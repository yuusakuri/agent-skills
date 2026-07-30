#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPDATER="${REPOSITORY_ROOT}/scripts/update-vendored-skills.sh"
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
    '---' \
    "# ${skill_name}" \
    >"${SOURCE_WORK}/skills/${skill_name}/SKILL.md"
done
printf '%s\n' \
  'MIT License' \
  '' \
  'Copyright (c) Test Fixture' \
  >"${SOURCE_WORK}/LICENSE"

git -C "${SOURCE_WORK}" init -q
git -C "${SOURCE_WORK}" config user.name "Agent Skills Test"
git -C "${SOURCE_WORK}" config user.email "agent-skills-test@example.invalid"
git -C "${SOURCE_WORK}" add skills LICENSE
git -C "${SOURCE_WORK}" commit -q -m "Add fixture skills"
SOURCE_REVISION="$(git -C "${SOURCE_WORK}" rev-parse HEAD)"
git clone -q --bare "${SOURCE_WORK}" "${REMOTE_ROOT}/example/source.git"

write_lock() {
  revision="$1"
  printf '%s\n' \
    $'name\tkind\trepository\tpath\trevision\tcapability\tactivation' \
    "external-one"$'\texternal\texample/source\tskills/external-one\t'"${revision}"$'\texternal-one-capability\tauto' \
    "external-two"$'\texternal\texample/source\tskills/external-two\t'"${revision}"$'\texternal-two-capability\tauto' \
    $'local-skill\tlocal\t.\tskills/local-skill\t-\tlocal-capability\tauto' \
    >"${CATALOG_ROOT}/skills.lock.tsv"
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

write_lock "0000000000000000000000000000000000000000"
printf 'preserve\n' >"${TARGET_ROOT}/sentinel"
if PATH="${FAKE_BIN}:${PATH}" \
  FETCH_LOG="${FETCH_LOG}" \
  REAL_GIT_BIN="${REAL_GIT_BIN}" \
  AGENT_SKILLS_GITHUB_BASE_URL="file://${REMOTE_ROOT}" \
  "${UPDATER}" \
    --lock "${CATALOG_ROOT}/skills.lock.tsv" \
    --catalog-root "${CATALOG_ROOT}" \
    --target "${TARGET_ROOT}" >/dev/null 2>&1; then
  printf 'not ok - fetch failure should fail\n' >&2
  exit 1
fi
test -f "${TARGET_ROOT}/sentinel"
printf 'ok - fetch failure preserves the existing target\n'

write_lock "${SOURCE_REVISION}"
: >"${FETCH_LOG}"
PATH="${FAKE_BIN}:${PATH}" \
  FETCH_LOG="${FETCH_LOG}" \
  REAL_GIT_BIN="${REAL_GIT_BIN}" \
  AGENT_SKILLS_GITHUB_BASE_URL="file://${REMOTE_ROOT}" \
  "${UPDATER}" \
    --lock "${CATALOG_ROOT}/skills.lock.tsv" \
    --catalog-root "${CATALOG_ROOT}" \
    --target "${TARGET_ROOT}" >/dev/null

test ! -e "${TARGET_ROOT}/sentinel"
test -f "${TARGET_ROOT}/external-one/SKILL.md"
test -f "${TARGET_ROOT}/external-two/SKILL.md"
test -f "${TARGET_ROOT}/local-skill/SKILL.md"
printf 'ok - installs external and local skills\n'
test -f "${CATALOG_ROOT}/third-party-licenses/example--source/LICENSE"
test -f "${CATALOG_ROOT}/third-party-licenses/example--source/SOURCE.md"
printf 'ok - preserves source license and provenance\n'

fetch_count="$(wc -l <"${FETCH_LOG}" | tr -d ' ')"
test "${fetch_count}" = "1"
printf 'ok - fetches one pinned source only once\n'

first_digest="$(find "${TARGET_ROOT}" -type f -print0 | sort -z | xargs -0 shasum | shasum | awk '{print $1}')"
: >"${FETCH_LOG}"
PATH="${FAKE_BIN}:${PATH}" \
  FETCH_LOG="${FETCH_LOG}" \
  REAL_GIT_BIN="${REAL_GIT_BIN}" \
  AGENT_SKILLS_GITHUB_BASE_URL="file://${REMOTE_ROOT}" \
  "${UPDATER}" \
    --lock "${CATALOG_ROOT}/skills.lock.tsv" \
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
  "${UPDATER}" \
    --check \
    --lock "${CATALOG_ROOT}/skills.lock.tsv" \
    --catalog-root "${CATALOG_ROOT}" \
    --target "${TARGET_ROOT}" >/dev/null
printf 'ok - check mode accepts a matching snapshot\n'

printf '1..6\n'
