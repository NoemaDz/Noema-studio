# ADR-0002: Use Driver Pattern instead of Client Pattern

## Status

Accepted

## Context

AI providers are more than HTTP clients.

They are responsible for:

- submitting jobs
- polling execution
- downloading assets
- managing capabilities
- future websocket communication

Calling them "Client" understates their responsibility.

## Decision

Every infrastructure implementation will expose a Driver.

Core
    ↓
Provider
    ↓
Driver
    ↓
External AI System

Examples

- OllamaDriver
- ComfyUIDriver
- OpenAIDriver
- GeminiDriver

## Consequences

Advantages

- Better terminology
- Cleaner architecture
- Easier provider abstraction
- Future-proof

Noema Core remains completely provider-agnostic.