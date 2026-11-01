#!/usr/bin/env bash
# Exercise updates with upstream fixtures and an isolated installation directory.
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/home/.local/bin"
cat > "$tmp/home/.local/bin/curl" <<'SH'
#!/usr/bin/env bash
printf '[{"version":"v99.0.0-alpha.1"},{"version":"v28.1.0-rc.1"},{"version":"v28.0.1"},{"version":"v26.9.0","lts":"Example"}]\n'
SH
cat > "$tmp/home/.local/bin/fnm" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$CALLS"
SH
cat > "$tmp/home/.local/bin/npm" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$HOME/.local"
SH
chmod +x "$tmp/home/.local/bin/"{curl,fnm,npm}
env HOME="$tmp/home" CALLS="$tmp/node-calls" bash "$repo/scripts/package.sh" update node
for expected in 'install v28.0.1' 'use v28.0.1' 'default v28.0.1'; do
  grep -qxF "$expected" "$tmp/node-calls"
done
if grep -Eq 'alpha|rc\.' "$tmp/node-calls"; then
  echo 'Node update selected a prerelease' >&2
  exit 1
fi
printf 'Node update selects and activates the latest stable release\n'

cat > "$tmp/home/.local/bin/curl" <<'SH'
#!/usr/bin/env bash
printf '[{"version":"v99.0.0-alpha.1"}]\n'
SH
: > "$tmp/node-calls"
if env HOME="$tmp/home" CALLS="$tmp/node-calls" bash "$repo/scripts/package.sh" update node 2>/dev/null; then
  echo 'Node update accepted an index without stable releases' >&2
  exit 1
fi
if grep -Eq '^(install|default) ' "$tmp/node-calls"; then
  echo 'Node update changed versions without a stable release' >&2
  exit 1
fi
printf 'Node update rejects an index without stable releases\n'

mkdir -p "$tmp/payload"
cat > "$tmp/home/.local/bin/curl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
output="" url=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) output="$2"; shift 2 ;;
    https://*) url="$1"; shift ;;
    *) shift ;;
  esac
done
case "$url" in
  */opencode-v2.rb) cp "$FIXTURE/release.rb" "$output" ;;
  https://opencode.ai/files/bin/*)
    printf 'download\n' >> "$CALLS"
    cp "$FIXTURE/opencode.tar.gz" "$output"
    ;;
  *) exit 1 ;;
esac
SH
cat > "$tmp/home/.local/bin/systemctl" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$CALLS"
SH
chmod +x "$tmp/home/.local/bin/systemctl"

prepare_release() {
  local version="$1" asset checksum
  case "$(uname -m)" in
    x86_64) asset=opencode-linux-x64-baseline.tar.gz ;;
    aarch64) asset=opencode-linux-arm64.tar.gz ;;
  esac
  printf '#!/bin/sh\necho "opencode v%s"\n' "$version" > "$tmp/payload/opencode"
  chmod +x "$tmp/payload/opencode"
  tar -czf "$tmp/opencode.tar.gz" -C "$tmp/payload" opencode
  checksum="$(sha256sum "$tmp/opencode.tar.gz" | cut -d ' ' -f1)"
  printf '  version "%s"\n  url "https://opencode.ai/files/bin/%s/%s"\n  sha256 "%s"\n' \
    "$version" "$version" "$asset" "$checksum" > "$tmp/release.rb"
}

setup_service() {
  env HOME="$tmp/home" PATH="$tmp/home/.local/bin:$PATH" \
    CALLS="$tmp/service-calls" FIXTURE="$tmp" bash "$repo/services/opencode/setup.sh"
}

prepare_release 2.9.0
setup_service
service_binary="$tmp/home/services/opencode/bin/opencode"
[[ "$("$service_binary" --version)" == 'opencode v2.9.0' ]]
[[ -L "$tmp/home/.config/systemd/user/opencode-web.service" ]]
[[ "$(readlink -f "$tmp/home/services/opencode/runtime/xdg-data/opencode")" == "$tmp/home/services/opencode/runtime/data" ]]
grep -qxF -- '--user enable opencode-web.service' "$tmp/service-calls"
grep -qxF -- '--user restart opencode-web.service' "$tmp/service-calls"
setup_service
[[ "$(grep -cx download "$tmp/service-calls")" == 1 ]]
prepare_release 2.10.0
setup_service
[[ "$("$service_binary" --version)" == 'opencode v2.10.0' ]]
[[ "$(grep -cx download "$tmp/service-calls")" == 2 ]]
printf 'OpenCode service installs and starts the latest release and skips repeat downloads\n'

prepare_release 2.11.0
printf 'corrupted release' >> "$tmp/opencode.tar.gz"
: > "$tmp/service-calls"
if setup_service 2>/dev/null; then
  echo 'OpenCode setup accepted a corrupt release' >&2
  exit 1
fi
[[ "$("$service_binary" --version)" == 'opencode v2.10.0' ]]
if grep -q restart "$tmp/service-calls"; then
  echo 'OpenCode setup restarted the service after a failed update' >&2
  exit 1
fi
printf 'OpenCode rejects a corrupt release without replacing or restarting the service\n'

prepare_release 2.11.0
env HOME="$tmp/home" CALLS="$tmp/cli-calls" FIXTURE="$tmp" \
  bash "$repo/scripts/package.sh" update opencode
[[ "$("$tmp/home/.opencode/bin/opencode" --version)" == 'opencode v2.11.0' ]]
[[ "$("$service_binary" --version)" == 'opencode v2.10.0' ]]
printf 'Host CLI installation remains separate from the service binary\n'
