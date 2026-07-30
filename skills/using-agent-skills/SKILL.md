---
name: using-agent-skills
description: Helps choose among the installed agent Skills without replacing their native description-based discovery. Use when the user explicitly asks which Skill to use, requests an overview of the catalog, or several Skill descriptions remain equally applicable. Do not invoke merely because a session started.
---

# Using Agent Skills

Choose the smallest set of installed Skills that owns the requested outcome.

## Use native discovery first

Codex and Claude Code discover each Skill from the `name` and `description` in
that Skill's `SKILL.md`. This Skill is optional guidance, not a required root
manifest and not a dispatcher that must run before other Skills.

1. Read the available Skill names and descriptions supplied by the agent.
2. Match the user's requested outcome and current lifecycle stage.
3. Prefer the Skill that produces the exact requested artifact.
4. Use multiple Skills only when their outputs are sequential dependencies.
5. Never invent or invoke a Skill name that is not installed.

## Resolve common overlaps

| Need | Primary Skill | Boundary |
|---|---|---|
| Clarify an ambiguous request | `interview-me` | Use `brainstorming` after the problem is understood and options are needed. |
| Explore solution options | `brainstorming` | Use `spec-driven-development` once the implementation behavior is ready to define. |
| Define implementation behavior | `spec-driven-development` | Use `planning-and-task-breakdown` only after the specification is stable. |
| Break implementation into steps | `planning-and-task-breakdown` | It does not own product requirements or formal system documents. |
| Create a product requirements document | `deliver-prd` | Use `document-architecture` for formal requirements, specifications, designs, and proposals. |
| Create a formal system document | `document-architecture` | It routes to one document type and keeps Markdown canonical unless Word is requested. |
| Record an architecture decision | `documentation-and-adrs` | An ADR records why a decision was made; a technical specification records the selected design. |
| Implement a change | `incremental-implementation` | Combine with `test-driven-development` when behavior changes. |
| Review before merge | `code-review-and-quality` | Add security or performance review only when those risks are present. |
| Prepare a release | `shipping-and-launch` | Use `release-notes` only for the user-facing change summary. |

When a more specific installed Skill matches the requested named artifact or
framework, prefer it over a broad workflow Skill.

## Sequence dependent Skills

A typical implementation can use:

`spec-driven-development` → `planning-and-task-breakdown` →
`incremental-implementation` + `test-driven-development` →
`code-review-and-quality` → `shipping-and-launch`

This is an example, not a mandatory pipeline. Skip any stage whose owned
artifact or verification is already complete.

## Report the choice

When the user asks which Skill applies, return:

- the selected Skill or ordered set;
- the outcome each one owns;
- why nearby Skills were not selected;
- any required input that is still missing.
