"""Exercise translated snapshots against a local pinned Git source."""

from dataclasses import replace
import difflib
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

REPOSITORY = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPOSITORY / "scripts"))
from catalog_manifest import CatalogError, load_catalog
from update_catalog import checkout_source


class SourcePatchTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.catalog = self.root / "catalog"
        self.catalog.mkdir()
        upstream = self.root / "upstream"
        skill = upstream / "skills" / "writer"
        skill.mkdir(parents=True)
        self.original = "---\nname: writer\ndescription: Write clearly.\n---\n# Writing\n"
        self.translated = "---\nname: writer\ndescription: 明確に書く。\n---\n# 執筆\n"
        (skill / "SKILL.md").write_text(self.original)
        (upstream / "LICENSE").write_text("Test license\n")
        self.git(upstream, "init", "-q")
        self.git(upstream, "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
                 "add", ".")
        self.git(upstream, "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
                 "commit", "-qm", "Source")
        self.revision = self.git(upstream, "rev-parse", "HEAD").strip()
        self.remotes = self.root / "remotes"
        remote = self.remotes / "example" / "source.git"
        remote.parent.mkdir(parents=True)
        subprocess.run(["git", "clone", "-q", "--bare", str(upstream), str(remote)], check=True)
        self.manifest = f'''version = 1
[[sources]]
id = "example-source"
kind = "vendored"
repository = "example/source"
revision = "{self.revision}"
license = "Test"
license_file = "LICENSE"
patch_file = "translations/writer.patch"
adaptation = "日本語訳"
activation = "auto"
skills = [{{name = "writer", path = "skills/writer", capability = "writer"}}]
'''
        self.manifest_path = self.catalog / "catalog.toml"
        self.manifest_path.write_text(self.manifest)
        self.patch_path = self.catalog / "translations" / "writer.patch"
        self.patch_path.parent.mkdir()
        self.patch_path.write_text("".join(difflib.unified_diff(
            self.original.splitlines(keepends=True), self.translated.splitlines(keepends=True),
            fromfile="a/skills/writer/SKILL.md", tofile="b/skills/writer/SKILL.md",
        )))

    def git(self, root, *args):
        return subprocess.check_output(["git", "-C", str(root), *args], text=True)

    def update(self, *args):
        return subprocess.run(
            [sys.executable, str(REPOSITORY / "scripts/update_catalog.py"),
             "--catalog", str(self.manifest_path), "--catalog-root", str(self.catalog),
             "--target", str(self.catalog / "skills"), *args],
            env={**os.environ, "AGENT_SKILLS_GITHUB_BASE_URL": self.remotes.as_uri()},
            text=True, capture_output=True,
        )

    def require_success(self, result):
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_translation_survives_regeneration_and_check_detects_drift(self):
        self.require_success(self.update())
        generated = self.catalog / "skills/writer/SKILL.md"
        self.assertEqual(generated.read_text(), self.translated)
        notice = (self.catalog / "THIRD_PARTY_NOTICES.md").read_text()
        self.assertIn(self.revision, notice)
        self.assertIn("日本語訳", notice)
        self.assertIn("Test license", notice)
        self.require_success(self.update())
        self.assertEqual(generated.read_text(), self.translated)
        self.require_success(self.update("--check"))
        generated.write_text(self.original)
        self.assertNotEqual(self.update("--check").returncode, 0)

    def test_patch_mismatch_preserves_previous_skills_and_notice(self):
        self.require_success(self.update())
        generated = self.catalog / "skills/writer/SKILL.md"
        notice = self.catalog / "THIRD_PARTY_NOTICES.md"
        before = (generated.read_bytes(), notice.read_bytes())
        self.patch_path.write_text(self.patch_path.read_text().replace(
            "-description: Write clearly.", "-description: Missing upstream sentence."))
        self.assertNotEqual(self.update().returncode, 0)
        self.assertEqual(before, (generated.read_bytes(), notice.read_bytes()))

    def test_patch_cannot_escape_catalog_through_symlink(self):
        outside = self.root / "outside.patch"
        outside.write_bytes(self.patch_path.read_bytes())
        self.patch_path.unlink()
        self.patch_path.symlink_to(outside)
        result = self.update()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("escapes", result.stderr)
        self.assertFalse((self.catalog / "skills").exists())

    def test_gist_checkout_uses_pinned_revision_and_gist_host(self):
        source = load_catalog(self.manifest_path, self.catalog).sources[0]
        source = replace(source, host="gist.github.com", repository="writer/0123456789abcdef")
        with patch("update_catalog.run_git", return_value=self.revision) as git:
            checkout_source(source, self.root / "gist", "https://github.com")
        calls = [call.args for call in git.call_args_list]
        self.assertIn(("remote", "add", "origin",
                       "https://gist.github.com/writer/0123456789abcdef.git"), calls)
        self.assertIn(("fetch", "--depth=1", "origin", self.revision), calls)

    def test_manifest_requires_attribution_and_safe_patch_path(self):
        variants = [
            self.manifest.replace('adaptation = "日本語訳"\n', ""),
            self.manifest.replace('translations/writer.patch', '../writer.patch'),
            self.manifest + 'host = "unrecognized.example"\n',
        ]
        for contents in variants:
            with self.subTest(contents=contents):
                self.manifest_path.write_text(contents)
                with self.assertRaises(CatalogError):
                    load_catalog(self.manifest_path, self.catalog)


if __name__ == "__main__":
    unittest.main()
