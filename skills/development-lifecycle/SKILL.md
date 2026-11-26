---
name: development-lifecycle
description: Routes software development work to its phase and the skill that owns it, scales the process to the size of the change, and sets the specification and test rules every phase follows. Use at the start of a feature, bug fix, refactor, migration, release, or incident, when unsure which phase or skill applies, or when several skills seem to apply at once.
---

# Development Lifecycle

This skill is a map, not a method. It decides which phase the work is in,
hands off to the skill that owns that phase, and states the rules that hold
in every phase. Do the phase's work through the named skill, not here.

## Read the project first

Before routing, look for the project's own instructions (`AGENTS.md`,
`CLAUDE.md`, or the agent's equivalent) and use what they declare:

- the test command, and any faster command for a single test;
- where specifications, plans, and decision records live;
- the definition of done, if the project has one.

The project's instructions override every default below. When no test
command is declared, find it in the build files and say which one you will
use before relying on it.

## Route the work

Ask two questions:

1. What artifact must this work produce: a decision, a specification, a
   plan, code, a fix, a review, a release, or a document?
2. What does done look like, and who confirms it?

Then pick the row. When the work spans several phases, run them in order;
skipping an earlier phase is the most common cause of rework.

| # | Phase | Situation | Skill |
|---|---|---|---|
| 0 | Orient | The request is underspecified, or the user asks to be questioned | `interview-me` |
| 1 | Specify | A new feature or behavior change needs an approved design | `brainstorming` |
| 1 | Specify | The design needs testable Given/When/Then criteria | `deliver-acceptance-criteria` |
| 1 | Specify | Boundaries, failure states, and recovery paths need cataloguing | `deliver-edge-cases` |
| 1 | Specify | Stakeholders need a product requirements document | `deliver-prd` |
| 1 | Specify | A formal requirements definition, specification, or design document is required | `document-architecture` |
| 2 | Design | An API, schema, event, or module boundary is being defined | `api-and-interface-design` |
| 2 | Design | A costly-to-reverse decision needs its rationale recorded | `documentation-and-adrs` |
| 2 | Design | Authentication, secrets, personal data, payments, or untrusted input is involved | `security-and-hardening` |
| 2 | Design | A user interface is being designed or redesigned | `ui-ux-pro-max`, `frontend-ui-engineering` |
| 2 | Design | A one-page overview is needed to align people on the approach | `develop-solution-brief` |
| 3 | Plan | An approved design exists and needs an executable plan | `writing-plans` |
| 3 | Plan | The work needs an isolated branch or worktree | `using-git-worktrees` |
| 4 | Build | Any production code is about to be written or changed | `test-driven-development` |
| 4 | Build | A written plan is executed task by task with subagents | `subagent-driven-development` |
| 4 | Build | A written plan is executed inline in this session | `executing-plans` |
| 4 | Build | Two or more independent tasks share no state | `dispatching-parallel-agents` |
| 4 | Build | An unfamiliar library or API is used | `source-driven-development` |
| 4 | Build | Browser-facing HTML, CSS, or client JavaScript is written | `modern-web-guidance` |
| 4 | Build | Code is restructured without changing behavior | `code-simplification` |
| 5 | Fix | A bug, test failure, or unexplained behavior appears | `systematic-debugging` |
| 5 | Fix | Something is slow or uses too many resources | `performance-optimization` |
| 5 | Fix | CI is failing or a pipeline needs designing | `ci-cd-and-automation` |
| 6 | Verify | The work is about to be reported as done, fixed, or passing | `verification-before-completion` |
| 6 | Verify | A browser-facing change needs checking in a real browser | `browser-testing-with-devtools` |
| 6 | Verify | The implementation must be audited against its specification | `intended-vs-implemented` |
| 7 | Review | The work is ready for someone else to review | `requesting-code-review` |
| 7 | Review | A change needs reviewing, by you or a subagent | `code-review-and-quality` |
| 7 | Review | Review feedback has arrived | `receiving-code-review` |
| 8 | Ship | Tests pass and the branch must be integrated | `finishing-a-development-branch` |
| 8 | Ship | Commits, branches, versions, or a changelog need structuring | `git-workflow-and-versioning` |
| 8 | Ship | The change must be observable in production | `observability-and-instrumentation` |
| 8 | Ship | A production launch needs a readiness check and rollout plan | `shipping-and-launch` |
| 8 | Ship | An API, feature, or system is being retired | `deprecation-and-migration` |
| — | Meta | Output quality is degrading or the task is switching | `context-engineering` |
| — | Meta | A skill is being written or changed | `writing-skills` |

