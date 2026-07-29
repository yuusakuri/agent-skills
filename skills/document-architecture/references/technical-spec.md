# Technical Specification

Use this structure after the technical approach has been selected. Record how the system will satisfy approved requirements and which implementation constraints must remain stable.

## Inputs

- Approved requirements and acceptance conditions
- Selected technical approach and relevant ADRs
- Existing system architecture, data model, API contracts, and deployment constraints
- Security, privacy, reliability, capacity, and operations requirements

## Standard structure

| Chapter | Purpose | Required content | Completion check |
|---|---|---|---|
| 1. Purpose and scope | Bound the technical decision surface | Intended implementers, covered requirements, exclusions, related ADRs and designs | Readers know what this specification owns |
| 2. Input requirements and assumptions | Establish authoritative inputs | Requirement IDs, constraints, dependencies, validated assumptions, unresolved blockers | Inputs are linked rather than rewritten inconsistently |
| 3. Architecture overview | Explain the selected system shape | Context diagram, architecture style, major boundaries, dependency direction, rationale links | Components and trust boundaries are visible |
| 4. Components and responsibilities | Assign behavior to clear owners | Component purpose, public contract, dependencies, state ownership, scaling unit | No behavior has multiple owners |
| 5. Runtime and deployment topology | Define where and how components run | Environments, nodes or services, network zones, configuration, secrets, rollout topology | Deployment and trust boundaries match |
| 6. Data model and persistence | Define durable and transient state | Logical and physical models, source of truth, consistency, transactions, indexing, retention, migration | Data ownership and consistency rules are explicit |
| 7. APIs, events, and integrations | Define machine contracts | Endpoints or messages, schemas, versioning, authentication, idempotency, timeouts, compatibility | Producers and consumers can implement independently |
| 8. Security and privacy | Apply controls to identified threats | Threats, authorization, validation, encryption, secret handling, audit, privacy controls | Every sensitive flow crosses an explicit control |
| 9. Failure handling and observability | Make degraded behavior operable | Failure modes, retries, backoff, circuit breaking, recovery, logs, metrics, traces, alerts, runbooks | Operators can detect, diagnose, and recover |
| 10. Performance and capacity | Size the design against targets | Load model, latency and throughput budgets, capacity assumptions, scaling triggers, limits | Targets map to measurement and capacity evidence |
| 11. Test strategy | Define proof at each boundary | Unit, contract, integration, migration, security, performance, resilience, end-to-end tests | High-risk decisions have explicit verification |
| 12. Migration and rollback | Change the system safely | Compatibility stages, data backfill, cutover, validation, rollback conditions, cleanup | Every irreversible step is identified |
| 13. Risks and trade-offs | Preserve engineering reasoning | `RSK-*`, accepted trade-offs, mitigation, owner, trigger, review date | Risks are actionable and linked to decisions |
| 14. Requirements mapping | Prove coverage | Requirement → component or contract → test or operational evidence | No mandatory technical requirement is orphaned |

## Writing rules

- Reference ADRs for the reason a costly-to-reverse option was selected; do not duplicate the full decision history.
- Specify public contracts and invariants more precisely than internal implementation details.
- State failure behavior for every remote call, asynchronous process, and durable write path.
- Treat configuration, secrets, observability, migration, and rollback as first-class design elements.
- Include diagrams only when they clarify boundaries, flow, sequence, topology, or state.

## Required quality gates

- Component responsibilities, data ownership, and deployment topology agree.
- API and event contracts define compatibility, authentication, validation, timeout, and failure behavior.
- Security controls correspond to actual trust-boundary crossings.
- The test strategy proves the risky parts of the selected design.
- The document records a selected approach rather than reopening unresolved design exploration.
