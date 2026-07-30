#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SYNC="${REPOSITORY_ROOT}/scripts/sync_agent_links.py"
PYTHON_BIN="${PYTHON_BIN:-python3}"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/agent-skills-links.XXXXXX")"
trap 'rm -rf "${TEST_ROOT}"' EXIT

CATALOG_ROOT="${TEST_ROOT}/project/.agents/catalog"
PROJECT_ROOT="${TEST_ROOT}/project"
mkdir -p \
  "${CATALOG_ROOT}/skills/alpha-skill" \
  "${CATALOG_ROOT}/skills/beta-skill" \
  "${PROJECT_ROOT}/.claude/skills/local-only"
touch \
  "${CATALOG_ROOT}/skills/alpha-skill/SKILL.md" \
  "${CATALOG_ROOT}/skills/beta-skill/SKILL.md" \
  "${PROJECT_ROOT}/.claude/skills/local-only/SKILL.md"

"${PYTHON_BIN}" "${SYNC}" \
  --project-root "${PROJECT_ROOT}" \
  --catalog-root "${CATALOG_ROOT}" \
  --write

test -L "${PROJECT_ROOT}/.agents/skills"
test "$(readlink "${PROJECT_ROOT}/.agents/skills")" = "catalog/skills"
test -L "${PROJECT_ROOT}/.claude/skills/alpha-skill"
test "$(readlink "${PROJECT_ROOT}/.claude/skills/alpha-skill")" = \
  "../../.agents/catalog/skills/alpha-skill"
test -d "${PROJECT_ROOT}/.claude/skills/local-only"

"${PYTHON_BIN}" "${SYNC}" \
  --project-root "${PROJECT_ROOT}" \
  --catalog-root "${CATALOG_ROOT}" \
  --check
printf 'ok - writes and checks both agent entrypoints\n'

mv \
  "${CATALOG_ROOT}/skills/beta-skill" \
  "${CATALOG_ROOT}/skills/gamma-skill"
"${PYTHON_BIN}" "${SYNC}" \
  --project-root "${PROJECT_ROOT}" \
  --catalog-root "${CATALOG_ROOT}" \
  --write
test ! -e "${PROJECT_ROOT}/.claude/skills/beta-skill"
test -L "${PROJECT_ROOT}/.claude/skills/gamma-skill"
test -d "${PROJECT_ROOT}/.claude/skills/local-only"
printf 'ok - removes only stale links owned by the catalog\n'

printf '1..2\n'