When no row fits, say which phase the work is in, do not guess a skill, and
follow the rules below.

## Specifications and tests

The specification says what the system must do. The tests are its
executable form. These rules hold in every phase.

1. **Write the expected behavior down before the code.** A standard or
   larger change needs an approved design from `brainstorming`. A small
   change needs at least one sentence stating the expected behavior, agreed
   with the requester.
2. **Make acceptance criteria testable.** Each criterion names an
   observable result. Use `deliver-acceptance-criteria` for Given/When/Then
   form and `deliver-edge-cases` for boundaries and failure states.
3. **Trace every criterion to a test.** The plan names the test that proves
   each criterion. A criterion without a test is not done; a test without a
   criterion is either a missing criterion or a test to question.
4. **Fail first.** Follow `test-driven-development`: write the test, watch
   it fail for the expected reason, then write the code.
5. **Never make red green by weakening the test.** Do not delete, skip,
   mark as expected-to-fail, loosen assertions or tolerances, or
   regenerate snapshots to get a passing run. If the specification was
   wrong, change the specification with the requester first, then the
   test, then the code, in that order.
6. **Flaky means nondeterministic.** Find the cause — timing, shared state,
   test order, unseeded randomness, unordered comparisons, environment
   differences. Do not retry until green. For timing, use the
   condition-based waiting guidance in `systematic-debugging`.
7. **Pin legacy behavior before changing it.** When code without tests is
   about to be restructured, first write characterization tests that
   capture what it does today, bugs included.
8. **Show evidence before claims.** Follow `verification-before-completion`:
   run the relevant suite, read the output, and report the command and its
   result. "Tests pass" means you ran them in this session.

## Using Spec Kit

When the repository contains a `.specify/` directory, GitHub Spec Kit owns
the specification, plan, and task artifacts. Use its commands (constitution,
specify, clarify, plan, tasks, analyze, implement) for phases 1 and 3
instead of `brainstorming` and `writing-plans`, and never create a second
document that owns the same requirement.

Everything else still applies: during Spec Kit's implement step, build
with `test-driven-development`, fix with `systematic-debugging`, and finish
with `verification-before-completion` and `requesting-code-review`. Put the
rules in "Specifications and tests" into the Spec Kit constitution so its
own steps enforce them.

## Scale the process to the change

| Size | Examples | Phases |
|---|---|---|
| Trivial | Typo, comment, obvious one-line fix | 4, 6 — no design, no plan |
| Small | Contained, follows an existing pattern, cheap to revert | 1 (one sentence), 4, 6, 7 |
| Standard | New feature or endpoint | 0 when unclear, 1, 2 as needed, 3, 4, 6, 7, 8 |
| High impact | Data model, authentication, money, migrations, public API | Every phase; `security-and-hardening` and `documentation-and-adrs` are required |

When the size is unclear, treat it as the larger one and say so.

## Rules for every phase

1. **Reversibility sets rigor.** Cheap to undo: proceed. Costly or one-way:
   record the decision first with `documentation-and-adrs`.
2. **The requester owns scope.** Point out gaps and risks, but do not
   silently widen or narrow what was asked.
3. **Keep records in the repository.** Specifications, plans, and
   decisions belong in files, not only in the conversation.
4. **Failed checks go back, not forward.** A failing verification returns
   the work to phase 4 or 5; it never moves on to review or release.

## Resolve overlaps

| Need | Use | Not |
|---|---|---|
| Find out what the requester actually wants | `interview-me` when they ask to be questioned or the ask is very vague; otherwise `brainstorming` | Both in a row on the same question |
| Record a technical design | The design document from `brainstorming` | A separate specification that restates it |
| Record why a costly decision was made | `documentation-and-adrs` | The design document alone |
| Get a review | `requesting-code-review` dispatches it; `code-review-and-quality` is the standard the reviewer applies | Self-approval without a fresh reviewer |
| Integrate a branch | `finishing-a-development-branch` | `shipping-and-launch`, which is for production launches |
