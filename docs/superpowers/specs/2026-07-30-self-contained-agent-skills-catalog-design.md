# Self-Contained Agent Skills Catalog Design

## Status

Approved in conversation on 2026-07-30.

## Context

The catalog currently stores one locally maintained Skill and a lock file that points to 96 external Skills. A consumer must run an installer after cloning before the complete Skill set exists on disk.

That model is reproducible, but it has three drawbacks for the intended use:

1. A clone does not visibly contain the adopted Skills.
2. Each consuming project needs an installation step.
3. Shared documentation mentions OpenChoice even though the catalog is intended for any development project.

Formal system documents are usually maintained as GitHub Markdown. Word is still needed occasionally, but it is not the default deliverable.

## Goals

- Make all 97 adopted Skills available from a recursive clone of the public catalog repository.
- Let each development project pin its own catalog version as a Git submodule.
- Make Skills available without a consumer-side installation command.
- Keep each project's catalog version independent from every other project.
- Make the shared repository product- and project-neutral.
- Use GitHub Markdown as the default formal-document format.
- Preserve Word generation as an explicitly requested option.
- Retain pinned upstream provenance, duplicate prevention, atomic maintainer updates, and CI verification.

## Non-goals

- Do not install Skills globally in a user's home directory.
- Do not share a mutable checkout between development projects.
- Do not update every consumer automatically when the catalog changes.
- Do not use Git subtree or copy the catalog history into consumers.
- Do not generate both Markdown and Word unless both are explicitly requested.

## Repository architecture

The shared repository will use this layout:

```text
agent-skills/
├── .agents/
│   └── skills -> ../skills
├── .github/
│   └── workflows/ci.yml
├── docs/
│   └── superpowers/specs/
├── scripts/
│   ├── update-vendored-skills.sh
│   └── validate.sh
├── skills/
│   ├── ab-test-analysis/
│   ├── ...
│   ├── document-architecture/
│   └── ui-ux-pro-max -> ../vendor/ninehills--skills/ui-ux-pro-max
├── tests/
├── third-party-licenses/
├── vendor/
│   └── ninehills--skills/    # nested upstream submodule
├── README.md
└── skills.lock.tsv
```

`skills/` is the runtime-ready, canonical view. It contains 95 licensed, pinned external Skills; the locally maintained `document-architecture` Skill; and a symlink to the pinned `ui-ux-pro-max` nested submodule.

The repository-local `.agents/skills` symlink makes the catalog usable when it is cloned and opened as its own Codex project. The symlink points at the same canonical `skills/` directory; it does not create another copy.

## Consumer architecture

Every consuming project owns an independent submodule reference:

```text
consumer-project/
└── .agents/
    ├── catalog/              # agent-skills Git submodule
    └── skills -> catalog/skills
```

Initial setup:

```bash
git submodule add https://github.com/yuusakuri/agent-skills.git .agents/catalog
ln -s catalog/skills .agents/skills
git add .gitmodules .agents/catalog .agents/skills
```

Clone:

```bash
git clone --recurse-submodules <consumer-project-url>
```

Existing clone:

```bash
git submodule update --init --recursive
```

No consumer-side Skill installer is required. The project records a catalog commit through the normal Git submodule gitlink. Advancing that gitlink is an explicit, reviewable update for that project only.

Plain `git clone` does not initialize submodules. This is an inherent Git behavior, so documentation must consistently use `--recurse-submodules` or the explicit update command.

## Catalog update flow

Only catalog maintainers run the update workflow.

1. Review a proposed upstream Skill and its license.
2. Update the selected source path or pinned commit in `skills.lock.tsv`.
3. Run `scripts/update-vendored-skills.sh`.
4. Fetch each unique vendored upstream repository and commit once.
5. Update any non-vendored nested submodule to its pinned commit.
6. Build the complete 97-Skill view in a staging directory.
7. Preserve vendored upstream license text in `third-party-licenses/`.
8. Validate declared Skill names, paths, counts, capabilities, the nested submodule, and the local Skill.
9. Replace `skills/` only after the complete staged view passes.
10. Run CI and review the vendored diff before release.

Consumers never run this flow. They only update their submodule reference after a catalog release has passed CI.

