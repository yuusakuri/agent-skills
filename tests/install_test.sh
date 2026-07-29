#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="${REPOSITORY_ROOT}/scripts/install.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/agent-skills-install.XXXXXX")"
trap 'rm -rf "${TEST_ROOT}"' EXIT

CATALOG_ROOT="${TEST_ROOT}/catalog"
TARGET_ROOT="${TEST_ROOT}/project/.agents/skills"
FAKE_BIN="${TEST_ROOT}/bin"
mkdir -p "${CATALOG_ROOT}/skills/local-skill" "${TARGET_ROOT}" "${FAKE_BIN}"

printf '%s\n' \
  '---' \
  'name: local-skill' \
  'description: Local test fixture skill.' \
  '---' \
  '# Local fixture' \
  >"${CATALOG_ROOT}/skills/local-skill/SKILL.md"

printf '%s\n' \
  $'name\tkind\trepository\tpath\trevision\tcapability\tactivation' \
  $'external-skill\texternal\texample/source\tskills/external-skill\t0123456789abcdef0123456789abcdef01234567\texternal-capability\tauto' \
  $'local-skill\tlocal\t.\tskills/local-skill\t-\tlocal-capability\tauto' \
  >"${CATALOG_ROOT}/skills.lock.tsv"

printf '%s\n' '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'if [ "${1:-}" = "skill" ] && [ "${2:-}" = "--help" ]; then exit 0; fi' \
  'if [ "${1:-}" != "skill" ] || [ "${2:-}" != "install" ]; then exit 64; fi' \
  'if [ "${FAIL_FETCH:-0}" = "1" ]; then exit 42; fi' \
  'skill_path="${4}"' \
  'skill_name="${skill_path##*/}"' \
  'mkdir -p ".agents/skills/${skill_name}"' \
  'printf "%s\n" "---" "name: ${skill_name}" "description: External test fixture skill." "---" "# External fixture" >".agents/skills/${skill_name}/SKILL.md"' \
  >"${FAKE_BIN}/gh"
chmod +x "${FAKE_BIN}/gh"

printf 'preserve\n' >"${TARGET_ROOT}/sentinel"
if PATH="${FAKE_BIN}:${PATH}" FAIL_FETCH=1 "${INSTALLER}" \
  --lock "${CATALOG_ROOT}/skills.lock.tsv" \
  --catalog-root "${CATALOG_ROOT}" \
  --target "${TARGET_ROOT}" >/dev/null 2>&1; then
  printf 'not ok - fetch failure should fail\n' >&2
  exit 1
fi
test -f "${TARGET_ROOT}/sentinel"
printf 'ok - fetch failure preserves the existing target\n'

PATH="${FAKE_BIN}:${PATH}" "${INSTALLER}" \
  --lock "${CATALOG_ROOT}/skills.lock.tsv" \
  --catalog-root "${CATALOG_ROOT}" \
  --target "${TARGET_ROOT}" >/dev/null

test ! -e "${TARGET_ROOT}/sentinel"
test -f "${TARGET_ROOT}/external-skill/SKILL.md"
test -f "${TARGET_ROOT}/local-skill/SKILL.md"
first_digest="$(find "${TARGET_ROOT}" -type f -print0 | sort -z | xargs -0 shasum | shasum | awk '{print $1}')"
printf 'ok - installs external and local skills\n'

PATH="${FAKE_BIN}:${PATH}" "${INSTALLER}" \
  --lock "${CATALOG_ROOT}/skills.lock.tsv" \
  --catalog-root "${CATALOG_ROOT}" \
  --target "${TARGET_ROOT}" >/dev/null
second_digest="$(find "${TARGET_ROOT}" -type f -print0 | sort -z | xargs -0 shasum | shasum | awk '{print $1}')"
test "${first_digest}" = "${second_digest}"
printf 'ok - reinstall is idempotent\n'

printf '1..3\n'
