#!/usr/bin/env python3
"""Synchronize Codex and Claude Code links to one canonical skill catalog."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import sys


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


def synchronize(project_root: Path, catalog_root: Path, write: bool) -> None:
    project_root = project_root.resolve()
    catalog_root = catalog_root.resolve()
    skills_root = catalog_root / "skills"
    if not skills_root.is_dir():
        raise LinkError(f"catalog skills directory is missing: {skills_root}")

    skill_names = sorted(
        path.name
        for path in skills_root.iterdir()
        if path.is_dir() and (path / "SKILL.md").is_file()
    )
    if not skill_names:
        raise LinkError(f"catalog has no Skill directories: {skills_root}")

    ensure_link(project_root / ".agents" / "skills", skills_root, write)

    claude_root = project_root / ".claude" / "skills"
    if claude_root.is_symlink() or (claude_root.exists() and not claude_root.is_dir()):
        raise LinkError(f"Claude Code entrypoint must be a directory: {claude_root}")
    if write:
        claude_root.mkdir(parents=True, exist_ok=True)
    elif not claude_root.is_dir():
        raise LinkError(f"Claude Code entrypoint is missing: {claude_root}")

    expected = set(skill_names)
    for skill_name in skill_names:
        ensure_link(
            claude_root / skill_name,
            skills_root / skill_name,
            write,
        )

    for existing in claude_root.iterdir():
        if existing.name in expected or not is_catalog_link(existing, skills_root):
            continue
        if not write:
            raise LinkError(f"stale catalog link: {existing}")
        existing.unlink()


def main() -> int:
    args = parse_args()
    try:
        synchronize(args.project_root, args.catalog_root, args.write)
    except (LinkError, OSError) as error:
        print(f"agent link synchronization failed: {error}", file=sys.stderr)
        return 1
    action = "Synchronized" if args.write else "Validated"
    print(f"{action} Codex and Claude Code skill entrypoints.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
