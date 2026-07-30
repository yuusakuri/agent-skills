#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATOR="${REPOSITORY_ROOT}/scripts/validate.sh"
PASS_COUNT=0

new_fixture() {
  mktemp -d "${TMPDIR:-/tmp}/agent-skills-validate.XXXXXX"
}

write_skill() {
  local fixture_root="$1"
  local skill_name="$2"
  mkdir -p "${fixture_root}/skills/${skill_name}"
  printf '%s\n' \
    '---' \
    "name: ${skill_name}" \
    'description: Test fixture skill used by the validator test.' \
    '---' \
    '# Test fixture' \
    >"${fixture_root}/skills/${skill_name}/SKILL.md"
}

assert_success() {
  local test_name="$1"
  local fixture_root="$2"
  if "${VALIDATOR}" "${fixture_root}/skills.lock.tsv" "${fixture_root}" >/dev/null; then
    PASS_COUNT=$((PASS_COUNT + 1))
    printf 'ok - %s\n' "${test_name}"
  else
    printf 'not ok - %s\n' "${test_name}" >&2
    exit 1
  fi
}

assert_failure() {
  local test_name="$1"
  local expected_message="$2"
  local fixture_root="$3"
  local output
  if output=$("${VALIDATOR}" "${fixture_root}/skills.lock.tsv" "${fixture_root}" 2>&1); then
    printf 'not ok - %s: expected failure\n' "${test_name}" >&2
    exit 1
  fi
  if [[ "${output}" != *"${expected_message}"* ]]; then
    printf 'not ok - %s: missing error %s\n%s\n' "${test_name}" "${expected_message}" "${output}" >&2
    exit 1
  fi
  PASS_COUNT=$((PASS_COUNT + 1))
  printf 'ok - %s\n' "${test_name}"
}

valid_fixture="$(new_fixture)"
trap 'rm -rf "${valid_fixture}" "${duplicate_name_fixture:-}" "${duplicate_capability_fixture:-}" "${floating_revision_fixture:-}" "${missing_local_fixture:-}" "${traversal_fixture:-}"' EXIT
write_skill "${valid_fixture}" local-skill
mkdir -p "${valid_fixture}/vendor/example--source/skills/nested-skill"
printf '%s\n' \
  '---' \
  'name: nested-skill' \
  'description: Nested submodule fixture skill.' \
  '---' \
  '# Nested fixture' \
  >"${valid_fixture}/vendor/example--source/skills/nested-skill/SKILL.md"
printf '%s\n' \
  $'name\tkind\trepository\tpath\trevision\tcapability\tactivation' \
  $'external-skill\texternal\texample/source\tskills/external-skill\t0123456789abcdef0123456789abcdef01234567\texternal-capability\tauto' \
  $'nested-skill\tsubmodule\texample/source\tskills/nested-skill\t0123456789abcdef0123456789abcdef01234567\tnested-capability\tauto' \
  $'local-skill\tlocal\t.\tskills/local-skill\t-\tlocal-capability\tauto' \
  >"${valid_fixture}/skills.lock.tsv"
assert_success 'accepts a valid lock' "${valid_fixture}"

duplicate_name_fixture="$(new_fixture)"
write_skill "${duplicate_name_fixture}" local-skill
printf '%s\n' \
  $'name\tkind\trepository\tpath\trevision\tcapability\tactivation' \
  $'same-name\texternal\texample/source\tskills/one\t0123456789abcdef0123456789abcdef01234567\tone\tauto' \
  $'same-name\tlocal\t.\tskills/local-skill\t-\ttwo\tauto' \
  >"${duplicate_name_fixture}/skills.lock.tsv"
assert_failure 'rejects duplicate names' 'duplicate skill name: same-name' "${duplicate_name_fixture}"

duplicate_capability_fixture="$(new_fixture)"
write_skill "${duplicate_capability_fixture}" local-skill
printf '%s\n' \
  $'name\tkind\trepository\tpath\trevision\tcapability\tactivation' \
  $'external-skill\texternal\texample/source\tskills/one\t0123456789abcdef0123456789abcdef01234567\tsame-capability\tauto' \
  $'local-skill\tlocal\t.\tskills/local-skill\t-\tsame-capability\tauto' \
  >"${duplicate_capability_fixture}/skills.lock.tsv"
assert_failure 'rejects duplicate capabilities' 'duplicate capability: same-capability' "${duplicate_capability_fixture}"

floating_revision_fixture="$(new_fixture)"
printf '%s\n' \
  $'name\tkind\trepository\tpath\trevision\tcapability\tactivation' \
  $'external-skill\texternal\texample/source\tskills/one\tmain\texternal-capability\tauto' \
  >"${floating_revision_fixture}/skills.lock.tsv"
assert_failure 'rejects floating revisions' 'external revision must be a 40-character commit' "${floating_revision_fixture}"

missing_local_fixture="$(new_fixture)"
printf '%s\n' \
  $'name\tkind\trepository\tpath\trevision\tcapability\tactivation' \
  $'local-skill\tlocal\t.\tskills/local-skill\t-\tlocal-capability\tauto' \
  >"${missing_local_fixture}/skills.lock.tsv"
assert_failure 'rejects missing local skills' 'local skill is missing SKILL.md' "${missing_local_fixture}"

traversal_fixture="$(new_fixture)"
printf '%s\n' \
  $'name\tkind\trepository\tpath\trevision\tcapability\tactivation' \
  $'external-skill\texternal\texample/source\t../outside\t0123456789abcdef0123456789abcdef01234567\texternal-capability\tauto' \
  >"${traversal_fixture}/skills.lock.tsv"
assert_failure 'rejects path traversal' 'path must be repository-relative' "${traversal_fixture}"

printf '1..%s\n' "${PASS_COUNT}"
