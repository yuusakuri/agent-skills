# Document Quality Checklist

Read this checklist after the selected document-type reference. Fix failures before presenting the document as complete.

## Canonical ownership

- [ ] The document has one stated purpose, primary reader, owner, and expected decision.
- [ ] An existing canonical artifact was updated or referenced instead of duplicated.
- [ ] PRD, ADR, technical exploration, implementation specification, and implementation plan content remains with its specialist owner.
- [ ] Repeated definitions, requirements, decisions, and chapter content have one authoritative location.

## Scope and structure

- [ ] In-scope and out-of-scope items are explicit.
- [ ] Each chapter contributes to the expected decision or downstream action.
- [ ] Optional chapters were omitted or combined intentionally, with no loss of acceptance or traceability information.
- [ ] Detailed material that interrupts the decision flow is moved to an appendix or linked artifact.

## Evidence and uncertainty

- [ ] Material facts cite a source and, where relevant, an observation date.
- [ ] Estimates state their basis and range or sensitivity.
- [ ] Assumptions have an owner, consequence, and review or expiry condition.
- [ ] Open questions have an impact, owner, and due date.
- [ ] The document does not fabricate customer evidence, market data, cost, schedule, legal interpretation, or technical validation.

## Requirements and decisions

- [ ] Obligations are testable and use consistent normative language.
- [ ] Decisions are distinguishable from proposals and assumptions.
- [ ] Numeric targets include operating conditions and measurement methods.
- [ ] Alternatives and trade-offs are recorded when the decision is costly to reverse.
- [ ] Failure, exception, recovery, and operational behavior are covered where material.

## Consistency

- [ ] Terms, actors, systems, states, identifiers, and units are used consistently.
- [ ] Scope, process, permissions, data ownership, interfaces, schedule, cost, and responsibilities do not contradict one another.
- [ ] Diagrams, tables, and prose describe the same boundaries and flows.
- [ ] Dates, versions, currencies, tax treatment, and time zones are explicit where needed.

## Traceability

- [ ] Stable identifiers are used only for items that need downstream reference.
- [ ] Objectives trace to requirements, design elements, and verification evidence as applicable.
- [ ] Every mandatory requirement has an owner and acceptance path.
- [ ] Every design element and planned test has an approved source.
- [ ] No mandatory item is orphaned and no implementation element is unjustified.

## Reader test

- [ ] A decision-maker can identify the recommendation, value, investment, risk, and requested decision.
- [ ] An implementer can identify contracts, constraints, failure behavior, and verification.
- [ ] An operator can identify ownership, monitoring, recovery, and escalation.
- [ ] A reviewer can distinguish complete, assumed, unresolved, and rejected content.
- [ ] The next action has an owner and condition for completion.

## Final hygiene

- [ ] No `TODO`, `TBD`, placeholder, hidden instruction, or unresolved comment remains without an explicit owner.
- [ ] Links and cross-references resolve.
- [ ] Tables use comparable rows and columns rather than packaging normal prose.
- [ ] Sensitive information and credentials are absent.
- [ ] The title, status, version, date, and approval state are current.
- [ ] For Word output, the latest rendered pages were inspected and contain no clipping, overlap, broken tables, missing glyphs, or incorrect headers and footers.
