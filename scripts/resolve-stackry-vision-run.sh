#!/usr/bin/env bash
set -euo pipefail

repo="${STACKRY_VISION_REPOSITORY:-stackry/stackry-vision}"
workflow="${STACKRY_VISION_WORKFLOW:-Stackry CLI}"
branch="${STACKRY_VISION_BRANCH:-main}"
run_id="${STACKRY_VISION_RUN_ID:-}"
gh_bin="${GH_BIN:-gh}"

if [[ -n "${run_id}" ]]; then
  if [[ ! "${run_id}" =~ ^[0-9]+$ ]]; then
    printf 'STACKRY_VISION_RUN_ID must be numeric, got %q\n' "${run_id}" >&2
    exit 1
  fi
  printf '%s\n' "${run_id}"
  exit 0
fi

if [[ "${STACKRY_VISION_ALLOW_LATEST:-}" != "true" ]]; then
  printf 'STACKRY_VISION_RUN_ID is required. Set STACKRY_VISION_ALLOW_LATEST=true only for an intentional manual latest-run lookup.\n' >&2
  exit 1
fi

run_id="$(
  "${gh_bin}" run list \
    --repo "${repo}" \
    --workflow "${workflow}" \
    --branch "${branch}" \
    --event push \
    --status success \
    --limit 1 \
    --json databaseId \
    --jq '.[0].databaseId'
)"

if [[ -z "${run_id}" || "${run_id}" == "null" ]]; then
  printf 'No successful %s run found on %s/%s.\n' "${workflow}" "${repo}" "${branch}" >&2
  exit 1
fi

printf '%s\n' "${run_id}"
