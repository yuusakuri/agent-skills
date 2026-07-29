#!/usr/bin/env bash
set -euo pipefail

TEST_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CATALOG_ROOT="$(cd "${TEST_DIRECTORY}/.." && pwd)"
LOCK_FILE="${CATALOG_ROOT}/skills.lock.tsv"

fail() {
  printf 'not ok - %s\n' "$*" >&2
  exit 1
}

"${CATALOG_ROOT}/scripts/validate.sh" "${LOCK_FILE}" "${CATALOG_ROOT}" >/dev/null

skill_count="$(awk -F '\t' 'NR > 1 && NF > 0 { count++ } END { print count + 0 }' "${LOCK_FILE}")"
[ "${skill_count}" = "97" ] || fail "expected 97 adopted skills, got ${skill_count}"

external_count="$(awk -F '\t' '$2 == "external" { count++ } END { print count + 0 }' "${LOCK_FILE}")"
local_count="$(awk -F '\t' '$2 == "local" { count++ } END { print count + 0 }' "${LOCK_FILE}")"
[ "${external_count}" = "96" ] || fail "expected 96 external skills, got ${external_count}"
[ "${local_count}" = "1" ] || fail "expected 1 local skill, got ${local_count}"

for excluded_name in \
  create-prd \
  competitor-analysis \
  market-sizing \
  opportunity-solution-tree \
  prioritize-features
do
  if awk -F '\t' -v name="${excluded_name}" 'NR > 1 && $1 == name { found=1 } END { exit !found }' "${LOCK_FILE}"; then
    fail "duplicate candidate should remain excluded: ${excluded_name}"
  fi
done

for reference_name in \
  requirements-definition \
  technical-spec \
  basic-design \
  detailed-design \
  system-proposal \
  business-proposal \
  quality-checklist
do
  reference_file="${CATALOG_ROOT}/skills/document-architecture/references/${reference_name}.md"
  [ -f "${reference_file}" ] || fail "missing document reference: ${reference_name}"
done

printf 'ok - catalog contains 97 non-duplicated, pinned skills\n'
