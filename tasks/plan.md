# Implementation Plan: Self-Contained Agent Skills Catalog

## Overview

Convert the catalog from a consumer-installed dependency list into a runtime-ready, project-neutral snapshot. Licensed external Skills will be vendored, `ui-ux-pro-max` will remain a pinned nested submodule because its source does not declare a redistribution license, and every consumer project will expose the catalog through a tracked `.agents/skills` symlink.

## Architecture decisions

- Keep `skills.lock.tsv` as the provenance and duplicate-prevention source of truth.
- Add a non-vendored delivery kind for the unlicensed `ninehills/skills` source.
- Store one canonical runtime view under `skills/`.
- Use relative symlinks so the catalog works at any clone path.
- Make the updater a maintainer tool; consumers only initialize submodules.
- Make GitHub-Flavored Markdown the default `document-architecture` output.
- Release the breaking consumer-contract change as `v2.0.0`.

## Dependency graph

```text
Catalog contract tests
    │
    ├── Lock and validator delivery model
    │       │
    │       ├── Nested upstream submodule
    │       └── Maintainer update command
    │               │
    │               ├── Vendored Skill snapshot
    │               └── Third-party license snapshot
    │
    ├── Generic Markdown-first documentation
    │
    └── CI snapshot verification
            │
            ├── Catalog PR and v2.0.0 release
            └── Consumer-project migration and merge
```

## Tasks

### Task 1: Define the self-contained catalog contract

**Description:** Add failing tests that describe the runtime-ready catalog, repository-local symlink, nested-submodule delivery, licensing, and project-neutral documentation.

**Acceptance criteria:**

- Tests require exactly 97 accessible `SKILL.md` files from `skills/`.
- Tests require `.agents/skills -> ../skills`.
- Tests require five vendored source-license records and one pinned nested source.
- Tests reject OpenChoice-specific wording outside historical design documents.

**Verification:**

- The new tests fail against the current thin catalog.
- Existing validator tests continue to pass before implementation changes.

**Dependencies:** None

**Files likely touched:**

- `tests/catalog_test.sh`
- `tests/consumer_test.sh`

**Estimated scope:** Small

### Task 2: Implement vendored and nested delivery

**Description:** Extend the lock validator for the nested delivery kind, rename the installer as a maintainer updater, add check mode, and add the pinned `ninehills/skills` nested submodule.

**Acceptance criteria:**

- `ui-ux-pro-max` is declared as non-vendored and resolves through the nested submodule.
- Each vendored upstream repository is fetched once.
- Update failure preserves the existing canonical snapshot.
- `--check` detects a snapshot that differs from pinned sources.

**Verification:**

- `bash -n scripts/*.sh tests/*.sh`
- `./tests/validate_test.sh`
- `./tests/update_vendored_skills_test.sh`

**Dependencies:** Task 1

**Files likely touched:**

- `skills.lock.tsv`
- `scripts/validate.sh`
- `scripts/update-vendored-skills.sh`
- `tests/validate_test.sh`
- `tests/update_vendored_skills_test.sh`
- `.gitmodules`
- `vendor/ninehills--skills`

**Estimated scope:** Medium

### Task 3: Generate the canonical Skill and license snapshots

**Description:** Run the maintainer updater to populate licensed external Skills, retain the local Skill, link the nested Skill, and store pinned upstream license records.

**Acceptance criteria:**

- `skills/` exposes exactly 97 unique Skills.
- Five rejected duplicate candidates remain absent.
- Five licensed upstream repositories have preserved license text and source metadata.
- The generated snapshot matches pinned sources byte-for-byte.

**Verification:**

- `./scripts/update-vendored-skills.sh --check`
- `./tests/catalog_test.sh`
- Review the generated diff and license map.

**Dependencies:** Task 2

**Files likely touched:**

- `skills/`
- `third-party-licenses/`

**Estimated scope:** Medium, with a large mechanical generated diff

### Checkpoint: Runtime-ready catalog

