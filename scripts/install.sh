#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_CATALOG_ROOT="$(cd "${SCRIPT_DIRECTORY}/.." && pwd)"
LOCK_FILE="${DEFAULT_CATALOG_ROOT}/skills.lock.tsv"
CATALOG_ROOT="${DEFAULT_CATALOG_ROOT}"
TARGET_PATH=""

usage() {
  printf 'Usage: %s [--lock FILE] [--catalog-root DIR] --target DIR\n' "$0"
}

fail() {
  printf 'agent skills install failed: %s\n' "$*" >&2
  exit 1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --lock)
      [ "$#" -ge 2 ] || fail "--lock requires a file"
      LOCK_FILE="$2"
      shift 2
      ;;
    --catalog-root)
      [ "$#" -ge 2 ] || fail "--catalog-root requires a directory"
      CATALOG_ROOT="$2"
      shift 2
      ;;
    --target)
      [ "$#" -ge 2 ] || fail "--target requires a directory"
      TARGET_PATH="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

[ -n "${TARGET_PATH}" ] || fail "--target is required"
[ -d "${CATALOG_ROOT}" ] || fail "catalog root not found: ${CATALOG_ROOT}"
[ -f "${LOCK_FILE}" ] || fail "lock file not found: ${LOCK_FILE}"

target_parent_input="$(dirname "${TARGET_PATH}")"
target_name="$(basename "${TARGET_PATH}")"
[ -n "${target_name}" ] && [ "${target_name}" != "." ] && [ "${target_name}" != ".." ] ||
  fail "unsafe target path: ${TARGET_PATH}"
mkdir -p "${target_parent_input}"
target_parent="$(cd "${target_parent_input}" && pwd -P)"
target_path="${target_parent}/${target_name}"
catalog_root="$(cd "${CATALOG_ROOT}" && pwd -P)"

[ "${target_path}" != "/" ] || fail "refusing to replace filesystem root"
[ "${target_path}" != "${catalog_root}" ] || fail "refusing to replace catalog root"
if [ -n "${HOME:-}" ]; then
  user_home_path="$(cd "${HOME}" && pwd -P)"
  [ "${target_path}" != "${user_home_path}" ] || fail "refusing to replace user home"
fi

"${SCRIPT_DIRECTORY}/validate.sh" "${LOCK_FILE}" "${catalog_root}" >/dev/null

command -v gh >/dev/null 2>&1 || fail "GitHub CLI (gh) is required"
gh skill --help >/dev/null 2>&1 || fail "GitHub CLI skill support is required"

stage_root="$(mktemp -d "${target_parent}/.agent-skills-stage.XXXXXX")"
backup_root=""
replacement_path="${stage_root}/replacement"
stage_skills="${stage_root}/project/.agents/skills"

cleanup() {
  if [ -n "${backup_root}" ] && [ -d "${backup_root}/previous" ] && [ ! -e "${target_path}" ]; then
    mv "${backup_root}/previous" "${target_path}"
  fi
  [ ! -d "${stage_root}" ] || rm -rf "${stage_root}"
  if [ -n "${backup_root}" ] && [ -d "${backup_root}" ]; then
    rm -rf "${backup_root}"
  fi
}
trap cleanup EXIT

mkdir -p "${stage_root}/project"

while IFS=$'\t' read -r skill_name skill_kind repository skill_path revision _capability _activation; do
  [ "${skill_name}" = "name" ] && continue
  [ -n "${skill_name}" ] || continue

  if [ "${skill_kind}" = "external" ]; then
    (
      cd "${stage_root}/project"
      gh skill install "${repository}" "${skill_path}" \
        --agent codex \
        --scope project \
        --pin "${revision}"
    ) || fail "could not install ${skill_name} from ${repository}/${skill_path}@${revision}"
  else
    mkdir -p "${stage_skills}"
    cp -R "${catalog_root}/${skill_path}" "${stage_skills}/${skill_name}"
  fi

  installed_skill="${stage_skills}/${skill_name}/SKILL.md"
  [ -f "${installed_skill}" ] || fail "installed skill is missing SKILL.md: ${skill_name}"
  installed_name="$(sed -n 's/^name:[[:space:]]*//p' "${installed_skill}" | head -1 | tr -d '"')"
  [ "${installed_name}" = "${skill_name}" ] ||
    fail "installed skill name mismatch: expected ${skill_name}, got ${installed_name:-missing}"
done <"${LOCK_FILE}"

expected_count="$(awk -F '\t' 'NR > 1 && NF > 0 { count++ } END { print count + 0 }' "${LOCK_FILE}")"
actual_count="$(find "${stage_skills}" -mindepth 2 -maxdepth 2 -name SKILL.md -type f | wc -l | tr -d ' ')"
[ "${actual_count}" = "${expected_count}" ] ||
  fail "installed skill count mismatch: expected ${expected_count}, got ${actual_count}"

mv "${stage_skills}" "${replacement_path}"
backup_root="$(mktemp -d "${target_parent}/.agent-skills-backup.XXXXXX")"
if [ -e "${target_path}" ]; then
  mv "${target_path}" "${backup_root}/previous"
fi
mv "${replacement_path}" "${target_path}"

rm -rf "${backup_root}"
backup_root=""
rm -rf "${stage_root}"
trap - EXIT

printf 'Installed %s skills into %s\n' "${actual_count}" "${target_path}"
