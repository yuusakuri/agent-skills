#!/usr/bin/env python3
"""Synchronize Codex and Claude Code links to one canonical skill catalog.

Without a profile selection every catalog skill is exposed, and Codex reads the
catalog through a single `.agents/skills` directory link. With `--profiles`,
both agents see only the skills in the selected profiles, and the selection is
recorded in `.agents/agent-skills.toml` so later `--write` and `--check` runs
keep the same set.
"""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import shutil
import sys
import tomllib

from catalog_manifest import ALL_PROFILES, CatalogError, load_catalog


SELECTION_FILE = Path(".agents") / "agent-skills.toml"


class LinkError(ValueError):
    """Raised when an agent entrypoint cannot be synchronized safely."""


def parse_args() -> argparse.Namespace:
    repository_root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--project-root",
        type=Path,
        default=repository_root,
        help="project that should expose agent skill entrypoints",
    )
    parser.add_argument(
        "--catalog-root",
        type=Path,
        default=repository_root,
        help="catalog containing the canonical skills directory",
    )
    parser.add_argument(
        "--profiles",
        help=(
            "comma-separated profiles to expose, or 'all'; with --write the "
            "choice is recorded in .agents/agent-skills.toml"
        ),
    )
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true", help="check links only")
    mode.add_argument("--write", action="store_true", help="synchronize links")
    return parser.parse_args()


def relative_target(link: Path, target: Path) -> str:
    return os.path.relpath(target, start=link.parent)


def link_matches(link: Path, target: Path) -> bool:
    return link.is_symlink() and os.readlink(link) == relative_target(link, target)


def ensure_link(link: Path, target: Path, write: bool) -> None:
    if link_matches(link, target):
        return
    if not write:
        raise LinkError(f"link is missing or stale: {link}")
    if link.exists() and not link.is_symlink():
        raise LinkError(f"refusing to replace a non-symlink: {link}")
    if link.is_symlink():
        link.unlink()
    link.parent.mkdir(parents=True, exist_ok=True)
    link.symlink_to(relative_target(link, target))


def is_catalog_link(link: Path, skills_root: Path) -> bool:
    if not link.is_symlink():
        return False
    unresolved_target = (link.parent / os.readlink(link)).resolve(strict=False)
    try:
        unresolved_target.relative_to(skills_root.resolve())
    except ValueError:
        return False
    return True


def parse_profiles(value: str) -> tuple[str, ...] | None:
    profiles = tuple(
        sorted({part.strip() for part in value.split(",") if part.strip()})
    )
    if not profiles:
        raise LinkError("--profiles needs at least one profile or 'all'")
    if ALL_PROFILES in profiles:
        if len(profiles) > 1:
            raise LinkError("'all' cannot be combined with other profiles")
        return None
    return profiles


def read_selection(project_root: Path) -> tuple[str, ...] | None:
    selection_file = project_root / SELECTION_FILE
    if not selection_file.is_file():
        return None
    with selection_file.open("rb") as handle:
        raw = tomllib.load(handle)
    profiles = raw.get("profiles")
    if (
        set(raw) != {"profiles"}
        or not isinstance(profiles, list)
        or not profiles
        or not all(isinstance(profile, str) for profile in profiles)
    ):
        raise LinkError(
            f"{selection_file} must contain only a non-empty profiles array"
        )
    return tuple(sorted(set(profiles)))


def write_selection(project_root: Path, profiles: tuple[str, ...] | None) -> None:
    selection_file = project_root / SELECTION_FILE
    if profiles is None:
        selection_file.unlink(missing_ok=True)
        return
    selection_file.parent.mkdir(parents=True, exist_ok=True)
    quoted = ", ".join(f'"{profile}"' for profile in profiles)
    selection_file.write_text(
        "# Written by agent-skills scripts/sync_agent_links.py --profiles.\n"
        f"profiles = [{quoted}]\n",
        encoding="utf-8",
    )