- All shell tests pass.
- A fresh recursive clone exposes 97 Skills.
- No consumer installation command is required.

### Task 4: Make documentation generic and Markdown-first

**Description:** Rewrite repository guidance and `document-architecture` metadata so the catalog applies to any development project and GitHub Markdown is the normal output.

**Acceptance criteria:**

- README contains generic submodule and recursive-clone instructions.
- Shared operational documentation contains no OpenChoice-specific examples.
- `document-architecture` explicitly defaults to GitHub-Flavored Markdown.
- Word output remains available only when explicitly requested.

**Verification:**

- Project-neutral wording test passes.
- Skill Creator validation passes for `document-architecture`.
- `rg -ni 'open.?choice' README.md skills scripts tests .github` returns no matches.

**Dependencies:** Task 1

**Files likely touched:**

- `README.md`
- `skills/document-architecture/SKILL.md`
- `skills/document-architecture/agents/openai.yaml`
- `tests/catalog_test.sh`

**Estimated scope:** Small

### Task 5: Enforce the snapshot in CI

**Description:** Update GitHub Actions to initialize nested submodules and verify the committed runtime snapshot rather than installing Skills into a consumer target.

**Acceptance criteria:**

- CI checks out nested submodules recursively.
- CI runs syntax, validator, updater, catalog, symlink, license, and snapshot checks.
- CI completes without warnings or skipped checks.

**Verification:**

- Workflow YAML parses locally.
- A pushed branch run succeeds on GitHub Actions.

**Dependencies:** Tasks 2, 3, and 4

**Files likely touched:**

- `.github/workflows/ci.yml`
- `tests/consumer_test.sh`

**Estimated scope:** Small

### Checkpoint: Shared catalog complete

- Local tests and snapshot verification pass.
- GitHub Actions passes.
- The branch diff contains only intended catalog changes.

### Task 6: Merge and release the shared catalog

**Description:** Push the implementation branch, open a pull request, review the complete diff and CI result, merge to `main`, and publish `v2.0.0`.

**Acceptance criteria:**

- The pull request is merged into `main`.
- The merge commit passes CI.
- `v2.0.0` points to the merged self-contained catalog.

**Verification:**

- GitHub reports the PR as merged.
- The release is public and not marked draft or prerelease.

**Dependencies:** Task 5

**Files likely touched:** None

**Estimated scope:** Small

### Task 7: Migrate OpenChoice as an independent consumer

**Description:** In a clean OpenChoice worktree, update the catalog gitlink to `v2.0.0`, replace generated Skills with a tracked relative symlink, remove the consumer installer, and update the local ADR.

**Acceptance criteria:**

- `.agents/skills -> catalog/skills` is tracked.
- No Skill installation wrapper or generated-directory ignore rule remains.
- A recursive submodule update exposes all 97 Skills.
- OpenChoice-specific information remains only in OpenChoice.

**Verification:**

- Validate symlink resolution and count 97 `SKILL.md` files.
- Review and merge a focused OpenChoice pull request.

**Dependencies:** Task 6

**Files likely touched:**

- `.agents/catalog`
- `.agents/skills`
- `.gitignore`
- `tools/install-external-skills.sh`
- `docs/adr/002-use-shared-agent-skills-catalog.md`

**Estimated scope:** Medium due to tracked generated-file removal

## Risks and mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Unlicensed upstream content is redistributed | High | Keep `ninehills/skills` as a nested submodule and do not copy its content |
| Vendored content drifts from pinned sources | High | Add deterministic `--check` mode and run it in CI |
| Symlinks fail on unsupported clients | Medium | Document Git symlink support and verify on Linux CI and macOS locally |
| Nested submodule is not initialized | Medium | Require recursive clone/update in README and CI |
| Large generated diff hides unintended changes | Medium | Commit updater logic before generated content and review source groups/licenses separately |
| Existing OpenChoice worktree contains unrelated edits | High | Perform migration in a clean worktree and stage only migration paths |

## Open questions

None. The approved design and legal delivery exception determine the implementation.
