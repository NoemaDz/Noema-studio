# Noema Architecture

Version: Alpha 0.1

---

# Overview

Noema is an AI orchestration SDK designed around strict separation of responsibilities.

The architecture follows a layered approach where every layer depends only on the layer directly below it.

```
                UI
                │
                ▼
             Noema API
                │
                ▼
           Workflow Engine
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
        External AI Systems
```

---

# Project Structure

```
lib/

bootstrap/
builders/
core/
infrastructure/
models/
repositories/
ui/
workflows/
```

---

# Layer Responsibilities

## bootstrap

Application composition.

Responsible for wiring dependencies.

---

## core

Framework-independent business infrastructure.

Contains:

- Workflow Engine
- Workflow Context
- Provider interfaces
- Job system

---

## builders

Responsible for constructing prompts and intermediate objects.

Contains no networking or business logic.

---

## workflows

Application use-cases.

Each workflow coordinates providers without knowing implementation details.

---

## infrastructure

Integration with external systems.

Examples:

- Ollama
- ComfyUI
- Local Storage

Every external system exposes:

- Provider
- Driver

---

## models

Pure data structures.

No networking.

No business logic.

---

## repositories

Persistence abstraction.

---

## ui

Flutter presentation layer.

No business logic.

---

# Dependency Rules

Allowed dependencies:

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

Reverse dependencies are forbidden.

---

# Architectural Principles

- Single Responsibility Principle
- Dependency Injection
- Composition Root
- Provider Pattern
- Driver Pattern
- Workflow-based execution
- Infrastructure isolation