def selected_skill_names(
    catalog_root: Path,
    skills_root: Path,
    profiles: tuple[str, ...] | None,
) -> list[str]:
    available = sorted(
        path.name
        for path in skills_root.iterdir()
        if path.is_dir() and (path / "SKILL.md").is_file()
    )
    if not available:
        raise LinkError(f"catalog has no Skill directories: {skills_root}")
    if profiles is None:
        return available
    catalog_file = catalog_root / "catalog.toml"
    if not catalog_file.is_file():
        raise LinkError(f"profiles need the catalog manifest: {catalog_file}")
    catalog = load_catalog(catalog_file, catalog_root, check_local=False)
    names = sorted(skill.name for skill in catalog.skills_for(profiles))
    missing = sorted(set(names) - set(available))
    if missing:
        raise LinkError(f"selected skills are missing from the catalog: {missing}")
    return names


def sync_skill_directory(
    root: Path,
    skills_root: Path,
    skill_names: list[str],
    write: bool,
    label: str,
) -> None:
    """Keep one link per selected skill; leave non-catalog entries alone."""
    if root.is_symlink() or (root.exists() and not root.is_dir()):
        raise LinkError(f"{label} entrypoint must be a directory: {root}")
    if write:
        root.mkdir(parents=True, exist_ok=True)
    elif not root.is_dir():
        raise LinkError(f"{label} entrypoint is missing: {root}")

    for skill_name in skill_names:
        ensure_link(root / skill_name, skills_root / skill_name, write)

    expected = set(skill_names)
    for existing in sorted(root.iterdir()):
        if existing.name in expected or not is_catalog_link(existing, skills_root):
            continue
        if not write:
            raise LinkError(f"stale catalog link: {existing}")
        existing.unlink()


def only_catalog_links(directory: Path, skills_root: Path) -> bool:
    return all(is_catalog_link(entry, skills_root) for entry in directory.iterdir())


def sync_codex(
    project_root: Path,
    skills_root: Path,
    skill_names: list[str],
    profiles: tuple[str, ...] | None,
    write: bool,
) -> None:
    codex_root = project_root / ".agents" / "skills"
    if profiles is None and not (
        codex_root.is_dir()
        and not codex_root.is_symlink()
        and not only_catalog_links(codex_root, skills_root)
    ):
        # The whole catalog: one directory link, as before profiles existed.
        if codex_root.is_dir() and not codex_root.is_symlink():
            if not write:
                raise LinkError(f"link is missing or stale: {codex_root}")
            shutil.rmtree(codex_root)
        ensure_link(codex_root, skills_root, write)
        return

    if codex_root.is_symlink():
        if not is_catalog_link(codex_root, skills_root):
            raise LinkError(f"refusing to replace a foreign link: {codex_root}")
        if not write:
            raise LinkError(f"Codex entrypoint exposes every skill: {codex_root}")
        codex_root.unlink()
    sync_skill_directory(codex_root, skills_root, skill_names, write, "Codex")


def synchronize(
    project_root: Path,
    catalog_root: Path,
    write: bool,
    requested_profiles: str | None = None,
) -> tuple[str, ...] | None:
    project_root = project_root.resolve()
    catalog_root = catalog_root.resolve()
    skills_root = catalog_root / "skills"
    if not skills_root.is_dir():
        raise LinkError(f"catalog skills directory is missing: {skills_root}")

    if requested_profiles is not None:
        profiles = parse_profiles(requested_profiles)
    else:
        profiles = read_selection(project_root)

    # Resolve the selection fully before touching any entrypoint.
    skill_names = selected_skill_names(catalog_root, skills_root, profiles)

    sync_codex(project_root, skills_root, skill_names, profiles, write)
    sync_skill_directory(
        project_root / ".claude" / "skills",
        skills_root,
        skill_names,
        write,
        "Claude Code",
    )
    if write and requested_profiles is not None:
        write_selection(project_root, profiles)
    elif not write and requested_profiles is not None:
        if read_selection(project_root) != profiles:
            raise LinkError("recorded profile selection differs from --profiles")
    return profiles


def main() -> int:
    args = parse_args()
    try:
        profiles = synchronize(
            args.project_root, args.catalog_root, args.write, args.profiles
        )
    except (LinkError, CatalogError, OSError, tomllib.TOMLDecodeError) as error:
        print(f"agent link synchronization failed: {error}", file=sys.stderr)
        return 1
    action = "Synchronized" if args.write else "Validated"
    scope = "all profiles" if profiles is None else ", ".join(profiles)
    print(f"{action} Codex and Claude Code skill entrypoints ({scope}).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
