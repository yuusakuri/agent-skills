---
name: document-architecture
description: Coauthor, restructure, and quality-review formal system documents with a single canonical outline and traceable decisions. Use when creating or revising a requirements definition, technical specification, basic design, detailed design, system proposal, or business proposal, including Markdown or Word deliverables. Route PRDs, ADRs, unresolved technical choices, and implementation plans to their existing specialist skills instead of creating competing artifacts.
---

# Document Architecture

Create decision-ready system documents without duplicating the responsibility of PRDs, ADRs, technical exploration, or implementation plans.

## Route the request

Select exactly one primary document type, then read its reference completely.

| Requested outcome | Read |
|---|---|
| Define business and system requirements, scope, and acceptance | `references/requirements-definition.md` |
| Record a selected technical approach for implementers | `references/technical-spec.md` |
| Define externally observable behavior and major internal boundaries | `references/basic-design.md` |
| Define implementation-level modules, processing, data updates, and unit tests | `references/detailed-design.md` |
| Propose a system investment, delivery, cost, and benefit to a customer | `references/system-proposal.md` |
| Propose business improvement or a new operating initiative | `references/business-proposal.md` |

Always read `references/quality-checklist.md` before finalizing the document. Do not read unrelated document references.

## Preserve artifact ownership

- Use `deliver-prd` for a product requirements document covering the customer problem, value, product scope, and outcomes.
- Use `brainstorming` when a technical approach is unresolved. Compare options first, then record the selected approach in the technical document.
- Use `spec-driven-development` for a coding implementation specification.
- Use `planning-and-task-breakdown` for file-level implementation tasks and verification steps.
- Use `documentation-and-adrs` for an architecture decision record explaining a costly-to-reverse decision.
- Use `develop-solution-brief` for a short internal alignment document.
- Use this skill for formal requirements, specifications, designs, and proposals after identifying their inputs and decision audience.

Update or reference an existing canonical artifact. Never create a second document that owns the same decision or requirement.

## Follow the coauthoring workflow

1. Identify the primary reader, purpose, expected decision, use date, and delivery format.
2. Identify existing source artifacts and the owner of each fact or decision.
3. Select one primary document type. If several documents are needed, order them by dependency and create or update them one at a time.
4. Read the selected document reference and propose its outline. Preserve an existing approved outline unless changing it resolves a concrete gap.
5. Classify input as `Fact`, `Decision`, `Assumption`, or `Open question`. Cite the source of facts and name the owner and review date of assumptions.
6. Draft each section for its decision purpose. Prefer measurable statements, explicit scope boundaries, and testable conditions.
7. Add traceability identifiers where downstream verification matters.
8. Read `references/quality-checklist.md`, fix failures, and verify the document from the reader's perspective.

Ask only for information that changes the structure, scope, or decision. When information is unavailable, mark the specific assumption and its consequence instead of inventing data.

## Maintain traceability

Use stable identifiers when the document feeds another lifecycle artifact.

| Item | Prefix example | Trace to |
|---|---|---|
| Business requirement | `BR-001` | Goal, stakeholder, process |
| Functional requirement | `FR-001` | Business requirement, acceptance condition |
| Non-functional requirement | `NFR-001` | Quality target, measurement method |
| Interface requirement | `IF-001` | Producer, consumer, contract |
| Design element | `DES-001` | Requirement and verification |
| Risk | `RSK-001` | Mitigation, owner, trigger |

Do not assign identifiers to narrative that will never be referenced. Keep identifiers stable when wording changes.

## Create Word deliverables

When the requested deliverable is Word:

1. Use `assets/templates/base-document.docx` as the common style source.
2. Generate the document chapters from the selected reference; do not copy a chapter list from the template.
3. Use the document creation skill to apply styles, render the DOCX to PNG, inspect every page, and iterate until clean.
4. Deliver the final document only after the latest render passes.

The template owns presentation. The selected reference owns document structure. The current artifact owns project-specific content.

## Finalize the result

Return:

- the completed or updated canonical document;
- the decision it supports;
- assumptions and open questions that materially affect approval or execution;
- the next owned artifact, if one is required.

Do not append a redundant summary document when the requested document already contains an executive summary or decision section.
