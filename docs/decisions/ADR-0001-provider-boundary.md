# ADR-0001: Keep the Core Provider-Agnostic

## Status

Accepted

## Context

During the implementation of the Job System, we considered making
JobRunner directly communicate with ComfyUI services.

This would make the Core layer aware of provider-specific
implementation details.

## Decision

The Core must never depend on ComfyUI.

Instead:

Core
    ↓
Provider Interface
    ↓
Concrete Provider
    ↓
Provider Services

Every provider is responsible for its own:

- Job polling
- Download logic
- Asset retrieval

The Core only works with abstract providers.

## Consequences

Advantages

- Easy provider replacement
- Easy testing
- Cleaner architecture
- Better Open Source contribution

Disadvantages

- Slightly more abstraction

The architectural consistency is worth the additional abstraction.