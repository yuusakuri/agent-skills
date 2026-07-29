#!/usr/bin/env bash
set -euo pipefail

LOCK_FILE="${1:-skills.lock.tsv}"
CATALOG_ROOT="${2:-$(pwd)}"
EXPECTED_HEADER=$'name\tkind\trepository\tpath\trevision\tcapability\tactivation'

fail() {
  printf 'skills lock validation failed: %s\n' "$*" >&2
  exit 1
}

[ -f "${LOCK_FILE}" ] || fail "lock file not found: ${LOCK_FILE}"
[ -d "${CATALOG_ROOT}" ] || fail "catalog root not found: ${CATALOG_ROOT}"

IFS= read -r actual_header <"${LOCK_FILE}" || fail "lock file is empty"
[ "${actual_header}" = "${EXPECTED_HEADER}" ] || fail "unexpected header"

awk -F '\t' '
  function fail(message) {
    printf "skills lock validation failed: line %d: %s\n", NR, message > "/dev/stderr"
    exit 1
  }
  NR == 1 { next }
  /^[[:space:]]*$/ { next }
  NF != 7 { fail("expected 7 tab-separated columns") }
  $1 !~ /^[a-z0-9]+(-[a-z0-9]+)*$/ { fail("invalid skill name: " $1) }
  $2 != "external" && $2 != "local" { fail("invalid kind for " $1 ": " $2) }
  $4 == "" || $4 ~ /^\// || $4 ~ /(^|\/)\.\.(\/|$)/ || $4 ~ /(^|\/)\.(\/|$)/ {
    fail("path must be repository-relative for " $1 ": " $4)
  }
  $6 !~ /^[a-z0-9]+(-[a-z0-9]+)*$/ { fail("invalid capability for " $1 ": " $6) }
  $7 == "" { fail("activation is required for " $1) }
  seen_name[$1]++ { fail("duplicate skill name: " $1) }
  seen_capability[$6]++ { fail("duplicate capability: " $6) }
  $2 == "external" {
    if ($3 !~ /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/) {
      fail("invalid external repository for " $1 ": " $3)
    }
    if ($5 !~ /^[0-9a-fA-F]{40}$/) {
      fail("external revision must be a 40-character commit for " $1)
    }
  }
  $2 == "local" {
    if ($3 != ".") { fail("local repository must be . for " $1) }
    if ($5 != "-") { fail("local revision must be - for " $1) }
  }
  {
    count++
  }
  END {
    if (count == 0) {
      printf "skills lock validation failed: no skills are defined\n" > "/dev/stderr"
      exit 1
    }
  }
' "${LOCK_FILE}"

while IFS=$'\t' read -r skill_name skill_kind _repository skill_path _revision _capability _activation; do
  [ "${skill_name}" = "name" ] && continue
  [ -n "${skill_name}" ] || continue
  [ "${skill_kind}" = "local" ] || continue

  skill_file="${CATALOG_ROOT}/${skill_path}/SKILL.md"
  [ -f "${skill_file}" ] || fail "local skill is missing SKILL.md: ${skill_path}"

  declared_name="$(sed -n 's/^name:[[:space:]]*//p' "${skill_file}" | head -1 | tr -d '"')"
  [ "${declared_name}" = "${skill_name}" ] ||
    fail "local skill name mismatch: lock=${skill_name}, SKILL.md=${declared_name:-missing}"
done <"${LOCK_FILE}"

skill_count="$(awk -F '\t' 'NR > 1 && NF > 0 { count++ } END { print count + 0 }' "${LOCK_FILE}")"
printf 'Validated %s skills from %s\n' "${skill_count}" "${LOCK_FILE}"
