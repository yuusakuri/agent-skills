#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPDATER="${REPOSITORY_ROOT}/scripts/update_catalog.py"
PYTHON_BIN="${PYTHON_BIN:-python3}"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/agent-skills-update.XXXXXX")"
trap 'rm -rf "${TEST_ROOT}"' EXIT

CATALOG_ROOT="${TEST_ROOT}/catalog"
TARGET_ROOT="${TEST_ROOT}/project/.agents/skills"
SOURCE_WORK="${TEST_ROOT}/source-work"
REMOTE_ROOT="${TEST_ROOT}/remotes"
FAKE_BIN="${TEST_ROOT}/bin"
FETCH_LOG="${TEST_ROOT}/fetch.log"
REAL_GIT_BIN="$(command -v git)"

mkdir -p \
  "${CATALOG_ROOT}/skills/local-skill" \
  "${TARGET_ROOT}" \
  "${SOURCE_WORK}/skills/external-one" \
  "${SOURCE_WORK}/skills/external-two" \
  "${SOURCE_WORK}/references" \
  "${REMOTE_ROOT}/example" \
  "${FAKE_BIN}" \
  "${TEST_ROOT}/project/.git"

printf '%s\n' \
  '---' \
  'name: local-skill' \
  'description: Local test fixture skill.' \
  '---' \
  '# Local fixture' \
  >"${CATALOG_ROOT}/skills/local-skill/SKILL.md"

for skill_name in external-one external-two; do
  printf '%s\n' \
    '---' \
    "name: ${skill_name}" \
    'description: External test fixture skill.' \
    'metadata:' \
    '  frameworks: [test, fixture]' \
    '  updated: 2026-01-01' \
    '---' \
    "# ${skill_name}" \
    >"${SOURCE_WORK}/skills/${skill_name}/SKILL.md"
done
printf '\nUse `retired-skill` for the next step.\n' \
  >>"${SOURCE_WORK}/skills/external-one/SKILL.md"
printf 'shared completion criteria\n' \
  >"${SOURCE_WORK}/references/definition-of-done.md"
printf '%s\n' \
  'MIT License' \
  '' \
  'Copyright (c) Test Fixture' \
  >"${SOURCE_WORK}/LICENSE"

git -C "${SOURCE_WORK}" init -q
git -C "${SOURCE_WORK}" config user.name "Agent Skills Test"
git -C "${SOURCE_WORK}" config user.email "agent-skills-test@example.invalid"
git -C "${SOURCE_WORK}" add skills references LICENSE
git -C "${SOURCE_WORK}" commit -q -m "Add fixture skills"
SOURCE_REVISION="$(git -C "${SOURCE_WORK}" rev-parse HEAD)"
git clone -q --bare "${SOURCE_WORK}" "${REMOTE_ROOT}/example/source.git"

write_catalog() {
  revision="$1"
  cat >"${CATALOG_ROOT}/catalog.toml" <<TOML
version = 1

[[sources]]
id = "example-source"
kind = "vendored"
repository = "example/source"
revision = "${revision}"
license = "MIT"
license_file = "LICENSE"
activation = "auto"
aliases = [
  { from = "retired-skill", to = "local-skill" },
]
skills = [
  { name = "external-one", path = "skills/external-one", capability = "external-one-capability", resources = ["references/definition-of-done.md"] },
  { name = "external-two", path = "skills/external-two", capability = "external-two-capability" },
]

[[sources]]
id = "catalog"
kind = "local"
repository = "."
license = "MIT"
activation = "auto"
skills = [
  { name = "local-skill", path = "skills/local-skill", capability = "local-capability" },
]
TOML
}

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'if [ "${1:-}" = "-C" ] && [ "${3:-}" = "fetch" ]; then' \
  '  printf "fetch\n" >>"${FETCH_LOG}"' \
  'fi' \
  'exec "${REAL_GIT_BIN}" "$@"' \
  >"${FAKE_BIN}/git"
chmod +x "${FAKE_BIN}/git"

write_catalog "0000000000000000000000000000000000000000"
printf 'preserve\n' >"${TARGET_ROOT}/sentinel"
if PATH="${FAKE_BIN}:${PATH}" \
  FETCH_LOG="${FETCH_LOG}" \
  REAL_GIT_BIN="${REAL_GIT_BIN}" \
  AGENT_SKILLS_GITHUB_BASE_URL="file://${REMOTE_ROOT}" \
  "${PYTHON_BIN}" "${UPDATER}" \
    --catalog "${CATALOG_ROOT}/catalog.toml" \
    --catalog-root "${CATALOG_ROOT}" \
    --target "${TARGET_ROOT}" >/dev/null 2>&1; then
  printf 'not ok - fetch failure should fail\n' >&2
  exit 1
fi
test -f "${TARGET_ROOT}/sentinel"
printf 'ok - fetch failure preserves the existing target\n'

write_catalog "${SOURCE_REVISION}"
: >"${FETCH_LOG}"
PATH="${FAKE_BIN}:${PATH}" \
  FETCH_LOG="${FETCH_LOG}" \
  REAL_GIT_BIN="${REAL_GIT_BIN}" \
  AGENT_SKILLS_GITHUB_BASE_URL="file://${REMOTE_ROOT}" \
  "${PYTHON_BIN}" "${UPDATER}" \
    --catalog "${CATALOG_ROOT}/catalog.toml" \
    --catalog-root "${CATALOG_ROOT}" \
    --target "${TARGET_ROOT}" >/dev/null

