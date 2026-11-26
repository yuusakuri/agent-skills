#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATOR="${REPOSITORY_ROOT}/scripts/validate.py"
PYTHON_BIN="${PYTHON_BIN:-python3}"
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
  if "${PYTHON_BIN}" "${VALIDATOR}" \
    --catalog "${fixture_root}/catalog.toml" \
    --catalog-root "${fixture_root}" \
    --schema-only >/dev/null; then
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
  if output=$("${PYTHON_BIN}" "${VALIDATOR}" \
    --catalog "${fixture_root}/catalog.toml" \
    --catalog-root "${fixture_root}" \
    --schema-only 2>&1); then
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

assert_snapshot_failure() {
  local test_name="$1"
  local expected_message="$2"
  local fixture_root="$3"
  local output
  if output=$("${PYTHON_BIN}" "${VALIDATOR}" \
    --catalog "${fixture_root}/catalog.toml" \
    --catalog-root "${fixture_root}" 2>&1); then
    printf 'not ok - %s: expected failure\n' "${test_name}" >&2
    exit 1
  fi
  if [[ "${output}" != *"${expected_message}"* ]]; then
    printf 'not ok - %s: missing error %s\n%s\n' \
      "${test_name}" "${expected_message}" "${output}" >&2
    exit 1
  fi
  PASS_COUNT=$((PASS_COUNT + 1))
  printf 'ok - %s\n' "${test_name}"
}

assert_snapshot_success() {
  local test_name="$1"
  local fixture_root="$2"
  local output
  if ! output=$("${PYTHON_BIN}" "${VALIDATOR}" \
    --catalog "${fixture_root}/catalog.toml" \
    --catalog-root "${fixture_root}" 2>&1); then
    printf 'not ok - %s\n%s\n' "${test_name}" "${output}" >&2
    exit 1
  fi
  PASS_COUNT=$((PASS_COUNT + 1))
  printf 'ok - %s\n' "${test_name}"
}

valid_fixture="$(new_fixture)"
trap 'rm -rf "${valid_fixture}" "${duplicate_name_fixture:-}" "${duplicate_capability_fixture:-}" "${floating_revision_fixture:-}" "${missing_local_fixture:-}" "${traversal_fixture:-}" "${submodule_fixture:-}" "${invalid_resource_fixture:-}" "${invalid_alias_fixture:-}" "${broken_reference_fixture:-}" "${metadata_fixture:-}" "${namespace_fixture:-}" "${invalid_profile_fixture:-}" "${reserved_profile_fixture:-}" "${cross_profile_fixture:-}" "${sibling_fixture:-}"' EXIT
write_skill "${valid_fixture}" local-skill
cat >"${valid_fixture}/catalog.toml" <<'TOML'
version = 1

