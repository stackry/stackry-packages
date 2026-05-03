#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[stackry-packages] %s\n' "$*"
}

die() {
  printf '[stackry-packages] ERROR: %s\n' "$*" >&2
  exit 1
}

if [[ "${EUID}" -ne 0 ]]; then
  die "run as root, for example: curl -fsSL <url> | sudo bash"
fi

if ! command -v apt-get >/dev/null 2>&1; then
  die "this installer supports Debian/Ubuntu apt systems only"
fi

arch="$(dpkg --print-architecture)"
case "${arch}" in
  amd64|arm64) ;;
  *) die "unsupported architecture: ${arch}" ;;
esac

base_url="${STACKRY_PACKAGES_BASE_URL:-https://stackry.github.io/stackry-packages}"
apt_url="${STACKRY_APT_BASE_URL:-${base_url}/apt}"
codename="${STACKRY_APT_CODENAME:-stable}"
component="${STACKRY_APT_COMPONENT:-main}"

keyring_dir="/usr/share/keyrings"
keyring_path="${keyring_dir}/stackry-packages.gpg"
source_path="/etc/apt/sources.list.d/stackry.list"

log "Installing prerequisites."
apt-get update
apt-get install -y ca-certificates curl gnupg

log "Installing Stackry package signing key."
install -d -m 0755 "${keyring_dir}"
curl -fsSL "${apt_url}/stackry-packages.gpg" -o "${keyring_path}.tmp"
gpg --dearmor < "${keyring_path}.tmp" > "${keyring_path}"
rm -f "${keyring_path}.tmp"
chmod 0644 "${keyring_path}"

log "Writing APT source ${source_path}."
cat > "${source_path}" <<EOF
deb [arch=${arch} signed-by=${keyring_path}] ${apt_url} ${codename} ${component}
EOF

log "Refreshing package metadata."
apt-get update

log "Stackry package repository configured."
log "Next: sudo apt-get install -y stackry-cli"
