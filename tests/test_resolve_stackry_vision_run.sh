#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="${repo_root}/scripts/resolve-stackry-vision-run.sh"
tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

assert_eq() {
  local got="$1"
  local want="$2"
  local label="$3"

  if [[ "${got}" != "${want}" ]]; then
    printf '%s: got %q, want %q\n' "${label}" "${got}" "${want}" >&2
    exit 1
  fi
}

got="$(STACKRY_VISION_RUN_ID=25347696404 "${script}")"
assert_eq "${got}" "25347696404" "explicit run id"

if STACKRY_VISION_RUN_ID=abc "${script}" >/tmp/stackry-run-out 2>/tmp/stackry-run-err; then
  printf 'non-numeric run id unexpectedly succeeded\n' >&2
  exit 1
fi

if ! grep -q 'STACKRY_VISION_RUN_ID must be numeric' /tmp/stackry-run-err; then
  printf 'non-numeric run id error was not helpful:\n' >&2
  cat /tmp/stackry-run-err >&2
  exit 1
fi

if "${script}" >/tmp/stackry-run-out 2>/tmp/stackry-run-err; then
  printf 'missing run id unexpectedly succeeded\n' >&2
  exit 1
fi

if ! grep -q 'STACKRY_VISION_RUN_ID is required' /tmp/stackry-run-err; then
  printf 'missing run id error was not helpful:\n' >&2
  cat /tmp/stackry-run-err >&2
  exit 1
fi

fake_gh="${tmpdir}/gh"
cat > "${fake_gh}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

expected=(
  run list
  --repo stackry/stackry-vision
  --workflow "Stackry CLI"
  --branch main
  --event push
  --status success
  --limit 1
  --json databaseId
  --jq '.[0].databaseId'
)
args=("$@")

if [[ "$#" -ne "${#expected[@]}" ]]; then
  printf 'unexpected arg count: %s\n' "$#" >&2
  printf '%q\n' "$@" >&2
  exit 64
fi

for index in "${!expected[@]}"; do
  if [[ "${args[${index}]}" != "${expected[${index}]}" ]]; then
    printf 'arg %s: got %q, want %q\n' "${index}" "${args[${index}]}" "${expected[${index}]}" >&2
    exit 64
  fi
done

printf '25347696404\n'
EOF
chmod +x "${fake_gh}"

got="$(STACKRY_VISION_ALLOW_LATEST=true GH_BIN="${fake_gh}" "${script}")"
assert_eq "${got}" "25347696404" "latest successful run id"

printf 'resolve stackry vision run test passed\n'
