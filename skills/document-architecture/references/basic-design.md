# Basic Design

Use this structure to define the externally observable system specification and the major internal boundaries that realize it. Keep implementation-level algorithms and function details in the detailed design.

## Inputs

- Approved requirements definition
- Approved technical architecture and relevant ADRs
- User roles, business processes, interface constraints, and data requirements
- UI, accessibility, operations, and migration standards

## Standard structure

| Chapter | Purpose | Required content | Completion check |
|---|---|---|---|
| 1. Purpose and scope | Define the design baseline | Readers, covered requirement IDs, exclusions, related documents | Design ownership is unambiguous |
| 2. Overall system structure | Orient readers to the solution | System context, subsystems, responsibility boundaries, principal flows | Every in-scope function has a system owner |
| 3. Users, roles, and permissions | Define authorized behavior | Roles, capabilities, data scope, separation of duties, approval paths | Permission rules cover normal and exceptional actions |
| 4. Business and functional flows | Translate requirements into end-to-end behavior | Triggers, actors, steps, states, handoffs, alternate and failure flows | Flows cover requirements and operational exceptions |
| 5. Screen flow and screen design | Define user-visible interaction contracts | Navigation, screen inventory, states, inputs, validation, actions, feedback, accessibility | Each screen has entry, success, empty, loading, and error behavior as applicable |
| 6. Reports and outputs | Define generated information | Audience, fields, filters, sort, grouping, format, timing, distribution, retention | Output content and delivery responsibility are testable |
| 7. APIs and external interfaces | Define externally visible contracts | Operations, schemas, authentication, validation, status or error model, timing, versioning | Both sides can agree on one contract |
| 8. Logical data design | Define business information structure | Entities, attributes, relationships, identifiers, lifecycle, ownership, validation | Data supports all flows without conflicting ownership |
| 9. Batch and scheduled jobs | Define non-interactive processing | Trigger, schedule, input, output, restart, duplicate prevention, monitoring, cutoff | Operators can rerun and recover safely |
| 10. Messages and error presentation | Make user and operator feedback consistent | Message catalog, severity, audience, localization, recovery action, correlation identifier | Messages tell the audience what happened and what to do |
| 11. Non-functional design | Allocate quality requirements | Performance budgets, availability, accessibility, security, privacy, observability, capacity | Each `NFR-*` maps to a design response |
| 12. Operations and migration | Define service transition and operation | Environments, configuration, support, monitoring, backup, recovery, migration, cutover | Ownership exists for deployment through steady state |
| 13. Requirements mapping | Show design coverage | Requirement → flow, screen, interface, data element, job, or operation | No approved requirement is unimplemented in the basic design |

## Writing rules

- Describe what users and connected systems observe before describing internal mechanics.
- Keep screen, API, report, batch, and data terminology consistent.
- Define state transitions and permissions once, then reference them from individual screens or operations.
- Do not prescribe classes, functions, queries, or low-level algorithms unless they are an approved external constraint.

## Required quality gates

- User flows, permissions, screens, APIs, and logical data use the same states and terms.
- Every error state has an audience, message, and recovery path.
- Batch and interface designs include duplicate prevention, restart, and monitoring.
- Every requirement maps to at least one basic-design element.
