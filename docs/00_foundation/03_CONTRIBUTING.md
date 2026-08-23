# Contributing to Noema

Thank you for contributing to Noema.

This document defines the architectural and development rules that every contribution must follow.

---

# General Principles

* Keep the architecture clean.
* Prefer readability over cleverness.
* Every component must have a single responsibility.
* Do not introduce unnecessary abstractions.
* Maintain backward compatibility whenever possible.

---

# Architecture Rules

Every new class must belong to a single architectural layer.

```
bootstrap
builders
core
infrastructure
models
repositories
ui
workflows
```

Never create generic directories such as:

```
services
helpers
utils
misc
common
```

unless an Architecture Decision Record explicitly introduces them.

---

# Dependency Rules

Dependencies must always follow the architecture.

Allowed direction:

```
UI
↓

Core

↓

Workflows

↓

Providers

↓

Drivers

↓

External Systems
```

Reverse dependencies are not allowed.

---

# Providers

Providers expose capabilities to workflows.

Providers must never contain implementation details.

---

# Drivers

Drivers communicate with external systems.

Drivers must never contain business logic.

---

# Workflows

A workflow represents a complete business use-case.

Each workflow is composed of multiple workflow steps.

---

# Builders

Builders generate prompts and intermediate objects.

Builders perform no networking.

---

# Models

Models are pure data structures.

Models contain no networking and no business logic.

---

# Documentation

Every architectural change must update the relevant documentation.

Every major architectural decision requires a new ADR.

---

# Code Quality

Before every commit:

* Project builds successfully.
* `flutter analyze` reports zero errors.
* New code follows the existing architecture.
* Documentation is updated when required.

---

# Philosophy

The architecture is considered part of the product.

Code that violates the architecture will not be accepted, even if it works.
