#!/usr/bin/env python3
"""Exercise the macOS startup branch with real limits in isolated child shells."""
import os
from pathlib import Path
import resource
import subprocess


snippet = Path(__file__).resolve().parents[1] / "home/.config/fish/conf.d/05-limits.fish"
cases = [
    ("Darwin", 256, 131072, 65536),
    ("Darwin", 256, 32768, 32768),
    ("Darwin", 65536, 131072, 65536),
    ("Darwin", 131072, 131072, 131072),
    ("Linux", 256, 131072, 256),
]
for platform, soft, hard, expected_soft in cases:
    result = subprocess.run(
        [
            "fish", "--no-config", "-c",
            "function uname; echo $TEST_OS; end; "
            "source $argv[1]; printf '%s %s\\n' (ulimit -Sn) (ulimit -Hn)",
            "--", str(snippet),
        ],
        env={**os.environ, "TEST_OS": platform},
        preexec_fn=lambda: resource.setrlimit(resource.RLIMIT_NOFILE, (soft, hard)),
        capture_output=True,
        text=True,
        check=True,
    )
    assert not result.stderr, result.stderr
    assert result.stdout.strip() == f"{expected_soft} {hard}", result.stdout
    print(f"{platform}: {soft}/{hard} -> {expected_soft}/{hard}")
