#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_CATALOG_ROOT="$(cd "${SCRIPT_DIRECTORY}/.." && pwd)"
LOCK_FILE="${DEFAULT_CATALOG_ROOT}/skills.lock.tsv"
CATALOG_ROOT="${DEFAULT_CATALOG_ROOT}"
TARGET_PATH="${DEFAULT_CATALOG_ROOT}/skills"
CHECK_ONLY=false

usage() {
  printf 'Usage: %s [--lock FILE] [--catalog-root DIR] [--target DIR] [--check]\n' "$0"
}

fail() {
  printf 'vendored skills update failed: %s\n' "$*" >&2
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
    --check)
      CHECK_ONLY=true
      shift
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

command -v git >/dev/null 2>&1 || fail "Git is required"
github_base_url="${AGENT_SKILLS_GITHUB_BASE_URL:-https://github.com}"
github_base_url="${github_base_url%/}"

stage_root="$(mktemp -d "${target_parent}/.agent-skills-stage.XXXXXX")"
backup_root=""
skills_replaced=false
licenses_replaced=false
replacement_path="${stage_root}/replacement"
stage_skills="${stage_root}/project/.agents/skills"
stage_licenses="${stage_root}/third-party-licenses"
licenses_path="${catalog_root}/third-party-licenses"

cleanup() {
  if [ -n "${backup_root}" ] && [ -d "${backup_root}" ]; then
    if [ -d "${backup_root}/previous" ]; then
      [ ! -e "${target_path}" ] || mv "${target_path}" "${stage_root}/failed-skills"
      mv "${backup_root}/previous" "${target_path}"
    elif [ "${skills_replaced}" = true ] && [ -e "${target_path}" ]; then
      mv "${target_path}" "${stage_root}/failed-skills"
    fi
    if [ -d "${backup_root}/previous-licenses" ]; then
      [ ! -e "${licenses_path}" ] || mv "${licenses_path}" "${stage_root}/failed-licenses"
      mv "${backup_root}/previous-licenses" "${licenses_path}"
    elif [ "${licenses_replaced}" = true ] && [ -e "${licenses_path}" ]; then
      mv "${licenses_path}" "${stage_root}/failed-licenses"
    fi
    rm -rf "${backup_root}"
  fi
  [ ! -d "${stage_root}" ] || rm -rf "${stage_root}"
}
trap cleanup EXIT

mkdir -p "${stage_root}/project"

external_sources="${stage_root}/external-sources.tsv"
awk -F '\t' 'NR > 1 && $2 == "external" { print $3 "\t" $5 }' "${LOCK_FILE}" |
  LC_ALL=C sort -u >"${external_sources}"

