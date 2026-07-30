#!/usr/bin/env bash
set -euo pipefail

TEST_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CATALOG_ROOT="$(cd "${TEST_DIRECTORY}/.." && pwd)"
CATALOG_FILE="${CATALOG_ROOT}/catalog.toml"
PYTHON_BIN="${PYTHON_BIN:-python3}"

fail() {
  printf 'not ok - %s\n' "$*" >&2
  exit 1
}

"${PYTHON_BIN}" "${CATALOG_ROOT}/scripts/validate.py" \
  --catalog "${CATALOG_FILE}" \
  --catalog-root "${CATALOG_ROOT}" >/dev/null

catalog_summary="$("${PYTHON_BIN}" - "${CATALOG_FILE}" <<'PY'
import sys
import tomllib

with open(sys.argv[1], "rb") as catalog_file:
    catalog = tomllib.load(catalog_file)
sources = catalog["sources"]
skills = [skill for source in sources for skill in source["skills"]]
print(len(skills))
PY
)"
skill_count="${catalog_summary}"

for excluded_name in \
  create-prd \
  competitor-analysis \
  market-sizing \
  opportunity-solution-tree \
  prioritize-features \
  startup-canvas
do
  if "${PYTHON_BIN}" - "${CATALOG_FILE}" "${excluded_name}" <<'PY'
import sys
import tomllib

with open(sys.argv[1], "rb") as catalog_file:
    catalog = tomllib.load(catalog_file)
names = {
    skill["name"]
    for source in catalog["sources"]
    for skill in source["skills"]
}
raise SystemExit(0 if sys.argv[2] in names else 1)
PY
  then
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

available_count="$(find -L "${CATALOG_ROOT}/skills" -mindepth 2 -maxdepth 2 -name SKILL.md -type f | wc -l | tr -d ' ')"
[ "${available_count}" = "${skill_count}" ] ||
  fail "manifest declares ${skill_count} skills but runtime exposes ${available_count}"

for skill_path in "${CATALOG_ROOT}"/skills/*
do
  test -d "${skill_path}" || fail "skill must be a directory: ${skill_path}"
  test ! -L "${skill_path}" || fail "skill must not be a symlink: ${skill_path}"
done

test -f "${CATALOG_ROOT}/skills/ui-ux-pro-max/SKILL.md" ||
  fail "ui-ux-pro-max must be vendored into the standalone catalog"

for repository in \
  GoogleChrome/modern-web-guidance \
  addyosmani/agent-skills \
  nextlevelbuilder/ui-ux-pro-max-skill \
  obra/superpowers \
  phuryn/pm-skills \
  product-on-purpose/pm-skills
do
  occurrence_count="$(grep -Fc "https://github.com/${repository}" "${CATALOG_ROOT}/THIRD_PARTY_NOTICES.md")"
  [ "${occurrence_count}" = "1" ] ||
    fail "notice must list ${repository} exactly once, got ${occurrence_count}"
done

printf 'ok - catalog contains a consistent set of pinned skills\n'
