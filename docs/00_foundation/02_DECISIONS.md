# Architectural Decisions

This document indexes the Architectural Decision Records (ADRs) adopted by the Noema project.

---

## ADR-0001 — Provider Boundary

Status: Accepted

Defines the Provider abstraction as the only interface visible to workflows.

Providers isolate business logic from implementation details.

Reference:

* `docs/decisions/ADR-0001-provider-boundary.md`

---

## ADR-0002 — Driver Pattern

Status: Accepted

Introduces Drivers as low-level adapters responsible for communicating with external systems.

Drivers contain no business logic.

Reference:

* `docs/decisions/ADR-0002-driver-pattern.md`

---

## ADR-0003 — Layered Architecture

Status: Accepted

Defines the architectural layers of Noema.

Removes the generic `services` layer and replaces it with explicit architectural layers.

Reference:

* `docs/decisions/ADR-0003-layered-architecture.md`

---

# Decision Policy

Every architectural decision that changes the structure of the project must be documented as an ADR.

The architecture documentation describes the current state.

ADRs describe why the architecture evolved.
