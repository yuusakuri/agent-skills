#!/usr/bin/env python3
"""Validate catalog.toml and local skill metadata."""

from __future__ import annotations

import argparse
from pathlib import Path
import sys
import tomllib

from catalog_manifest import CatalogError, load_catalog


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
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        catalog = load_catalog(
            args.catalog.resolve(),
            args.catalog_root.resolve(),
        )
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
