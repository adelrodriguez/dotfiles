#!/usr/bin/env python3
import base64
import fnmatch
import json
import os
from pathlib import Path
import subprocess
import urllib.error
import urllib.request


ROOT = Path.home() / "services/opencode"
CONFIG = Path.home() / ".config/opencode/service.json"
PASSWORD = json.loads(CONFIG.read_text())["password"]
AUTH = "Basic " + base64.b64encode(f"opencode:{PASSWORD}".encode()).decode()
PORT = os.environ.get("OPENCODE_PORT", "4096")
URLS = [f"http://127.0.0.1:{PORT}"]
if PORT == "4096":
    URLS.append("https://opencode.homelab.adel.wtf")


def get(base, path, authenticated=True):
    headers = {"Authorization": AUTH} if authenticated else {}
    request = urllib.request.Request(base + path, headers=headers)
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read()


for base in URLS:
    assert b"<title>OpenCode</title>" in get(base, "/", False), base
    if base.startswith("https://"):
        info = json.loads(get(base, "/api/info", False))
        assert json.loads(get(base, "/api/session?limit=1", False))["data"]
        access = "password-free API and session access"
    else:
        try:
            get(base, "/api/info", False)
        except urllib.error.HTTPError as error:
            assert error.code == 401, error.code
        else:
            raise AssertionError(f"{base}: backend accepted an unauthenticated request")
        info = json.loads(get(base, "/api/info"))
        access = "backend API authentication"
    assert info["version"] == "2.0.22", info
    print(f"PASS {base}: web UI, {access}, version {info['version']}")

config = json.loads(get(URLS[0], "/api/config"))
rules = [
    rule
    for entry in config
    if entry["type"] == "document"
    for rule in entry["info"].get("permissions", [])
]
for action, resource in [
    ("read", "/etc/hosts"),
    ("read", "/home/adel/projects/example/.env"),
    ("glob", "**/*"),
    ("grep", "example"),
    ("external_directory", "/etc/*"),
]:
    matches = [
        rule for rule in rules
        if fnmatch.fnmatchcase(action, rule["action"])
        and fnmatch.fnmatchcase(resource, rule["resource"])
    ]
    assert matches and matches[-1]["effect"] == "allow", (action, resource)
print("PASS loaded global configuration allows file inspection and external directories")

sessions = json.loads(get(URLS[0], "/api/session?limit=1"))
assert sessions["data"], "Expected copied session history"
print("PASS copied session history is available through the API")

unit = "opencode-web.service"
for operation in ["is-active", "is-enabled"]:
    subprocess.run(["systemctl", "--user", operation, "--quiet", unit], check=True)
pid = int(subprocess.check_output(
    ["systemctl", "--user", "show", unit, "--property=MainPID", "--value"], text=True
))
assert info["pid"] == pid, (info, pid)
process = Path(f"/proc/{pid}")
assert process.stat().st_uid == os.getuid() == 1000
assert process.joinpath("exe").resolve() == ROOT / "bin/opencode"
assert process.joinpath("root/etc/os-release").read_text() == Path("/etc/os-release").read_text()
environment = dict(
    entry.split("=", 1)
    for entry in process.joinpath("environ").read_text().split("\0") if entry
)
for variable, directory in [
    ("XDG_DATA_HOME", "data"),
    ("XDG_STATE_HOME", "state"),
    ("XDG_CACHE_HOME", "cache"),
]:
    assert (Path(environment[variable]) / "opencode").resolve() == ROOT / "runtime" / directory
assert environment["DBUS_SESSION_BUS_ADDRESS"] == "unix:path=/run/user/1000/bus"
subprocess.run(["systemctl", "--user", "show", "t3code.service", "--property=ActiveState"],
               env=environment, check=True)
listeners = subprocess.check_output(["ss", "-ltnp"], text=True)
assert any(f"127.0.0.1:{PORT} " in line and f"pid={pid}," in line
           for line in listeners.splitlines()), listeners
assert not subprocess.check_output(
    ["docker", "compose", "ps", "-q", "opencode"], cwd=ROOT, text=True
).strip(), "Docker web server is still running"
print("PASS native service, boot startup, host user, persistent data, loopback binding, and host service access")
