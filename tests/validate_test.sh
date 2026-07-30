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

valid_fixture="$(new_fixture)"
trap 'rm -rf "${valid_fixture}" "${duplicate_name_fixture:-}" "${duplicate_capability_fixture:-}" "${floating_revision_fixture:-}" "${missing_local_fixture:-}" "${traversal_fixture:-}" "${submodule_fixture:-}" "${invalid_resource_fixture:-}" "${invalid_alias_fixture:-}" "${broken_reference_fixture:-}" "${metadata_fixture:-}"' EXIT
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

printf '1..%s\n' "${PASS_COUNT}"