[[sources]]
id = "example-source"
kind = "vendored"
repository = "example/source"
revision = "0123456789abcdef0123456789abcdef01234567"
license = "MIT"
license_file = "LICENSE"
activation = "auto"
skills = [
  { name = "external-skill", path = "skills/external-skill", capability = "external-capability" },
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
assert_success 'accepts a valid catalog' "${valid_fixture}"

duplicate_name_fixture="$(new_fixture)"
write_skill "${duplicate_name_fixture}" local-skill
cat >"${duplicate_name_fixture}/catalog.toml" <<'TOML'
version = 1
[[sources]]
id = "example"
kind = "vendored"
repository = "example/source"
revision = "0123456789abcdef0123456789abcdef01234567"
license = "MIT"
license_file = "LICENSE"
activation = "auto"
skills = [
  { name = "same-name", path = "skills/one", capability = "one" },
  { name = "same-name", path = "skills/two", capability = "two" },
]
TOML
assert_failure 'rejects duplicate names' 'duplicate skill name: same-name' "${duplicate_name_fixture}"

duplicate_capability_fixture="$(new_fixture)"
write_skill "${duplicate_capability_fixture}" local-skill
cat >"${duplicate_capability_fixture}/catalog.toml" <<'TOML'
version = 1
[[sources]]
id = "example"
kind = "vendored"
repository = "example/source"
revision = "0123456789abcdef0123456789abcdef01234567"
license = "MIT"
license_file = "LICENSE"
activation = "auto"
skills = [
  { name = "external-one", path = "skills/one", capability = "same-capability" },
  { name = "external-two", path = "skills/two", capability = "same-capability" },
]
TOML
assert_failure 'rejects duplicate capabilities' 'duplicate capability: same-capability' "${duplicate_capability_fixture}"

floating_revision_fixture="$(new_fixture)"
cat >"${floating_revision_fixture}/catalog.toml" <<'TOML'
version = 1
[[sources]]
id = "example"
kind = "vendored"
repository = "example/source"
revision = "main"
license = "MIT"
license_file = "LICENSE"
activation = "auto"
skills = [
  { name = "external-skill", path = "skills/one", capability = "external-capability" },
]
TOML
assert_failure 'rejects floating revisions' 'vendored revision must be a 40-character commit' "${floating_revision_fixture}"

missing_local_fixture="$(new_fixture)"
cat >"${missing_local_fixture}/catalog.toml" <<'TOML'
version = 1
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
assert_failure 'rejects missing local skills' 'local skill is missing SKILL.md' "${missing_local_fixture}"

traversal_fixture="$(new_fixture)"
cat >"${traversal_fixture}/catalog.toml" <<'TOML'
version = 1
[[sources]]
id = "example"
kind = "vendored"
repository = "example/source"
revision = "0123456789abcdef0123456789abcdef01234567"
license = "MIT"
license_file = "LICENSE"
activation = "auto"
skills = [
  { name = "external-skill", path = "../outside", capability = "external-capability" },
]
TOML
assert_failure 'rejects path traversal' 'path must be repository-relative' "${traversal_fixture}"

submodule_fixture="$(new_fixture)"
cat >"${submodule_fixture}/catalog.toml" <<'TOML'
version = 1
[[sources]]
id = "example"
kind = "submodule"
repository = "example/source"
revision = "0123456789abcdef0123456789abcdef01234567"
license = "MIT"
license_file = "LICENSE"
activation = "auto"
skills = [
  { name = "external-skill", path = "skills/one", capability = "external-capability" },
]
TOML
assert_failure 'rejects nested submodules' 'source kind must be vendored or local' "${submodule_fixture}"

invalid_resource_fixture="$(new_fixture)"
cat >"${invalid_resource_fixture}/catalog.toml" <<'TOML'
version = 1
[[sources]]
id = "example"
kind = "vendored"
repository = "example/source"
revision = "0123456789abcdef0123456789abcdef01234567"
license = "MIT"
license_file = "LICENSE"
activation = "auto"
skills = [
  { name = "external-skill", path = "skills/one", capability = "external-capability", resources = ["../shared.md"] },
]
TOML
assert_failure 'rejects resource traversal' 'path must be repository-relative' "${invalid_resource_fixture}"

invalid_alias_fixture="$(new_fixture)"
cat >"${invalid_alias_fixture}/catalog.toml" <<'TOML'
version = 1
[[sources]]
id = "example"
kind = "vendored"
repository = "example/source"
revision = "0123456789abcdef0123456789abcdef01234567"
license = "MIT"
license_file = "LICENSE"
activation = "auto"
aliases = [
  { from = "retired-skill", to = "missing-skill" },
]
skills = [
  { name = "external-skill", path = "skills/one", capability = "external-capability" },
]
TOML
assert_failure 'rejects aliases to missing skills' 'alias target is not a catalog skill' "${invalid_alias_fixture}"

broken_reference_fixture="$(new_fixture)"
write_skill "${broken_reference_fixture}" local-skill
printf '\nRead `references/missing.md` before continuing.\n' \
  >>"${broken_reference_fixture}/skills/local-skill/SKILL.md"
cat >"${broken_reference_fixture}/catalog.toml" <<'TOML'
version = 1
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
assert_snapshot_failure 'rejects broken Skill resources' 'broken local reference' "${broken_reference_fixture}"

metadata_fixture="$(new_fixture)"
mkdir -p "${metadata_fixture}/skills/local-skill"
cat >"${metadata_fixture}/skills/local-skill/SKILL.md" <<'SKILL'
---
name: local-skill
description: Test fixture with invalid metadata.
metadata:
  frameworks: [one, two]
---
# Local skill
SKILL
cat >"${metadata_fixture}/catalog.toml" <<'TOML'
version = 1
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
assert_snapshot_failure 'rejects non-string metadata' 'metadata values must be strings' "${metadata_fixture}"

namespace_fixture="$(new_fixture)"
write_skill "${namespace_fixture}" external-skill
printf '\nNext, invoke example:external-skill.\n' \
  >>"${namespace_fixture}/skills/external-skill/SKILL.md"
cat >"${namespace_fixture}/catalog.toml" <<'TOML'
version = 1
[[sources]]
id = "example"
kind = "vendored"
repository = "example/source"
revision = "0123456789abcdef0123456789abcdef01234567"
license = "MIT"
license_file = "LICENSE"
activation = "auto"
namespace = "example"
skills = [
  { name = "external-skill", path = "skills/external-skill", capability = "external-capability" },
]
TOML
assert_snapshot_failure 'rejects unresolved namespaced references' 'unresolved namespaced reference in external-skill: example:external-skill' "${namespace_fixture}"

invalid_profile_fixture="$(new_fixture)"
cat >"${invalid_profile_fixture}/catalog.toml" <<'TOML'
version = 1
[[sources]]
id = "example"
kind = "vendored"
repository = "example/source"
revision = "0123456789abcdef0123456789abcdef01234567"
license = "MIT"
license_file = "LICENSE"
activation = "auto"
profile = "Not Valid"
skills = [
  { name = "external-skill", path = "skills/one", capability = "external-capability" },
]
TOML
assert_failure 'rejects invalid profile names' 'invalid profile: Not Valid' "${invalid_profile_fixture}"

reserved_profile_fixture="$(new_fixture)"
cat >"${reserved_profile_fixture}/catalog.toml" <<'TOML'
version = 1
[[sources]]
id = "example"
kind = "vendored"
repository = "example/source"
revision = "0123456789abcdef0123456789abcdef01234567"
license = "MIT"
license_file = "LICENSE"
activation = "auto"
skills = [
  { name = "external-skill", path = "skills/one", capability = "external-capability", profile = "all" },
]
TOML
assert_failure 'rejects the reserved profile name' 'profile name is reserved: all' "${reserved_profile_fixture}"

cross_profile_fixture="$(new_fixture)"
write_skill "${cross_profile_fixture}" router-skill
write_skill "${cross_profile_fixture}" product-skill
sed -i.bak 's/^description: .*/description: Product fixture skill for the profile test./' \
  "${cross_profile_fixture}/skills/product-skill/SKILL.md"
printf '\nHand off to `product-skill` afterwards.\n' \
  >>"${cross_profile_fixture}/skills/router-skill/SKILL.md"
cat >"${cross_profile_fixture}/catalog.toml" <<'TOML'
version = 1
[[sources]]
id = "catalog"
kind = "local"
repository = "."
license = "MIT"
activation = "auto"
profile = "engineering"
skills = [
  { name = "router-skill", path = "skills/router-skill", capability = "router" },
  { name = "product-skill", path = "skills/product-skill", capability = "product", profile = "product" },
]
TOML
assert_snapshot_failure 'rejects local references across profiles' 'local skill router-skill (engineering) references product-skill from profile product' "${cross_profile_fixture}"

sibling_fixture="$(new_fixture)"
write_skill "${sibling_fixture}" plan-runner
write_skill "${sibling_fixture}" review-kit
sed -i.bak 's/^description: .*/description: Review kit fixture for the sibling link test./' \
  "${sibling_fixture}/skills/review-kit/SKILL.md"
printf 'reviewer prompt\n' >"${sibling_fixture}/skills/review-kit/reviewer.md"
printf '\nDispatch [the reviewer](../review-kit/reviewer.md).\n' \
  >>"${sibling_fixture}/skills/plan-runner/SKILL.md"
cat >"${sibling_fixture}/catalog.toml" <<'TOML'
version = 1
[[sources]]
id = "catalog"
kind = "local"
repository = "."
license = "MIT"
activation = "auto"
skills = [
  { name = "plan-runner", path = "skills/plan-runner", capability = "plan-runner" },
  { name = "review-kit", path = "skills/review-kit", capability = "review-kit" },
]
TOML
assert_snapshot_success 'accepts links to a sibling skill in the same profile' "${sibling_fixture}"

sed -i.bak 's/capability = "review-kit" }/capability = "review-kit", profile = "other" }/' \
  "${sibling_fixture}/catalog.toml"
assert_snapshot_failure 'rejects links to a sibling skill in another profile' 'plan-runner links to review-kit from profile other' "${sibling_fixture}"

sed -i.bak 's/, profile = "other" }/ }/' "${sibling_fixture}/catalog.toml"
rm "${sibling_fixture}/skills/review-kit/reviewer.md"
assert_snapshot_failure 'rejects broken links to a sibling skill' 'broken Markdown link in plan-runner' "${sibling_fixture}"

printf '1..%s\n' "${PASS_COUNT}"
