#!/usr/bin/env python3
"""Build, activate, and roll back the Nix pilot in a disposable home."""
import hashlib
import json
import os
from pathlib import Path
import platform
import pwd
import shutil
import stat
import subprocess
import tempfile


def expect(condition, message):
    if not condition:
        raise AssertionError(message)
    print("PASS " + message, flush=True)


def run(stage, arguments, environment, succeeds=True, input=None):
    print(stage, flush=True)
    result = subprocess.run(arguments, env=environment, input=input, text=True, capture_output=True)
    if succeeds and result.returncode:
        raise RuntimeError("%s failed (%s):\n%s\n%s" % (stage, result.returncode, result.stdout[-3000:], result.stderr[-6000:]))
    return result


def snapshot(path):
    try:
        status = path.lstat()
    except FileNotFoundError:
        return None
    metadata = (stat.S_IMODE(status.st_mode), status.st_uid, status.st_gid)
    if path.is_symlink():
        return ("link", metadata, os.readlink(path))
    if path.is_dir():
        return ("directory", metadata, {child.name: snapshot(child) for child in sorted(path.iterdir())})
    if path.is_file():
        return ("file", metadata, hashlib.sha256(path.read_bytes()).hexdigest())
    raise ValueError("Unexpected file type in a Nix profile: " + str(path))


