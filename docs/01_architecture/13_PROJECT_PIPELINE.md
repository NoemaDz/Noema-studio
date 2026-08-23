# Project Pipeline

---

# Overview

A Noema project progresses through a sequence of well-defined stages.

Each stage transforms the project into a richer representation until all assets required for production are available.

The pipeline is deterministic and state-driven.

---

# Pipeline

```text
User Idea
    │
    ▼
Story Generation
    │
    ▼
Character Extraction
    │
    ▼
Character Image Generation
    │
    ▼
Scene Prompt Generation
    │
    ▼
Scene Image Generation
    │
    ▼
Video Generation (Future)
    │
    ▼
Voice Generation (Future)
    │
    ▼
Final Production
```

---

# Stage 1 — Story Generation

Input:

* User idea

Output:

* Story
* Scenes

---

# Stage 2 — Character Extraction

Input:

* Story

Output:

* Characters

---

# Stage 3 — Character Image Generation

Input:

* Characters

Output:

* Character reference images

---

# Stage 4 — Scene Prompt Generation

Input:

* Story
* Characters
* Style

Output:

* Image prompts for every scene

---

# Stage 5 — Scene Image Generation

Input:

* Scene prompts

Output:

* Generated images
* AI jobs
* Stored assets

---

# Future Stages

Planned pipeline extensions:

* Video generation
* Camera animation
* Voice synthesis
* Music generation
* Sound effects
* Automatic editing

---

# Pipeline Characteristics

The pipeline is:

* Sequential
* Reproducible
* Incremental
* Provider-independent

Each stage may internally execute one or more workflows.

---

# Project State

The project records its current stage.

Example:

```text
Story
↓

Characters
↓

Character Images
↓

Scene Prompts
↓

Scene Images
```

This allows interrupted projects to resume from the last completed stage.
