# ADR-0003: Layered Architecture

## Status

Accepted

---

## Context

As Noema evolved, the original `services` directory became responsible for multiple unrelated concerns:

- AI communication
- Storage
- Prompt generation
- Business logic

This made the architecture harder to understand and maintain.

---

## Decision

Noema adopts a strict layered architecture.

Each layer has a single responsibility.

```
UI
    │
    ▼
Workflows
    │
    ▼
Providers
    │
    ▼
Drivers
    │
    ▼
External Systems
```

Infrastructure components are grouped by technology.

```
infrastructure/
    comfyui/
    ollama/
    storage/
```

Prompt generation is isolated inside `builders`.

Composition is isolated inside `bootstrap`.

No generic `services` directory is allowed.

---

## Consequences

Advantages:

- Clear dependency flow.
- Easier testing.
- Easier replacement of AI engines.
- Better scalability.
- Reduced architectural ambiguity.

Trade-offs:

- More folders.
- Slightly more boilerplate.

These trade-offs are accepted.