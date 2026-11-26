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

fail() {
  printf 'not ok - %s\n' "$*" >&2
  exit 1
}

PROFILE_PROJECT="${TEST_ROOT}/profiled"
PROFILE_CATALOG="${PROFILE_PROJECT}/.agents/catalog"
mkdir -p "${PROFILE_CATALOG}/skills/alpha-skill" "${PROFILE_CATALOG}/skills/beta-skill"
touch \
  "${PROFILE_CATALOG}/skills/alpha-skill/SKILL.md" \
  "${PROFILE_CATALOG}/skills/beta-skill/SKILL.md"
cat >"${PROFILE_CATALOG}/catalog.toml" <<'TOML'
version = 1
[[sources]]
id = "catalog"
kind = "local"
repository = "."
license = "MIT"
activation = "auto"
profile = "engineering"
skills = [
  { name = "alpha-skill", path = "skills/alpha-skill", capability = "alpha" },
  { name = "beta-skill", path = "skills/beta-skill", capability = "beta", profile = "product" },
]
TOML

sync_profiled() {
  "${PYTHON_BIN}" "${SYNC}" \
    --project-root "${PROFILE_PROJECT}" \
    --catalog-root "${PROFILE_CATALOG}" \
    "$@"
}

sync_profiled --write >/dev/null
test -L "${PROFILE_PROJECT}/.agents/skills" ||
  fail "without a profile selection Codex keeps one directory link"

sync_profiled --write --profiles engineering >/dev/null
test -d "${PROFILE_PROJECT}/.agents/skills" ||
  fail "Codex entrypoint must become a directory"
test ! -L "${PROFILE_PROJECT}/.agents/skills" ||
  fail "a profile selection must not expose every skill to Codex"
test -L "${PROFILE_PROJECT}/.agents/skills/alpha-skill" ||
  fail "Codex must see the selected profile"
test "$(readlink "${PROFILE_PROJECT}/.agents/skills/alpha-skill")" = "../catalog/skills/alpha-skill" ||
  fail "Codex link has the wrong target"
test ! -e "${PROFILE_PROJECT}/.agents/skills/beta-skill" ||
  fail "Codex must not see an unselected profile"
test -L "${PROFILE_PROJECT}/.claude/skills/alpha-skill" ||
  fail "Claude Code must see the selected profile"
test ! -e "${PROFILE_PROJECT}/.claude/skills/beta-skill" ||
  fail "Claude Code must not see an unselected profile"
grep -Fq 'profiles = ["engineering"]' "${PROFILE_PROJECT}/.agents/agent-skills.toml" ||
  fail "the selection must be recorded for later checks"
sync_profiled --check >/dev/null ||
  fail "check must use the recorded selection"
printf 'ok - installs only the selected profiles\n'

ln -s ../../.agents/catalog/skills/beta-skill "${PROFILE_PROJECT}/.claude/skills/beta-skill"
if sync_profiled --check >/dev/null 2>&1; then
  fail "check must reject a link outside the selected profiles"
fi
sync_profiled --write >/dev/null
test ! -e "${PROFILE_PROJECT}/.claude/skills/beta-skill" ||
  fail "write must remove links outside the recorded selection"
printf 'ok - keeps entrypoints within the recorded selection\n'

if output="$(sync_profiled --write --profiles missing 2>&1)"; then
  fail "an unknown profile must fail"
fi
[[ "${output}" == *"unknown profile: missing"* ]] ||
  fail "unknown profile error is unclear: ${output}"
test -L "${PROFILE_PROJECT}/.agents/skills/alpha-skill" ||
  fail "a rejected selection must leave entrypoints untouched"
printf 'ok - rejects unknown profiles without changing entrypoints\n'

sync_profiled --write --profiles all >/dev/null
test -L "${PROFILE_PROJECT}/.agents/skills" ||
  fail "selecting all profiles restores the single Codex link"
test -L "${PROFILE_PROJECT}/.claude/skills/beta-skill" ||
  fail "selecting all profiles exposes every skill"
test ! -e "${PROFILE_PROJECT}/.agents/agent-skills.toml" ||
  fail "selecting all profiles clears the recorded selection"
sync_profiled --check >/dev/null
printf 'ok - returns to the full catalog\n'

printf '1..6\n'
