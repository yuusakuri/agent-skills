#!/usr/bin/env python3
"""Validate catalog.toml and local skill metadata."""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path
import re
import sys
import tomllib

from catalog_manifest import Catalog, CatalogError, NAME_PATTERN, load_catalog


RESOURCE_REFERENCE_PATTERN = re.compile(
    r"(?<![A-Za-z0-9_./-])"
    r"((?:references|scripts|assets)/[A-Za-z0-9_./-]+)"
)
MARKDOWN_LINK_PATTERN = re.compile(r"\[[^\]]*]\(([^)]+)\)")
BACKTICK_NAME_PATTERN = re.compile(r"`([a-z0-9]+(?:-[a-z0-9]+)+)`")


def parse_args() -> argparse.Namespace:
    repository_root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--catalog",
        type=Path,
        default=repository_root / "catalog.toml",
        help="catalog TOML file",
    )
    parser.add_argument(
        "--catalog-root",
        type=Path,
        default=repository_root,
        help="directory containing the catalog and local skills",
    )
    parser.add_argument(
        "--schema-only",
        action="store_true",
        help="validate manifest schema without checking the generated snapshot",
    )
    return parser.parse_args()


def frontmatter(skill_file: Path) -> tuple[str, str]:
    lines = skill_file.read_text(encoding="utf-8").splitlines()
    if len(lines) > 500:
        raise CatalogError(f"SKILL.md exceeds 500 lines: {skill_file}")
    if not lines or lines[0].strip() != "---":
        raise CatalogError(f"SKILL.md is missing YAML frontmatter: {skill_file}")
    try:
        closing = next(
            index
            for index, line in enumerate(lines[1:], start=1)
            if line.strip() == "---"
        )
    except StopIteration as error:
        raise CatalogError(
            f"SKILL.md frontmatter is not closed: {skill_file}"
        ) from error

    values: dict[str, str] = {}
    index = 1
    while index < closing:
        line = lines[index]
        if line.startswith((" ", "\t")) or ":" not in line:
            index += 1
            continue
        key, raw_value = line.split(":", 1)
        value = raw_value.strip()
        if value in {"|", ">", "|-", ">-"}:
            block: list[str] = []
            index += 1
            while index < closing and (
                not lines[index].strip()
                or lines[index].startswith((" ", "\t"))
            ):
                block.append(lines[index].strip())
                index += 1
            values[key] = " ".join(part for part in block if part)
            continue
        values[key] = value.strip("\"'")
        index += 1

    name = values.get("name", "")
    description = values.get("description", "")
    if not name or not description:
        raise CatalogError(
            f"SKILL.md requires name and description: {skill_file}"
        )
    if not NAME_PATTERN.fullmatch(name) or len(name) > 64:
        raise CatalogError(f"invalid SKILL.md name: {skill_file}: {name}")
    if len(description) > 1024:
        raise CatalogError(
            f"SKILL.md description exceeds 1024 characters: {skill_file}"
        )

    in_metadata = False
    for line in lines[1:closing]:
        if line == "metadata:":
            in_metadata = True
            continue
        if not in_metadata:
            continue
        if line and not line.startswith((" ", "\t")):
            in_metadata = False
            continue
        if not line.strip():
            continue
        if not line.startswith("  ") or line.startswith("    ") or ":" not in line:
            raise CatalogError(
                f"metadata must be a flat string map: {skill_file}: {line}"
            )
        _, raw_value = line.strip().split(":", 1)
        value = raw_value.strip()
        if (
            not value
            or value.startswith(("[", "{"))
            or value.lower() in {"true", "false", "null", "~"}
            or re.fullmatch(r"[+-]?[0-9]+(?:\.[0-9]+)?", value)
            or re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}", value)
        ):
            raise CatalogError(
                f"metadata values must be strings: {skill_file}: {line.strip()}"
            )
    return name, description