test ! -e "${TARGET_ROOT}/sentinel"
test -f "${TARGET_ROOT}/external-one/SKILL.md"
test -f "${TARGET_ROOT}/external-one/references/definition-of-done.md"
grep -Fq 'shared completion criteria' \
  "${TARGET_ROOT}/external-one/references/definition-of-done.md"
grep -Fq 'Use `local-skill` for the next step.' \
  "${TARGET_ROOT}/external-one/SKILL.md"
if grep -Fq 'retired-skill' "${TARGET_ROOT}/external-one/SKILL.md"; then
  printf 'not ok - excluded upstream skill reference was not normalized\n' >&2
  exit 1
fi
test -f "${TARGET_ROOT}/external-two/SKILL.md"
test -f "${TARGET_ROOT}/local-skill/SKILL.md"
grep -Fq 'frameworks: "test, fixture"' \
  "${TARGET_ROOT}/external-two/SKILL.md"
grep -Fq 'updated: "2026-01-01"' \
  "${TARGET_ROOT}/external-two/SKILL.md"
printf 'ok - installs self-contained external and local skills\n'
test "$(grep -Fc 'https://github.com/example/source' "${CATALOG_ROOT}/THIRD_PARTY_NOTICES.md")" = "1"
grep -Fq "${SOURCE_REVISION}" "${CATALOG_ROOT}/THIRD_PARTY_NOTICES.md"
grep -Fq 'Copyright (c) Test Fixture' "${CATALOG_ROOT}/THIRD_PARTY_NOTICES.md"
printf 'ok - consolidates source license and provenance once\n'

fetch_count="$(wc -l <"${FETCH_LOG}" | tr -d ' ')"
test "${fetch_count}" = "1"
printf 'ok - fetches one pinned source only once\n'

first_digest="$(find "${TARGET_ROOT}" -type f -print0 | sort -z | xargs -0 shasum | shasum | awk '{print $1}')"
: >"${FETCH_LOG}"
PATH="${FAKE_BIN}:${PATH}" \
  FETCH_LOG="${FETCH_LOG}" \
  REAL_GIT_BIN="${REAL_GIT_BIN}" \
  AGENT_SKILLS_GITHUB_BASE_URL="file://${REMOTE_ROOT}" \
  "${PYTHON_BIN}" "${UPDATER}" \
    --catalog "${CATALOG_ROOT}/catalog.toml" \
    --catalog-root "${CATALOG_ROOT}" \
    --target "${TARGET_ROOT}" >/dev/null
second_digest="$(find "${TARGET_ROOT}" -type f -print0 | sort -z | xargs -0 shasum | shasum | awk '{print $1}')"
test "${first_digest}" = "${second_digest}"
test "$(wc -l <"${FETCH_LOG}" | tr -d ' ')" = "1"
printf 'ok - reinstall is idempotent\n'

PATH="${FAKE_BIN}:${PATH}" \
  FETCH_LOG="${FETCH_LOG}" \
  REAL_GIT_BIN="${REAL_GIT_BIN}" \
  AGENT_SKILLS_GITHUB_BASE_URL="file://${REMOTE_ROOT}" \
  "${PYTHON_BIN}" "${UPDATER}" \
    --check \
    --catalog "${CATALOG_ROOT}/catalog.toml" \
    --catalog-root "${CATALOG_ROOT}" \
    --target "${TARGET_ROOT}" >/dev/null
printf 'ok - check mode accepts a matching snapshot\n'

mkdir -p "${TARGET_ROOT}/external-one/__pycache__"
printf 'runtime cache\n' >"${TARGET_ROOT}/external-one/__pycache__/core.pyc"
PATH="${FAKE_BIN}:${PATH}" \
  FETCH_LOG="${FETCH_LOG}" \
  REAL_GIT_BIN="${REAL_GIT_BIN}" \
  AGENT_SKILLS_GITHUB_BASE_URL="file://${REMOTE_ROOT}" \
  "${PYTHON_BIN}" "${UPDATER}" \
    --check \
    --catalog "${CATALOG_ROOT}/catalog.toml" \
    --catalog-root "${CATALOG_ROOT}" \
    --target "${TARGET_ROOT}" >/dev/null
printf 'ok - check mode ignores Python runtime caches\n'

printf '\n# drift\n' >>"${TARGET_ROOT}/external-one/SKILL.md"
if PATH="${FAKE_BIN}:${PATH}" \
  FETCH_LOG="${FETCH_LOG}" \
  REAL_GIT_BIN="${REAL_GIT_BIN}" \
  AGENT_SKILLS_GITHUB_BASE_URL="file://${REMOTE_ROOT}" \
  "${PYTHON_BIN}" "${UPDATER}" \
    --check \
    --catalog "${CATALOG_ROOT}/catalog.toml" \
    --catalog-root "${CATALOG_ROOT}" \
    --target "${TARGET_ROOT}" >/dev/null 2>&1; then
  printf 'not ok - check mode should reject content drift\n' >&2
  exit 1
fi
printf 'ok - check mode rejects content drift\n'

printf '1..8\n'
