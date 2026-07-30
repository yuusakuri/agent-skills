#!/usr/bin/env python3
"""Build the checked-in skill snapshot from catalog.toml."""

from __future__ import annotations

import argparse
from contextlib import suppress
import hashlib
import os
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import sys
import tempfile
import tomllib

from catalog_manifest import (
    CatalogError,
    Source,
    declared_skill_name,
    load_catalog,
)


NOTICE_NAME = "THIRD_PARTY_NOTICES.md"


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
        "--target",
        type=Path,
        default=repository_root / "skills",
        help="directory to replace with the generated skill snapshot",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="fail if the checked-in snapshot differs from generated output",
    )
    return parser.parse_args()


def run_git(*args: str, cwd: Path) -> str:
    completed = subprocess.run(
        ["git", "-C", str(cwd), *args],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    return completed.stdout.strip()


def assert_safe_target(target: Path, catalog_root: Path) -> None:
    if target.is_symlink():
        raise CatalogError(f"target must not be a symlink: {target}")
    if target.exists() and not target.is_dir():
        raise CatalogError(f"target must be a directory: {target}")
    resolved = target.resolve()
    if resolved in {Path("/"), Path.home().resolve(), catalog_root.resolve()}:
        raise CatalogError(f"refusing unsafe target: {target}")
    if len(resolved.parts) < 3:
        raise CatalogError(f"refusing broad target: {target}")


def assert_contained(path: Path, root: Path, context: str) -> Path:
    resolved = path.resolve(strict=True)
    try:
        resolved.relative_to(root.resolve(strict=True))
    except ValueError as error:
        raise CatalogError(f"{context} escapes its source checkout: {path}") from error
    return resolved


def assert_tree_symlinks_contained(tree: Path, root: Path, context: str) -> None:
    for path in tree.rglob("*"):
        if path.is_symlink():
            assert_contained(path, root, context)


def verify_skill(skill_dir: Path, expected_name: str) -> None:
    skill_file = skill_dir / "SKILL.md"
    if not skill_file.is_file():
        raise CatalogError(f"skill is missing SKILL.md: {expected_name}")
    actual_name = declared_skill_name(skill_file)
    if actual_name != expected_name:
        raise CatalogError(
            f"SKILL.md name does not match {expected_name}: "
            f"{actual_name or '<missing>'}"
        )


def checkout_source(source: Source, checkout: Path, base_url: str) -> None:
    checkout.mkdir(parents=True)
    run_git("init", "-q", cwd=checkout)
    repository_url = f"{base_url.rstrip('/')}/{source.repository}.git"
    run_git("remote", "add", "origin", repository_url, cwd=checkout)
    run_git("sparse-checkout", "init", "--cone", cwd=checkout)

    sparse_directories = {str(skill.path) for skill in source.skills}
    for metadata_file in (source.license_file, source.notice_file):
        if metadata_file is not None and len(metadata_file.parts) > 1:
            sparse_directories.add(str(metadata_file.parent))
    run_git(
        "sparse-checkout",
        "set",
        "--",
        *sorted(sparse_directories),
        cwd=checkout,
    )
    assert source.revision is not None
    run_git("fetch", "--depth=1", "origin", source.revision, cwd=checkout)
    run_git("checkout", "--detach", "FETCH_HEAD", cwd=checkout)
    actual_revision = run_git("rev-parse", "HEAD", cwd=checkout)
    if actual_revision != source.revision:
        raise CatalogError(
            f"source revision mismatch for {source.repository}: "
            f"{actual_revision} != {source.revision}"
        )


def copy_source_skills(
    source: Source,
    source_root: Path,
    staged_skills: Path,
) -> None:
    for skill in source.skills:
        source_skill = source_root.joinpath(*skill.path.parts)
        assert_contained(source_skill, source_root, f"skill {skill.name}")
        assert_tree_symlinks_contained(
            source_skill,
            source_root,
            f"skill {skill.name}",
        )
        verify_skill(source_skill, skill.name)
        destination = staged_skills / skill.name
        if destination.exists():
            raise CatalogError(f"duplicate staged skill: {skill.name}")
        shutil.copytree(source_skill, destination, symlinks=True)


def metadata_text(
    source: Source,
    source_root: Path,
    metadata_path: PurePosixPath,
) -> str:
    path = source_root.joinpath(*metadata_path.parts)
    assert_contained(path, source_root, f"metadata for {source.id}")
    if not path.is_file():
        raise CatalogError(
            f"source metadata file is missing for {source.id}: {metadata_path}"
        )
    return path.read_text(encoding="utf-8").rstrip()


def notice_section(source: Source, source_root: Path) -> str:
    assert source.revision is not None
    assert source.license_file is not None
    lines = [
        f"## {source.repository}",
        "",
        f"- Repository: https://github.com/{source.repository}",
        f"- Revision: `{source.revision}`",
        f"- License: `{source.license}`",
        f"- Upstream license file: `{source.license_file}`",
        "",
        "### License text",
        "",
        "```text",
        metadata_text(source, source_root, source.license_file),
        "```",
    ]
    if source.notice_file is not None:
        lines.extend(
            [
                "",
                f"### Upstream notice (`{source.notice_file}`)",
                "",
                "```text",
                metadata_text(source, source_root, source.notice_file),
                "```",
            ]
        )
    return "\n".join(lines)


def tree_entries(root: Path) -> dict[str, tuple[str, str, bool]]:
    entries: dict[str, tuple[str, str, bool]] = {}
    if not root.is_dir():
        return entries
    for path in sorted(root.rglob("*")):
        relative = path.relative_to(root)
        if "__pycache__" in relative.parts or path.suffix in {".pyc", ".pyo"}:
            continue
        relative_path = relative.as_posix()
        if path.is_symlink():
            entries[relative_path] = ("symlink", os.readlink(path), False)
        elif path.is_file():
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            executable = bool(path.stat().st_mode & 0o111)
            entries[relative_path] = ("file", digest, executable)
    return entries


def same_tree(left: Path, right: Path) -> bool:
    return left.is_dir() and right.is_dir() and tree_entries(left) == tree_entries(
        right
    )


def replace_snapshot(
    staged_skills: Path,
    staged_notice: Path,
    target: Path,
    notice: Path,
    temporary_root: Path,
) -> None:
    target_backup = temporary_root / "previous-skills"
    notice_backup = temporary_root / "previous-notice"
    target_existed = target.exists()
    notice_existed = notice.exists()
    try:
        if target_existed:
            os.replace(target, target_backup)
        os.replace(staged_skills, target)
        if notice_existed:
            os.replace(notice, notice_backup)
        os.replace(staged_notice, notice)
    except Exception:
        with suppress(FileNotFoundError):
            if target.exists():
                shutil.rmtree(target)
        if target_existed and target_backup.exists():
            os.replace(target_backup, target)
        with suppress(FileNotFoundError):
            notice.unlink()
        if notice_existed and notice_backup.exists():
            os.replace(notice_backup, notice)
        raise


def update() -> int:
    args = parse_args()
    catalog_root = args.catalog_root.resolve()
    target = args.target.resolve()
    catalog_path = args.catalog.resolve()
    notice = catalog_root / NOTICE_NAME
    assert_safe_target(target, catalog_root)
    catalog = load_catalog(catalog_path, catalog_root)
    target.parent.mkdir(parents=True, exist_ok=True)
    base_url = os.environ.get(
        "AGENT_SKILLS_GITHUB_BASE_URL",
        "https://github.com",
    )

    with tempfile.TemporaryDirectory(
        prefix=".agent-skills-update.",
        dir=target.parent,
    ) as temporary_directory:
        temporary_root = Path(temporary_directory)
        staged_skills = temporary_root / "skills"
        staged_skills.mkdir()
        notice_sections: list[str] = []

        for source in catalog.sources:
            if source.kind == "local":
                copy_source_skills(source, catalog_root, staged_skills)
                continue
            checkout = temporary_root / "sources" / source.id
            checkout_source(source, checkout, base_url)
            copy_source_skills(source, checkout, staged_skills)
            notice_sections.append(notice_section(source, checkout))

        staged_names = {path.name for path in staged_skills.iterdir()}
        expected_names = {skill.name for skill in catalog.skills}
        if staged_names != expected_names:
            missing = sorted(expected_names - staged_names)
            extra = sorted(staged_names - expected_names)
            raise CatalogError(
                f"staged catalog differs from manifest; missing={missing}, extra={extra}"
            )

        staged_notice = temporary_root / NOTICE_NAME
        staged_notice.write_text(
            "# Third-Party Notices\n\n"
            "This file records the pinned upstream sources and license texts for "
            "the vendored Skills in this repository. License text is included "
            "once per upstream source.\n\n"
            + "\n\n".join(notice_sections)
            + "\n",
            encoding="utf-8",
        )

        if args.check:
            skills_match = same_tree(staged_skills, target)
            notice_match = (
                notice.is_file()
                and notice.read_bytes() == staged_notice.read_bytes()
            )
            if not skills_match or not notice_match:
                raise CatalogError(
                    "checked-in snapshot differs from catalog.toml; "
                    "run scripts/update_catalog.py"
                )
            print(
                f"Catalog snapshot is current: {len(catalog.skills)} skills "
                f"from {len(catalog.sources)} sources."
            )
            return 0

        replace_snapshot(
            staged_skills,
            staged_notice,
            target,
            notice,
            temporary_root,
        )
        print(
            f"Updated {target} with {len(catalog.skills)} skills and wrote "
            f"{notice}."
        )
    return 0


def main() -> int:
    try:
        return update()
    except (
        CatalogError,
        OSError,
        subprocess.CalledProcessError,
        tomllib.TOMLDecodeError,
    ) as error:
        print(f"catalog update failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
