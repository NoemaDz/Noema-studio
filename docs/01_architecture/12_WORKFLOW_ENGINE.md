# Workflow Engine

---

# Overview

The Workflow Engine is the execution core of Noema.

It coordinates workflows, manages execution context, and executes workflow steps in sequence.

Business logic is implemented through workflows rather than inside UI, providers, or drivers.

---

# Architecture

```text
Workflow
      │
      ▼
Workflow Engine
      │
      ▼
Workflow Context
      │
      ▼
Workflow Step 1
      │
      ▼
Workflow Step 2
      │
      ▼
Workflow Step N
```

---

# Workflow

A workflow represents one complete business use-case.

Examples:

* Story generation
* Character extraction
* Character image generation
* Scene prompt generation
* Image generation

---

# Workflow Engine

Responsibilities:

* Execute workflows.
* Execute workflow steps in order.
* Manage execution context.
* Propagate errors.
* Return execution results.

The engine contains no business logic.

---

# Workflow Context

The context is shared between workflow steps.

It acts as temporary execution memory.

Examples:

* story
* prompt
* image
* characters

The context exists only during workflow execution.

---

# Workflow Step

A workflow step performs exactly one operation.

Examples:

* Generate story
* Parse story
* Extract characters
* Build prompts
* Submit image job

Each step:

* receives the current context
* modifies the context
* returns control to the engine

---

# Error Handling

If a step throws an exception:

* workflow execution stops
* the exception propagates to the caller

Recovery strategies are implemented by workflows, not by the engine.

---

# Design Principles

* Single Responsibility
* Context-based execution
* Stateless engine
* Sequential execution
* Provider independence

---

# Future Evolution

The Workflow Engine is designed to support future execution strategies without changing existing workflows.

Possible future extensions:

* Parallel execution
* Conditional branches
* Retry policies
* Progress reporting
* Distributed execution
