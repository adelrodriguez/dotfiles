#!/usr/bin/env bash
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 "$repo/tests/boundaries-test.py"
python3 "$repo/tests/boundaries.py"
python3 "$repo/tests/doctor.py"
python3 "$repo/tests/provisioning.py"
python3 "$repo/services/tests/setup.py"
python3 "$repo/home/tests/migration.py"
python3 "$repo/home/tests/runtime.py"
python3 "$repo/tools/tests/providers.py"
for test in agents/tests/environment.sh agents/tests/deploy.sh home/tests/fish-limits.sh home/tests/grok-completions.sh; do
  bash "$repo/$test"
done
