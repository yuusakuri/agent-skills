#!/usr/bin/env python3
"""Parse and validate the agent skill catalog manifest."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path, PurePosixPath
import re
import tomllib
from typing import Any


NAME_PATTERN = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
REPOSITORY_PATTERN = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")
REVISION_PATTERN = re.compile(r"^[0-9a-f]{40}$")
SOURCE_KEYS = {
    "id",
    "kind",
    "repository",
    "revision",
    "license",
    "license_file",
    "notice_file",
    "activation",
    "skills",
}
SKILL_KEYS = {"name", "path", "capability", "activation"}


class CatalogError(ValueError):
    """Raised when catalog metadata violates the supported schema."""


@dataclass(frozen=True)
class Skill:
    name: str
    path: PurePosixPath
    capability: str
    activation: str


@dataclass(frozen=True)
class Source:
    id: str
    kind: str
    repository: str
    revision: str | None
    license: str
    license_file: PurePosixPath | None
    notice_file: PurePosixPath | None
    activation: str
    skills: tuple[Skill, ...]


@dataclass(frozen=True)
class Catalog:
    version: int
    sources: tuple[Source, ...]

    @property
    def skills(self) -> tuple[Skill, ...]:
        return tuple(skill for source in self.sources for skill in source.skills)


def _required_string(mapping: dict[str, Any], key: str, context: str) -> str:
    value = mapping.get(key)
    if not isinstance(value, str) or not value.strip():
        raise CatalogError(f"{context} {key} must be a non-empty string")
    return value


def _relative_path(value: str, context: str) -> PurePosixPath:
    path = PurePosixPath(value)
    if (
        "\\" in value
        or path.is_absolute()
        or not path.parts
        or any(part in {"", ".", ".."} for part in path.parts)
    ):
        raise CatalogError(f"{context} path must be repository-relative: {value}")
    return path


def declared_skill_name(skill_file: Path) -> str | None:
    try:
        lines = skill_file.read_text(encoding="utf-8").splitlines()
    except UnicodeDecodeError as error:
        raise CatalogError(f"SKILL.md must be UTF-8: {skill_file}") from error
    if not lines or lines[0].strip() != "---":
        return None
    for line in lines[1:]:
        if line.strip() == "---":
            break
        if line.startswith("name:"):
            return line.split(":", 1)[1].strip().strip("\"'")
    return None


def _parse_skill(
    raw_skill: Any,
    source_id: str,
    default_activation: str,
) -> Skill:
    context = f"source {source_id} skill"
    if not isinstance(raw_skill, dict):
        raise CatalogError(f"{context} must be a table")
    unexpected = set(raw_skill) - SKILL_KEYS
    if unexpected:
        raise CatalogError(
            f"{context} has unsupported keys: {', '.join(sorted(unexpected))}"
        )

    name = _required_string(raw_skill, "name", context)
    capability = _required_string(raw_skill, "capability", context)
    path = _relative_path(_required_string(raw_skill, "path", context), context)
    activation_value = raw_skill.get("activation", default_activation)
    if not isinstance(activation_value, str) or not activation_value.strip():
        raise CatalogError(f"{context} activation must be a non-empty string")
    if not NAME_PATTERN.fullmatch(name):
        raise CatalogError(f"invalid skill name: {name}")
    if not NAME_PATTERN.fullmatch(capability):
        raise CatalogError(f"invalid capability: {capability}")
    return Skill(name, path, capability, activation_value)


def _parse_source(raw_source: Any) -> Source:
    if not isinstance(raw_source, dict):
        raise CatalogError("each source must be a table")
    source_id = _required_string(raw_source, "id", "source")
    unexpected = set(raw_source) - SOURCE_KEYS
    if unexpected:
        raise CatalogError(
            f"source {source_id} has unsupported keys: "
            f"{', '.join(sorted(unexpected))}"
        )
    if not NAME_PATTERN.fullmatch(source_id):
        raise CatalogError(f"invalid source id: {source_id}")

    kind = _required_string(raw_source, "kind", f"source {source_id}")
    if kind not in {"vendored", "local"}:
        raise CatalogError(
            f"source kind must be vendored or local: {source_id} has {kind}"
        )

    repository = _required_string(
        raw_source, "repository", f"source {source_id}"
    )
    license_name = _required_string(raw_source, "license", f"source {source_id}")
    activation = _required_string(
        raw_source, "activation", f"source {source_id}"
    )

    revision_value = raw_source.get("revision")
    license_value = raw_source.get("license_file")
    notice_value = raw_source.get("notice_file")
    revision: str | None = None
    license_file: PurePosixPath | None = None
    notice_file: PurePosixPath | None = None

    if kind == "vendored":
        if not REPOSITORY_PATTERN.fullmatch(repository):
            raise CatalogError(
                f"vendored repository must use owner/name format: {repository}"
            )
        if not isinstance(revision_value, str) or not REVISION_PATTERN.fullmatch(
            revision_value
        ):
            raise CatalogError(
                f"vendored revision must be a 40-character commit: {source_id}"
            )
        revision = revision_value
        if not isinstance(license_value, str):
            raise CatalogError(
                f"vendored source must declare license_file: {source_id}"
            )
        license_file = _relative_path(
            license_value, f"source {source_id} license_file"
        )
        if notice_value is not None:
            if not isinstance(notice_value, str):
                raise CatalogError(
                    f"source {source_id} notice_file must be a string"
                )
            notice_file = _relative_path(
                notice_value, f"source {source_id} notice_file"
            )
    else:
        if repository != ".":
            raise CatalogError(f"local repository must be '.': {source_id}")
        if revision_value is not None:
            raise CatalogError(f"local source must not declare revision: {source_id}")
        if license_value is not None or notice_value is not None:
            raise CatalogError(
                f"local source must use the catalog license: {source_id}"
            )

    raw_skills = raw_source.get("skills")
    if not isinstance(raw_skills, list) or not raw_skills:
        raise CatalogError(f"source must declare at least one skill: {source_id}")
    skills = tuple(
        _parse_skill(raw_skill, source_id, activation)
        for raw_skill in raw_skills
    )
    return Source(
        source_id,
        kind,
        repository,
        revision,
        license_name,
        license_file,
        notice_file,
        activation,
        skills,
    )


def load_catalog(
    catalog_path: Path,
    catalog_root: Path,
    *,
    check_local: bool = True,
) -> Catalog:
    """Load and validate catalog metadata."""
    with catalog_path.open("rb") as catalog_file:
        raw_catalog = tomllib.load(catalog_file)
    if set(raw_catalog) != {"version", "sources"}:
        unexpected = set(raw_catalog) - {"version", "sources"}
        missing = {"version", "sources"} - set(raw_catalog)
        details = []
        if unexpected:
            details.append(f"unsupported keys: {', '.join(sorted(unexpected))}")
        if missing:
            details.append(f"missing keys: {', '.join(sorted(missing))}")
        raise CatalogError(f"invalid catalog root ({'; '.join(details)})")
    if raw_catalog["version"] != 1:
        raise CatalogError("catalog version must be 1")
    if not isinstance(raw_catalog["sources"], list) or not raw_catalog["sources"]:
        raise CatalogError("catalog sources must be a non-empty array")

    sources = tuple(_parse_source(source) for source in raw_catalog["sources"])
    source_ids: set[str] = set()
    repositories: set[str] = set()
    names: set[str] = set()
    capabilities: set[str] = set()

    for source in sources:
        if source.id in source_ids:
            raise CatalogError(f"duplicate source id: {source.id}")
        source_ids.add(source.id)
        if source.repository in repositories:
            raise CatalogError(f"duplicate source repository: {source.repository}")
        repositories.add(source.repository)

        for skill in source.skills:
            if skill.name in names:
                raise CatalogError(f"duplicate skill name: {skill.name}")
            names.add(skill.name)
            if skill.capability in capabilities:
                raise CatalogError(f"duplicate capability: {skill.capability}")
            capabilities.add(skill.capability)

            if source.kind == "local" and check_local:
                skill_file = catalog_root.joinpath(*skill.path.parts, "SKILL.md")
                if not skill_file.is_file():
                    raise CatalogError(
                        f"local skill is missing SKILL.md: {skill.path}"
                    )
                declared_name = declared_skill_name(skill_file)
                if declared_name != skill.name:
                    raise CatalogError(
                        f"local SKILL.md name does not match {skill.name}: "
                        f"{declared_name or '<missing>'}"
                    )

    return Catalog(1, sources)
