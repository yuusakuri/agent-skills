# Detailed Design

Use this structure to make an approved basic design implementable and unit-testable. Follow the codebase's actual language, framework, and module conventions.

## Inputs

- Approved requirements, technical specification, and basic design
- Current source layout, public interfaces, coding rules, and test conventions
- Physical data schema and infrastructure constraints
- Relevant ADRs and security requirements

## Standard structure

| Chapter | Purpose | Required content | Completion check |
|---|---|---|---|
| 1. Purpose and scope | Bound the implementation slice | Target release, modules, requirement and basic-design IDs, exclusions | The implementation boundary is small and clear |
| 2. Implementation units and dependencies | Define change ownership and order | Modules, packages, services, dependency direction, public entry points | No circular or hidden dependency is introduced |
| 3. Modules, classes, and functions | Define implementation contracts | Responsibility, inputs, outputs, types, invariants, side effects, errors, visibility | Each unit has one reason to change and a testable contract |
| 4. Processing flow and state transitions | Specify control and state behavior | Sequence, branching, state machine, preconditions, postconditions, compensation | Every branch terminates in a defined result |
| 5. Physical data and transactions | Define storage operations | Tables or collections, columns, keys, indexes, queries, transaction boundaries, locking, migrations | Updates preserve constraints under failure and concurrency |
| 6. API implementation and validation | Map contracts to handlers and clients | Parsing, validation, authorization, mapping, service call, response, compatibility | Invalid and unauthorized input fails at the boundary |
| 7. Business rules and algorithms | Make non-obvious logic deterministic | Rule order, formulas, rounding, time and locale behavior, limits, examples | Edge conditions produce one expected result |
| 8. Exceptions, retries, and idempotency | Prevent ambiguous failure behavior | Error types, propagation, retry eligibility, backoff, deduplication key, compensation | Repetition and partial failure cannot corrupt state |
| 9. Concurrency and performance | Define resource behavior | Contention, race prevention, async boundaries, caching, memory and latency budgets | Concurrency assumptions are testable |
| 10. Logs, metrics, and audit | Define operational evidence | Events, fields, levels, correlation, sensitive-data exclusions, metrics, alerts, audit records | Failures can be traced without exposing secrets |
| 11. Security controls | Place controls in concrete units | Authorization points, validation, encoding, secret access, encryption, privacy enforcement | Every trust boundary has an implementation control |
| 12. Unit test design | Prove each implementation contract | Test cases, fixtures, normal, boundary, failure, concurrency, security, determinism | Tests cover rules and failure paths, not just line execution |
| 13. Traceability | Connect implementation to approved design | Requirement and design ID → module or function → test | Every implementation unit has a justified source |

## Writing rules

- Use real repository paths and actual public type or function names when the codebase exists.
- Separate public contracts from replaceable internals.
- Define transaction, retry, time, locale, numeric, and concurrency behavior explicitly.
- Prefer pseudocode only when exact code would prematurely constrain implementation.
- Keep file-level task ordering in the implementation plan, not in this design.

## Required quality gates

- The design can be implemented without inventing missing business rules.
- Function and module boundaries follow the actual dependency direction.
- Data changes specify transactions, concurrency, migration, and rollback behavior.
- Unit tests cover every non-trivial rule and material failure mode.
