# Job System

## Overview

The Job System is responsible for managing every asynchronous operation executed by AI providers.

Instead of treating AI generation as an instant operation, every request becomes a Job with a well-defined lifecycle.

The Job System is provider-independent and serves as the execution backbone of Noema.

---

## Goals

The Job System is designed to:

- Track asynchronous execution
- Support multiple AI providers
- Monitor progress
- Handle failures
- Synchronize generated assets
- Keep the Domain Model updated
- Notify the Presentation layer

---

## Job Lifecycle

```
Pending
    │
    ▼
Queued
    │
    ▼
Running
    │
    ▼
Completed
      or
Failed
```

---

# Architecture

```
Provider
    │
    ▼
JobRunner
    │
    ▼
JobMonitor
    │
    ▼
JobEvents
    │
    ▼
ProjectSynchronizer
    │
    ├── Updates Domain
    ▼
NoemaProject
    │
    └── Signals Presentation
            ▼
ProjectState
            ▼
UI
```

---

# Components

## Job

Represents a single asynchronous AI task.

Contains:

- id
- status
- progress
- provider metadata

---

## JobRunner

Communicates with the provider.

Responsibilities:

- Query job status
- Update progress
- Detect completion
- Detect failures

JobRunner never modifies the project.

---

## JobMonitor

Polls running jobs periodically.

Responsibilities:

- Monitor active jobs
- Invoke JobRunner
- Dispatch events when a job changes

JobMonitor contains no business logic.

---

## JobEvents

Lightweight event dispatcher.

Responsibilities:

- Broadcast job updates
- Decouple monitoring from synchronization

JobEvents never knows about the project or the UI.

---

## ProjectSynchronizer

Synchronizes completed jobs with the Domain Model.

Responsibilities:

- Download generated assets
- Update GeneratedImage.asset
- Keep NoemaProject synchronized

ProjectSynchronizer never updates UI widgets.

---

## ProjectState

Presentation State.

Responsibilities:

- Notify the UI when the Domain changes.
- Trigger widget rebuilds.

Contains no business logic.

---

# Layer Responsibilities

## Domain

Contains only pure models.

Examples:

- NoemaProject
- Story
- Scene
- GeneratedImage

The Domain never depends on Flutter.

---

## Application

Coordinates asynchronous execution.

Examples:

- JobRunner
- JobMonitor
- JobEvents
- ProjectSynchronizer

Application services never manipulate widgets.

---

## Presentation

Responsible only for notifying the UI.

Current implementation:

- ProjectState

---

## UI

Listens only to Presentation State.

Widgets never subscribe directly to:

- JobRunner
- JobMonitor
- JobEvents
- ProjectSynchronizer

---

# Design Principles

## Provider Independence

The Job System never depends on a specific AI provider.

Providers expose a common interface.

---

## Event Driven

Communication between execution and synchronization is event-driven.

No direct coupling exists between monitoring and project updates.

---

## Layer Isolation

Each layer has a single responsibility.

```
Provider
        ↓
Application
        ↓
Domain
        ↓
Presentation
        ↓
UI
```

No layer is allowed to bypass another.

---

## Current Status

Implemented

- Job model
- JobRunner
- JobMonitor
- JobEvents
- ProjectSynchronizer
- Asset download
- Presentation State notifications
- UI synchronization

---

## Future Extensions

The same architecture will be reused for:

- Video generation
- Audio generation
- Animation rendering
- 3D generation
- Batch processing
- Cloud execution

No architectural changes should be required to support new AI providers.