# Domain Model

---

## Overview

The domain model defines the core business entities of Noema.

These entities represent the project state independently of the user interface and AI providers.

---

# Root Entity

```
NoemaProject
```

The project is the aggregate root.

It owns the complete production state.

---

# Main Entities

## Story

Represents the generated story.

Contains:

* title
* scenes

---

## Scene

Represents a single scene.

Contains:

* id
* description
* imagePrompt

---

## Character

Represents a story character.

Contains:

* name
* description
* reference images

---

## GeneratedImage

Represents an image produced by an AI engine.

Contains:

* sceneId
* prompt
* imageId
* localPath

---

## Job

Represents an asynchronous AI task.

Contains:

* id
* type
* status

Job lifecycle:

```
Queued
↓

Running
↓

Completed
```

or

```
Queued
↓

Running
↓

Failed
```

---

## ProjectTask

Represents a workflow execution inside the project.

Contains:

* task type
* state
* timestamps

---

## Style

Represents the artistic style used during generation.

Examples:

* Anime
* Pixar
* Realistic
* Comic

---

# Aggregate

```
NoemaProject
│
├── Story
│      └── Scene[]
│
├── Character[]
│
├── GeneratedImage[]
│
├── Job[]
│
├── ProjectTask[]
│
└── Style
```

---

# Design Rules

Models are pure data structures.

Models never:

* communicate with AI providers
* access storage
* execute workflows
* contain business logic

All domain models support serialization.

Each model implements:

- toJson()
- fromJson()

Persistence is performed outside the domain layer.