source_index=0
while IFS=$'\t' read -r repository revision; do
  [ -n "${repository}" ] || continue
  source_index=$((source_index + 1))
  source_checkout="${stage_root}/sources/${source_index}"
  source_paths=()

  while IFS=$'\t' read -r _skill_name skill_kind lock_repository skill_path lock_revision _capability _activation; do
    [ "${skill_kind}" = "external" ] || continue
    [ "${lock_repository}" = "${repository}" ] || continue
    [ "${lock_revision}" = "${revision}" ] || continue
    source_paths+=("${skill_path}")
  done <"${LOCK_FILE}"

  git init -q "${source_checkout}"
  git -C "${source_checkout}" remote add origin "${github_base_url}/${repository}.git"
  git -C "${source_checkout}" sparse-checkout init --cone
  git -C "${source_checkout}" sparse-checkout set "${source_paths[@]}"
  git -C "${source_checkout}" fetch -q --depth 1 origin "${revision}" ||
    fail "could not fetch ${repository}@${revision}"
  git -C "${source_checkout}" checkout -q --detach FETCH_HEAD

  fetched_revision="$(git -C "${source_checkout}" rev-parse HEAD)"
  [ "${fetched_revision}" = "${revision}" ] ||
    fail "fetched revision mismatch for ${repository}: expected ${revision}, got ${fetched_revision}"

  license_file="$(find "${source_checkout}" -maxdepth 1 -type f \( -iname 'LICENSE' -o -iname 'LICENSE.*' \) | LC_ALL=C sort | head -1)"
  [ -n "${license_file}" ] ||
    fail "vendored source has no repository-level license: ${repository}@${revision}"
  vendor_name="${repository//\//--}"
  mkdir -p "${stage_licenses}/${vendor_name}"
  cp "${license_file}" "${stage_licenses}/${vendor_name}/LICENSE"
  {
    printf '# Upstream source\n\n'
    printf -- '- Repository: https://github.com/%s\n' "${repository}"
    printf -- '- Revision: `%s`\n' "${revision}"
    printf -- '- License file: `%s`\n' "$(basename "${license_file}")"
  } >"${stage_licenses}/${vendor_name}/SOURCE.md"

  while IFS=$'\t' read -r skill_name skill_kind lock_repository skill_path lock_revision _capability _activation; do
    [ "${skill_kind}" = "external" ] || continue
    [ "${lock_repository}" = "${repository}" ] || continue
    [ "${lock_revision}" = "${revision}" ] || continue

    source_skill="${source_checkout}/${skill_path}"
    [ -d "${source_skill}" ] ||
      fail "source skill directory is missing: ${repository}/${skill_path}@${revision}"
    resolved_source_skill="$(cd "${source_skill}" && pwd -P)"
    case "${resolved_source_skill}" in
      "${source_checkout}"/*) ;;
      *) fail "source skill escapes checkout: ${repository}/${skill_path}" ;;
    esac

    mkdir -p "${stage_skills}"
    cp -R "${source_skill}" "${stage_skills}/${skill_name}"
  done <"${LOCK_FILE}"
done <"${external_sources}"

while IFS=$'\t' read -r skill_name skill_kind _repository skill_path _revision _capability _activation; do
  [ "${skill_name}" = "name" ] && continue
  [ -n "${skill_name}" ] || continue

  if [ "${skill_kind}" = "local" ]; then
    mkdir -p "${stage_skills}"
    cp -R "${catalog_root}/${skill_path}" "${stage_skills}/${skill_name}"
  fi
done <"${LOCK_FILE}"

while IFS=$'\t' read -r skill_name skill_kind repository skill_path revision _capability _activation; do
  [ "${skill_name}" = "name" ] && continue
  [ -n "${skill_name}" ] || continue
  [ "${skill_kind}" = "submodule" ] || continue

  vendor_name="${repository//\//--}"
  vendor_checkout="${catalog_root}/vendor/${vendor_name}"
  [ -d "${vendor_checkout}" ] || fail "submodule checkout is missing: ${vendor_checkout}"
  actual_revision="$(git -C "${vendor_checkout}" rev-parse HEAD)"
  [ "${actual_revision}" = "${revision}" ] ||
    fail "submodule revision mismatch for ${repository}: expected ${revision}, got ${actual_revision}"
  [ -f "${vendor_checkout}/${skill_path}/SKILL.md" ] ||
    fail "submodule skill is missing SKILL.md: ${repository}/${skill_path}"

  mkdir -p "${stage_skills}"
  ln -s "../vendor/${vendor_name}/${skill_path}" "${stage_skills}/${skill_name}"
done <"${LOCK_FILE}"

while IFS=$'\t' read -r skill_name _skill_kind _repository _skill_path _revision _capability _activation; do
  [ "${skill_name}" = "name" ] && continue
  [ -n "${skill_name}" ] || continue
  if [ -L "${stage_skills}/${skill_name}" ]; then
    repository="$(awk -F '\t' -v name="${skill_name}" 'NR > 1 && $1 == name { print $3; exit }' "${LOCK_FILE}")"
    skill_path="$(awk -F '\t' -v name="${skill_name}" 'NR > 1 && $1 == name { print $4; exit }' "${LOCK_FILE}")"
    vendor_name="${repository//\//--}"
    installed_skill="${catalog_root}/vendor/${vendor_name}/${skill_path}/SKILL.md"
  else
    installed_skill="${stage_skills}/${skill_name}/SKILL.md"
  fi
  [ -f "${installed_skill}" ] || fail "installed skill is missing SKILL.md: ${skill_name}"
  installed_name="$(sed -n 's/^name:[[:space:]]*//p' "${installed_skill}" | head -1 | tr -d '"')"
  [ "${installed_name}" = "${skill_name}" ] ||
    fail "installed skill name mismatch: expected ${skill_name}, got ${installed_name:-missing}"
done <"${LOCK_FILE}"

expected_count="$(awk -F '\t' 'NR > 1 && NF > 0 { count++ } END { print count + 0 }' "${LOCK_FILE}")"
actual_count="$(find "${stage_skills}" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) | wc -l | tr -d ' ')"
[ "${actual_count}" = "${expected_count}" ] ||
  fail "vendored skill count mismatch: expected ${expected_count}, got ${actual_count}"

if [ "${CHECK_ONLY}" = true ]; then
  [ -d "${target_path}" ] || fail "vendored target is missing: ${target_path}"
  [ -d "${licenses_path}" ] || fail "third-party licenses are missing: ${licenses_path}"
  git diff --no-index --quiet --no-ext-diff -- "${target_path}" "${stage_skills}" ||
    fail "vendored skills differ from pinned sources"
  git diff --no-index --quiet --no-ext-diff -- "${licenses_path}" "${stage_licenses}" ||
    fail "third-party licenses differ from pinned sources"
  rm -rf "${stage_root}"
  trap - EXIT
  printf 'Verified %s vendored skills in %s\n' "${actual_count}" "${target_path}"
  exit 0
fi

mv "${stage_skills}" "${replacement_path}"
backup_root="$(mktemp -d "${target_parent}/.agent-skills-backup.XXXXXX")"
if [ -e "${target_path}" ]; then
  mv "${target_path}" "${backup_root}/previous"
fi
mv "${replacement_path}" "${target_path}"
skills_replaced=true

licenses_backup="${backup_root}/previous-licenses"
if [ -e "${licenses_path}" ]; then
  mv "${licenses_path}" "${licenses_backup}"
fi
mv "${stage_licenses}" "${licenses_path}"
licenses_replaced=true

rm -rf "${backup_root}"
backup_root=""
rm -rf "${stage_root}"
trap - EXIT

printf 'Updated %s vendored skills in %s\n' "${actual_count}" "${target_path}"
