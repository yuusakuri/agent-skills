#!/usr/bin/env bash
set -euo pipefail

TEST_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CATALOG_ROOT="$(cd "${TEST_DIRECTORY}/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/agent-skills-consumer.XXXXXX")"
trap 'rm -rf "${TEST_ROOT}"' EXIT

fail() {
  printf 'not ok - %s\n' "$*" >&2
  exit 1
}

test -L "${CATALOG_ROOT}/.agents/skills" ||
  fail "catalog must expose .agents/skills as a symlink"
test "$(readlink "${CATALOG_ROOT}/.agents/skills")" = "../skills" ||
  fail "catalog .agents/skills must point to ../skills"

mkdir -p "${TEST_ROOT}/.agents"
ln -s "${CATALOG_ROOT}" "${TEST_ROOT}/.agents/catalog"
ln -s "catalog/skills" "${TEST_ROOT}/.agents/skills"

available_count="$(find -L "${TEST_ROOT}/.agents/skills" -mindepth 2 -maxdepth 2 -name SKILL.md -type f | wc -l | tr -d ' ')"
test "${available_count}" = "97" ||
  fail "consumer must see 97 skills without installation, got ${available_count}"

for removed_path in \
  .gitmodules \
  skills.lock.tsv \
  tasks \
  third-party-licenses \
  vendor
do
  test ! -e "${CATALOG_ROOT}/${removed_path}" ||
    fail "standalone catalog must not contain ${removed_path}"
done

test -f "${CATALOG_ROOT}/catalog.toml" ||
  fail "catalog.toml must describe pinned skill sources"
test -f "${CATALOG_ROOT}/THIRD_PARTY_NOTICES.md" ||
  fail "third-party notices must be consolidated at repository root"

for skill_path in "${CATALOG_ROOT}"/skills/*; do
  test -d "${skill_path}" ||
    fail "every skill must be a regular directory: ${skill_path}"
  test ! -L "${skill_path}" ||
    fail "standalone clone must not require a nested checkout: ${skill_path}"
done

test -f "${CATALOG_ROOT}/skills/ui-ux-pro-max/SKILL.md" ||
  fail "ui-ux-pro-max must be included in a normal clone"

if grep -RniE 'open.?choice' \
  "${CATALOG_ROOT}/README.md" \
  "${CATALOG_ROOT}/skills" \
  "${CATALOG_ROOT}/scripts" \
  "${CATALOG_ROOT}/.github"; then
  fail "shared operational files must be project-neutral"
fi

document_skill="${CATALOG_ROOT}/skills/document-architecture/SKILL.md"
grep -Fq "GitHub-Flavored Markdown is the default output." "${document_skill}" ||
  fail "document-architecture must default to GitHub-Flavored Markdown"
grep -Fq "Only create a Word deliverable when explicitly requested" "${document_skill}" ||
  fail "document-architecture must keep Word output opt-in"

if grep -Fq 'skills/document-architecture/' "${CATALOG_ROOT}/README.md"; then
  fail "README must present document-architecture as a peer skill"
fi

printf 'ok - standalone catalog clone is runtime-ready and project-neutral\n'