def validate_resource_references(skill_dir: Path) -> None:
    skill_file = skill_dir / "SKILL.md"
    content = skill_file.read_text(encoding="utf-8")
    for raw_reference in RESOURCE_REFERENCE_PATTERN.findall(content):
        reference = raw_reference.rstrip(".,:;)")
        referenced_path = skill_dir / reference
        if not referenced_path.exists():
            raise CatalogError(
                f"broken local reference in {skill_dir.name}: {reference}"
            )
    for raw_reference in MARKDOWN_LINK_PATTERN.findall(content):
        reference = raw_reference.split("#", 1)[0].strip().strip("<>")
        if (
            not reference
            or "://" in reference
            or reference.startswith(("mailto:", "#"))
        ):
            continue
        referenced_path = (skill_dir / reference).resolve(strict=False)
        try:
            referenced_path.relative_to(skill_dir.resolve())
        except ValueError as error:
            raise CatalogError(
                f"reference escapes skill root in {skill_dir.name}: {reference}"
            ) from error
        if not referenced_path.exists():
            raise CatalogError(
                f"broken Markdown link in {skill_dir.name}: {reference}"
            )


def validate_local_skill_references(
    catalog: Catalog,
    catalog_root: Path,
    names: set[str],
) -> None:
    for source in catalog.sources:
        if source.kind != "local":
            continue
        for skill in source.skills:
            skill_file = catalog_root / "skills" / skill.name / "SKILL.md"
            for referenced_name in BACKTICK_NAME_PATTERN.findall(
                skill_file.read_text(encoding="utf-8")
            ):
                if referenced_name not in names:
                    raise CatalogError(
                        f"local skill {skill.name} references absent skill: "
                        f"{referenced_name}"
                    )


def validate_snapshot(catalog: Catalog, catalog_root: Path) -> None:
    skills_root = catalog_root / "skills"
    if not skills_root.is_dir():
        raise CatalogError(f"generated skills directory is missing: {skills_root}")
    expected = {skill.name for skill in catalog.skills}
    actual = {
        path.name
        for path in skills_root.iterdir()
        if path.is_dir() and not path.name.startswith(".")
    }
    if actual != expected:
        raise CatalogError(
            "generated skills differ from catalog; "
            f"missing={sorted(expected - actual)}, extra={sorted(actual - expected)}"
        )

    content_hashes: dict[str, str] = {}
    descriptions: dict[str, str] = {}
    for skill_name in sorted(expected):
        skill_dir = skills_root / skill_name
        if skill_dir.is_symlink():
            raise CatalogError(
                f"canonical skill must be a regular directory: {skill_name}"
            )
        skill_file = skill_dir / "SKILL.md"
        if not skill_file.is_file():
            raise CatalogError(f"skill is missing SKILL.md: {skill_name}")
        declared_name, description = frontmatter(skill_file)
        if declared_name != skill_name:
            raise CatalogError(
                f"SKILL.md name does not match directory: "
                f"{skill_name} != {declared_name}"
            )
        digest = hashlib.sha256(skill_file.read_bytes()).hexdigest()
        if digest in content_hashes:
            raise CatalogError(
                f"duplicate SKILL.md content: "
                f"{content_hashes[digest]} and {skill_name}"
            )
        content_hashes[digest] = skill_name
        if description in descriptions:
            raise CatalogError(
                f"duplicate Skill description: "
                f"{descriptions[description]} and {skill_name}"
            )
        descriptions[description] = skill_name
        validate_resource_references(skill_dir)

    for source in catalog.sources:
        for alias in source.aliases:
            for skill in source.skills:
                skill_dir = skills_root / skill.name
                for markdown_file in skill_dir.rglob("*.md"):
                    if alias.source in markdown_file.read_text(encoding="utf-8"):
                        raise CatalogError(
                            f"unresolved skill alias in {skill.name}: "
                            f"{alias.source}"
                        )

    validate_local_skill_references(catalog, catalog_root, expected)


def main() -> int:
    args = parse_args()
    try:
        catalog = load_catalog(
            args.catalog.resolve(),
            args.catalog_root.resolve(),
        )
        if not args.schema_only:
            validate_snapshot(catalog, args.catalog_root.resolve())
    except (CatalogError, OSError, tomllib.TOMLDecodeError) as error:
        print(f"catalog validation failed: {error}", file=sys.stderr)
        return 1
    print(
        f"Validated {len(catalog.skills)} skills from "
        f"{len(catalog.sources)} sources."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