## Provenance and licensing

`skills.lock.tsv` remains the machine-readable adoption and provenance record. Every external Skill keeps:

- its canonical Skill name;
- upstream repository;
- repository-relative path;
- exact 40-character commit;
- canonical capability;
- activation policy.

Vendoring external content makes license retention mandatory. `third-party-licenses/` will contain one directory per vendored upstream repository, including its license text and pinned source metadata. CI will fail when a vendored upstream repository has no corresponding license record.

The pinned `ninehills/skills` source does not declare a repository-level or `ui-ux-pro-max` license. Its content will therefore not be copied into this repository. It will remain a nested Git submodule, and `skills/ui-ux-pro-max` will point to that checkout. This preserves upstream ownership while still making the Skill available after a recursive clone.

The repository's MIT license applies only to locally maintained files. Vendored Skills remain governed by their upstream licenses.

## Document Architecture behavior

`document-architecture` remains one shared workflow with six document-specific references:

- requirements definition;
- technical specification;
- basic design;
- detailed design;
- system proposal;
- business proposal.

GitHub-Flavored Markdown is the default output:

- use repository-relative links;
- use Markdown tables only when they improve comparison;
- use Mermaid when a relationship is materially clearer as a diagram;
- keep one canonical Markdown document rather than creating a redundant summary;
- optimize headings and anchors for GitHub review.

Word is produced only when explicitly requested or when a delivery requirement demands it. In that case, the existing Word template and render-based visual verification remain mandatory. Markdown is not converted to Word automatically, and a parallel Word copy is not maintained by default.

## Generic positioning

The shared repository must not describe itself as an OpenChoice component. Its README, Skill metadata, examples, tests, and maintenance instructions will refer to generic consumer projects.

OpenChoice remains one independent consumer. OpenChoice-specific migration instructions and architecture decisions stay in the OpenChoice repository.

## Migration

### Shared catalog

1. Generate and commit the licensed Skill snapshots and the nested-submodule Skill link under `skills/`.
2. Add the repository-local `.agents/skills` symlink.
3. Rename the installer to a maintainer-only update command.
4. Add third-party license snapshots and validation.
5. Update README and `document-architecture` for generic, Markdown-first use.
6. Update CI to verify the vendored snapshot against pinned sources.

### OpenChoice consumer

1. Update `.agents/catalog` to the released catalog commit.
2. Replace the ignored generated `.agents/skills/` directory with the tracked `skills -> catalog/skills` symlink.
3. Remove the consumer-side installation wrapper.
4. Remove the generated-directory ignore rule.
5. Update the OpenChoice ADR to describe direct submodule consumption.

## Failure handling

- An unavailable upstream commit fails the maintainer update before replacement.
- A missing or mismatched `SKILL.md` fails validation.
- A Skill path escaping its checkout fails validation.
- A missing upstream license blocks vendoring; an explicitly non-vendored source must be a pinned nested submodule.
- A vendored snapshot differing from pinned sources fails CI.
- A consumer with an uninitialized submodule receives an empty symlink target; project setup documentation directs them to initialize submodules.
- Existing consumer Skills are not deleted until the submodule and symlink targets have been verified.

## Verification

The completed change must prove:

- exactly 97 unique Skill names are available from the canonical `skills/` view;
- all five rejected duplicate candidates remain absent;
- every external Skill matches its pinned source;
- all five vendored upstream repositories are fetched at most once per update;
- all five vendored upstream license records exist;
- the non-vendored `ninehills/skills` gitlink matches its pinned commit;
- `.agents/skills` resolves to the canonical snapshot in both the catalog and a consumer fixture;
- a fresh recursive clone exposes the complete Skill set without installation;
- `document-architecture` defaults to Markdown and retains optional Word handling;
- the shared repository contains no OpenChoice-specific references outside historical design context;
- CI passes before the pull request is merged.

## Release and merge

The implementation will be developed on `codex/self-contained-agent-skills`, reviewed through a GitHub pull request, and merged into `main` only after CI succeeds. Because the consumer contract changes from installation to direct vendored access, `v2.0.0` will be created after merge. OpenChoice will then update its submodule to that release in a separate reviewable commit.
