#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT
publish_root="${tmpdir}/publish-root"
mkdir -p "${publish_root}/apt"

export GNUPGHOME="${tmpdir}/gnupg"
mkdir -p "${GNUPGHOME}"
chmod 0700 "${GNUPGHOME}"

gpg --batch --quiet --passphrase '' --quick-gen-key \
  "Stackry Packages Test <engineering@stackry.com>" rsa2048 sign 1d
key_id="$(gpg --batch --quiet --list-keys --with-colons \
  | awk -F: '$1 == "fpr" {print $10; exit}')"

make_deb() {
  local arch="$1"
  local package_root="${tmpdir}/pkg-${arch}"
  mkdir -p "${package_root}/DEBIAN" "${package_root}/usr/bin"

  cat > "${package_root}/DEBIAN/control" <<EOF
Package: stackry-cli
Version: 0.0.0+test
Section: admin
Priority: optional
Architecture: ${arch}
Maintainer: Stackry <engineering@stackry.com>
Description: Stackry station appliance CLI test package
EOF

  cat > "${package_root}/usr/bin/stackry" <<'EOF'
#!/usr/bin/env bash
echo stackry test
EOF
  chmod 0755 "${package_root}/usr/bin/stackry"

  dpkg-deb --build "${package_root}" "${tmpdir}/stackry-cli_0.0.0+test_${arch}.deb" >/dev/null
}

make_deb amd64
make_deb arm64

"${repo_root}/scripts/publish-apt-repo.sh" \
  --repo-root "${publish_root}" \
  --input-dir "${tmpdir}" \
  --codename stable \
  --component main \
  --gpg-key "${key_id}"

test -f "${publish_root}/apt/stackry-packages.gpg"
test -f "${publish_root}/apt/dists/stable/Release"
test -f "${publish_root}/apt/dists/stable/InRelease"
test -f "${publish_root}/apt/dists/stable/Release.gpg"
test -f "${publish_root}/apt/dists/stable/main/binary-amd64/Packages"
test -f "${publish_root}/apt/dists/stable/main/binary-amd64/Packages.gz"
test -f "${publish_root}/apt/dists/stable/main/binary-arm64/Packages"
test -f "${publish_root}/apt/dists/stable/main/binary-arm64/Packages.gz"

grep -q '^Package: stackry-cli$' "${publish_root}/apt/dists/stable/main/binary-amd64/Packages"
grep -q '^Architecture: amd64$' "${publish_root}/apt/dists/stable/main/binary-amd64/Packages"
grep -q '^Filename: pool/main/s/stackry-cli/stackry-cli_0.0.0+test_amd64.deb$' \
  "${publish_root}/apt/dists/stable/main/binary-amd64/Packages"
grep -q '^Architecture: arm64$' "${publish_root}/apt/dists/stable/main/binary-arm64/Packages"

gpg --batch --quiet --verify \
  "${publish_root}/apt/dists/stable/Release.gpg" \
  "${publish_root}/apt/dists/stable/Release"
gpg --batch --quiet --verify "${publish_root}/apt/dists/stable/InRelease"

echo "publish apt repo test passed"