def main():
    hosts = {("Linux", "x86_64"): "server", ("Darwin", "arm64"): "mac"}
    machine = (platform.system(), platform.machine())
    if machine not in hosts:
        raise SystemExit("The pilot supports x86_64 Linux and arm64 macOS.")
    executable = shutil.which("nix")
    if executable is None:
        raise SystemExit("Nix is required. See docs/nix-pilot.md.")
    socket = Path("/nix/var/nix/daemon-socket/socket")
    if not socket.is_socket():
        raise SystemExit("The pilot requires a running multi-user Nix daemon at " + str(socket))
    username = pwd.getpwuid(os.getuid()).pw_name
    actual_home = Path.home()
    state_dir = Path(os.environ.get("NIX_STATE_DIR", "/nix/var/nix"))
    protected = [
        actual_home / ".nix-profile",
        actual_home / ".local/state/nix/profiles",
        actual_home / ".local/state/home-manager",
        state_dir / "profiles/per-user" / username,
    ]
    before = {str(path): snapshot(path) for path in protected}
    pilot = Path(__file__).resolve().parents[1] / "nix"

    with tempfile.TemporaryDirectory(prefix="dotfiles-nix-pilot-") as directory:
        scratch = Path(directory).resolve()
        trial_home = scratch / "home"
        trial_home.mkdir()
        source = scratch / "source"
        shutil.copytree(pilot, source)
        original_lock = (source / "flake.lock").read_bytes()
        environment = dict(os.environ)
        for key in ["NIX_PROFILE", "NIX_PROFILES", "NIX_USER_PROFILE_DIR", "NIX_PATH", "__ETC_PROFILE_NIX_SOURCED", "__HM_SESS_VARS_SOURCED"]:
            environment.pop(key, None)
        environment.update({
            "HOME": str(trial_home),
            "USER": username,
            "XDG_CONFIG_HOME": str(trial_home / ".config"),
            "XDG_CACHE_HOME": str(trial_home / ".cache"),
            "XDG_DATA_HOME": str(trial_home / ".local/share"),
            "XDG_STATE_HOME": str(trial_home / ".local/state"),
            # HOME alone does not isolate Home Manager's legacy-profile migration.
            "NIX_STATE_DIR": str(scratch / "client-state"),
            "NIX_REMOTE": "unix://" + str(socket),
            "NIX_CONFIG": "experimental-features = nix-command flakes\nuse-xdg-base-directories = false\n",
            "PATH": str(Path(executable).parent) + ":/usr/bin:/bin:/usr/sbin:/sbin",
        })
        (trial_home / ".local/state/nix/profiles").mkdir(parents=True)
        (scratch / "client-state").mkdir()
        parameters = {"username": username, "homeDirectory": str(trial_home), "message": "generation-a"}
        environment["DOTFILES_NIX_PILOT"] = json.dumps(parameters)
        target = trial_home / ".config/dotfiles-nix-pilot/message"
        profile = trial_home / ".nix-profile"
        generation_a = scratch / "generation-a"
        generation_b = scratch / "generation-b"
        build = [executable, "build", "--impure", "--no-update-lock-file", "path:" + str(source) + "#homeConfigurations." + hosts[machine] + ".activationPackage", "--out-link"]

        try:
            version = run("Checking the isolated Nix client", [executable, "--version"], environment)
            print(version.stdout.strip(), flush=True)
            run("Building generation A", build + [str(generation_a)], environment)
            expect(not target.exists(), "building does not activate files")
            target.parent.mkdir(parents=True)
            target.write_text("local-user-edit\n")
            collision = run("Checking local-file protection", [str(generation_a / "activate")], environment, succeeds=False)
            expect(collision.returncode != 0 and not target.is_symlink() and target.read_text() == "local-user-edit\n", "activation preserves a conflicting local file")
            backup = scratch / "local-file-backup"
            target.rename(backup)
            run("Activating generation A", [str(generation_a / "activate")], environment)
            first = (target.read_text(), str(target.resolve()), str((profile / "bin/jq").resolve()))
            expect(first[0] == "generation-a\n" and target.is_symlink(), "generation A installs the declared file")
            jq = run("Executing the installed jq", [str(profile / "bin/jq"), "-n", "--arg", "value", "nix-pilot", "{value:$value}"], environment)
            expect(json.loads(jq.stdout) == {"value": "nix-pilot"} and first[2].startswith("/nix/store/"), "the declared jq package executes from the Nix store")
            fresh = run("Checking a fresh login shell", [str(profile / "bin/bash"), "--login", "-c", "command -v jq; hello --greeting=nix-pilot"], environment)
            expect(fresh.stdout.splitlines() == [str(profile / "bin/jq"), "nix-pilot"], "a fresh shell selects and executes the declared packages")
            run("Repeating activation", [str(generation_a / "activate")], environment)
            expect((target.read_text(), str(target.resolve()), str((profile / "bin/jq").resolve())) == first, "repeat activation preserves the managed state")

            parameters["message"] = "generation-b"
            environment["DOTFILES_NIX_PILOT"] = json.dumps(parameters)
            run("Building generation B", build + [str(generation_b)], environment)
            expect(target.read_text() == first[0], "a second build leaves generation A active")
            run("Activating generation B", [str(generation_b / "activate")], environment)
            second = (target.read_text(), str(target.resolve()))
            expect(second[0] == "generation-b\n" and second[1] != first[1], "generation B changes the declared file")
            parameters["message"] = []
            environment["DOTFILES_NIX_PILOT"] = json.dumps(parameters)
            invalid = run("Rejecting an invalid configuration", build + [str(scratch / "invalid")], environment, succeeds=False)
            expect(invalid.returncode != 0 and (target.read_text(), str(target.resolve())) == second, "an invalid build preserves the active generation")
            parameters["message"] = "generation-b"
            environment["DOTFILES_NIX_PILOT"] = json.dumps(parameters)
            manager = str(profile / "bin/home-manager")
            run("Rolling back to generation A", [manager, "switch", "--rollback"], environment)
            expect((target.read_text(), str(target.resolve()), str((profile / "bin/jq").resolve())) == first, "rollback restores generation A and its package path")

            inputs = json.loads(run("Finding the pinned uninstall inputs", [executable, "flake", "archive", "--json", "--no-update-lock-file", "path:" + str(source)], environment).stdout)["inputs"]
            package_input = "nixpkgs-darwin" if hosts[machine] == "mac" else "nixpkgs-linux"
            run("Removing the pilot's Home Manager configuration", [manager, "-I", "home-manager=" + inputs["home-manager"]["path"], "-I", "nixpkgs=" + inputs[package_input]["path"], "uninstall"], environment, input="y\n")
            expect(not target.exists() and not target.is_symlink(), "Home Manager removal deletes the managed file")
            expect(not (profile / "bin/jq").exists() and not (profile / "bin/hello").exists(), "Home Manager removal drops the pilot packages")
            expect(backup.read_text() == "local-user-edit\n", "the saved local file survives activation and removal")
            expect((source / "flake.lock").read_bytes() == original_lock, "the build keeps the committed inputs pinned")
        finally:
            expect({str(path): snapshot(path) for path in protected} == before, "the account's existing Nix profiles remain unchanged")

    print("Nix pilot passed. The disposable home and client state were removed.", flush=True)


if __name__ == "__main__":
    main()
