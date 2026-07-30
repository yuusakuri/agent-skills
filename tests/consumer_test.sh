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

test -d "${CATALOG_ROOT}/.claude/skills" ||
  fail "catalog must expose a real .claude/skills directory"
test ! -L "${CATALOG_ROOT}/.claude/skills" ||
  fail "Claude Code entrypoint must use individual skill symlinks"
test ! -e "${CATALOG_ROOT}/SKILL.md" ||
  fail "catalog must not add a competing root SKILL.md"

skill_count="$("${PYTHON_BIN:-python3}" - "${CATALOG_ROOT}/catalog.toml" <<'PY'
import sys
import tomllib

with open(sys.argv[1], "rb") as catalog_file:
    catalog = tomllib.load(catalog_file)
print(sum(len(source["skills"]) for source in catalog["sources"]))
PY
)"

for skill_path in "${CATALOG_ROOT}"/skills/*; do
  skill_name="$(basename "${skill_path}")"
  claude_link="${CATALOG_ROOT}/.claude/skills/${skill_name}"
  test -L "${claude_link}" ||
    fail "Claude Code link is missing for ${skill_name}"
  test "$(readlink "${claude_link}")" = "../../skills/${skill_name}" ||
    fail "Claude Code link has the wrong target for ${skill_name}"
  test -f "${claude_link}/SKILL.md" ||
    fail "Claude Code cannot resolve ${skill_name}/SKILL.md"
done

mkdir -p "${TEST_ROOT}/.agents"
ln -s "${CATALOG_ROOT}" "${TEST_ROOT}/.agents/catalog"
"${PYTHON_BIN:-python3}" "${CATALOG_ROOT}/scripts/sync_agent_links.py" \
  --project-root "${TEST_ROOT}" \
  --catalog-root "${TEST_ROOT}/.agents/catalog" \
  --write

available_count="$(find -L "${TEST_ROOT}/.agents/skills" -mindepth 2 -maxdepth 2 -name SKILL.md -type f | wc -l | tr -d ' ')"
test "${available_count}" = "${skill_count}" ||
  fail "Codex consumer sees ${available_count} of ${skill_count} skills"

claude_count="$(find -L "${TEST_ROOT}/.claude/skills" -mindepth 2 -maxdepth 2 -name SKILL.md -type f | wc -l | tr -d ' ')"
test "${claude_count}" = "${skill_count}" ||
  fail "Claude Code consumer sees ${claude_count} of ${skill_count} skills"

"${PYTHON_BIN:-python3}" "${CATALOG_ROOT}/scripts/sync_agent_links.py" \
  --project-root "${TEST_ROOT}" \
  --catalog-root "${TEST_ROOT}/.agents/catalog" \
  --check

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

for heading in \
  '## 対応エージェント' \
  '## リポジトリ構成' \
  '## 単体で利用' \
  '## プロジェクトへ追加' \
  '## カタログの更新' \
  '## ライセンス'
do
  grep -Fq "${heading}" "${CATALOG_ROOT}/README.md" ||
    fail "README is missing final user-facing section: ${heading}"
done

if grep -nE '([0-9]+件|採用一覧|選定|検討過程|GitHub Issues|作業管理)' \
  "${CATALOG_ROOT}/README.md"; then
  fail "README must not expose catalog counts or internal deliberation"
fi

printf 'ok - standalone catalog supports Codex and Claude Code\n'
