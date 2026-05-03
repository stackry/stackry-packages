#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/publish-apt-repo.sh --input-dir DIR --gpg-key KEY_ID [options]

Publishes stackry-cli Debian packages into the local APT repository tree.

Options:
  --repo-root DIR     Repository root. Defaults to the current directory.
  --input-dir DIR     Directory containing stackry-cli_*.deb files.
  --codename NAME     APT distribution codename. Defaults to stable.
  --component NAME    APT component. Defaults to main.
  --gpg-key KEY_ID    GPG key id or fingerprint used for export and signing.
  -h, --help          Show this help.

Environment:
  GPG_PASSPHRASE      Optional passphrase for the signing key.
EOF
}

log() {
  printf '[stackry-packages] %s\n' "$*"
}

die() {
  printf '[stackry-packages] ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

repo_root="$(pwd)"
input_dir=""
codename="stable"
component="main"
gpg_key=""

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --repo-root)
      repo_root="$2"
      shift 2
      ;;
    --input-dir)
      input_dir="$2"
      shift 2
      ;;
    --codename)
      codename="$2"
      shift 2
      ;;
    --component)
      component="$2"
      shift 2
      ;;
    --gpg-key)
      gpg_key="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

[[ -n "${input_dir}" ]] || die "--input-dir is required"
[[ -n "${gpg_key}" ]] || die "--gpg-key is required"
[[ -d "${repo_root}" ]] || die "--repo-root does not exist: ${repo_root}"
[[ -d "${input_dir}" ]] || die "--input-dir does not exist: ${input_dir}"

require_command apt-ftparchive
require_command dpkg-deb
require_command dpkg-scanpackages
require_command gzip
require_command gpg

apt_root="${repo_root}/apt"
pool_dir="${apt_root}/pool/main/s/stackry-cli"
dist_dir="${apt_root}/dists/${codename}"

shopt -s nullglob
debs=("${input_dir}"/stackry-cli_*.deb)
shopt -u nullglob

((${#debs[@]} > 0)) || die "no stackry-cli_*.deb files found in ${input_dir}"

log "Preparing APT repository tree."
rm -rf "${pool_dir}" "${dist_dir}"
mkdir -p "${pool_dir}" "${dist_dir}/${component}/binary-amd64" "${dist_dir}/${component}/binary-arm64"

for deb in "${debs[@]}"; do
  package="$(dpkg-deb -f "${deb}" Package)"
  arch="$(dpkg-deb -f "${deb}" Architecture)"

  [[ "${package}" == "stackry-cli" ]] || die "${deb} package is ${package}, expected stackry-cli"
  case "${arch}" in
    amd64|arm64) ;;
    *) die "${deb} has unsupported architecture: ${arch}" ;;
  esac

  log "Adding $(basename "${deb}") (${arch})."
  cp "${deb}" "${pool_dir}/"
done

log "Exporting public signing key."
gpg --batch --yes --armor --export "${gpg_key}" > "${apt_root}/stackry-packages.gpg"

pushd "${apt_root}" >/dev/null

for arch in amd64 arm64; do
  packages_path="dists/${codename}/${component}/binary-${arch}/Packages"
  log "Generating ${packages_path}."
  dpkg-scanpackages --arch "${arch}" pool > "${packages_path}"
  gzip -9cn "${packages_path}" > "${packages_path}.gz"
done

release_config="$(mktemp)"
trap 'rm -f "${release_config}"' EXIT
cat > "${release_config}" <<EOF
APT::FTPArchive::Release {
  Origin "Stackry";
  Label "Stackry";
  Suite "${codename}";
  Codename "${codename}";
  Architectures "amd64 arm64";
  Components "${component}";
  Description "Stackry public package repository";
};
EOF

log "Generating Release metadata."
apt-ftparchive -c "${release_config}" release "dists/${codename}" > "dists/${codename}/Release"

gpg_args=(--batch --yes --local-user "${gpg_key}")
if [[ -n "${GPG_PASSPHRASE:-}" ]]; then
  gpg_args+=(--pinentry-mode loopback --passphrase "${GPG_PASSPHRASE}")
fi

log "Signing Release metadata."
gpg "${gpg_args[@]}" --armor --detach-sign \
  -o "dists/${codename}/Release.gpg" \
  "dists/${codename}/Release"
gpg "${gpg_args[@]}" --clearsign \
  -o "dists/${codename}/InRelease" \
  "dists/${codename}/Release"

popd >/dev/null

log "APT repository published under ${apt_root}."
