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

printf 'ok - recursive catalog checkout is runtime-ready and project-neutral\n'
