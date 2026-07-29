# Requirements Definition

Use this structure to translate an approved product direction into bounded, verifiable business and system requirements. Do not redesign the product strategy or choose implementation technology here.

## Inputs

- Approved PRD, problem statement, or initiative brief
- Current business process and pain evidence
- Stakeholder and user roles
- Applicable policies, regulations, contracts, and existing interfaces
- Known operational, migration, schedule, and budget constraints

## Standard structure

| Chapter | Purpose | Required content | Completion check |
|---|---|---|---|
| 1. Document purpose | Establish why the document exists | Intended readers, expected approval, lifecycle status, related artifacts | A reader can state the decision this document supports |
| 2. Background and objectives | Connect the systemization effort to the business need | Current problem, why now, desired outcomes, measurable objectives | Objectives describe outcomes rather than implementation |
| 3. Scope and exclusions | Bound responsibility and prevent scope drift | In-scope organizations, users, processes, data, systems, locations, releases; explicit exclusions | Every major request can be classified in or out |
| 4. Stakeholders and terminology | Make ownership and language unambiguous | Stakeholders, decision owners, users, glossary, abbreviations | Terms have one meaning throughout the document |
| 5. Current and target operations | Show the required business change | As-is process, pain points, to-be process, handoffs, exceptions | Differences between current and target states are explicit |
| 6. Business requirements | Define business capabilities and rules | `BR-*` statements, rationale, priority, owner, source | Each requirement supports an objective and avoids solution detail |
| 7. Functional requirements | Define observable system behavior | `FR-*` statements, actors, trigger, precondition, behavior, result, priority | Each requirement is independently testable |
| 8. Data requirements | Define information needed and governed | Data entities, ownership, source of truth, lifecycle, quality, retention, privacy classification | Data ownership and lifecycle are explicit |
| 9. External interface requirements | Define contracts with external parties and systems | `IF-*` producer, consumer, data, protocol constraints, timing, failure expectation | Both sides and failure responsibilities are named |
| 10. Non-functional requirements | Define measurable quality constraints | `NFR-*` performance, availability, security, privacy, accessibility, scalability, maintainability, observability | Every target has a metric, condition, and verification method |
| 11. Constraints and assumptions | Expose limits and uncertainty | Technology mandates only when externally constrained, policy, budget, schedule, staffing, assumptions, expiry or review date | Assumptions have owners and consequences |
| 12. Migration and operations requirements | Define transition and ongoing service needs | Data migration, cutover, rollback, training, support, monitoring, backup, recovery, maintenance windows | Day-one and steady-state responsibilities are covered |
| 13. Acceptance conditions | Define approval and delivery pass/fail | Business acceptance, system acceptance, evidence, approver, test environment | Acceptance can be evaluated without subjective interpretation |
| 14. Requirements traceability | Connect objectives to verification | Objective → `BR` → `FR`/`NFR`/`IF` → acceptance evidence | No mandatory requirement is orphaned |
| 15. Open issues and approval | Make remaining decisions visible | Open question, impact, owner, due date, status; approval record | No hidden blocker remains in narrative text |

## Writing rules

- Write requirements as obligations using “must” or an equally testable form.
- Keep one independently verifiable obligation per requirement.
- Separate requirements from design choices. Record externally imposed design constraints as constraints, not preferences.
- State the operational condition for numeric targets, such as load, geography, percentile, and measurement window.
- Include negative and failure behavior when it affects users, data integrity, compliance, or recovery.
- Link legal or regulatory requirements to the authoritative source without presenting unverified legal interpretation as fact.

## Required quality gates

- Every objective is supported by at least one business requirement.
- Every mandatory functional and non-functional requirement has an acceptance path.
- Scope, interfaces, data ownership, and operational ownership do not contradict one another.
- The document does not duplicate the PRD's market narrative or a technical specification's implementation design.
