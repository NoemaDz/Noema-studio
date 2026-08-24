# Noema Studio — Architecture Guide

> For contributors and developers who want to understand how Noema works under the hood.

---

## The Three Execution Layers

Noema separates "what to do", "in what order", and "how to track it" into three distinct systems:

```
┌─────────────────────────────────────────────────────────┐
│  Layer          │ Class             │ Responsibility      │
├─────────────────┼───────────────────┼─────────────────────┤
│  Workflow       │ WorkflowEngine    │ "What does AI DO?"  │
│                 │ WorkflowStep      │ (LLM calls, prompts)│
├─────────────────┼───────────────────┼─────────────────────┤
│  Pipeline       │ PipelineEngine    │ "In what ORDER?"    │
│                 │ TaskNode/DAG      │ (dependency graph)  │
├─────────────────┼───────────────────┼─────────────────────┤
│  Job System     │ JobMonitor        │ "Track background"  │
│                 │ JobManager        │ (ComfyUI polling)   │
└─────────────────┴───────────────────┴─────────────────────┘
```

**Rule:** A `Workflow` calls AI models. A `Pipeline` decides order. A `Job` tracks async work.
Never mix these responsibilities.

---

## The Canonical Project Model

`NoemaProject` (in `core/noema_project.dart`) is the **single Source of Truth** for all project state.

```
NoemaProject
  ├── Identity    : id, title, idea, language, createdAt
  ├── AI Settings : imageModel, llmModel
  ├── Content     : story (Story + Scenes), style, characters
  ├── Assets      : images (GeneratedImage[]), audios (GeneratedAudio[])
  ├── Execution   : tasks[], jobs[], projectState, stage
  └── Meta        : settings{}, metadata{}
```

> ⚠️ **DO NOT** create a parallel `Project` model. `NoemaProject` owns everything.
> If you need a UI-only representation, create a `ProjectViewModel` in the presentation layer.

---

## Pipeline DAG Structure

`ProjectPipeline` converts `PipelineStage`s into a true DAG via `PipelineEngine`.

### Stage Priority Guide

| Priority Range | Type | Runs |
|---|---|---|
| `0–49` | Planning (Planner, Characters, Prompts) | **Sequentially** |
| `50–69` | Per-scene Production (Image, Audio) | **In Parallel** per scene |
| `70+` | Compilation (Video Export) | **Sequentially** |

### Execution Graph (3 scenes example)

```
[AgentPlanner p=5] → [CharacterStage p=20] → [CharacterImageStage p=30]
                                                        │
                              ┌─────────────────────────┘
                              ▼
             ┌──────────────────────────────────┐
             │        (parallel, max 2)          │
    [SceneImage_1]    [SceneImage_2]    [SceneImage_3]
             │                │                  │
             └────────────────┴──────────────────┘
                              │ (join node)
             ┌──────────────────────────────────┐
             │        (parallel, max 2)          │
    [SceneAudio_1]    [SceneAudio_2]    [SceneAudio_3]
             └────────────────┴──────────────────┘
                              │ (join node)
                    [VideoCompilation p=70]
```

---

## How to Add a New AI Provider

1. Implement `ImageProvider` or `TTSProvider` or `LLMProvider` interface.
2. Register it in your plugin's `register(PluginContext context)`:
   ```dart
   context.providers.register(MyNewProvider());
   ```
3. Done. `ProxyLLMProvider` / `ProxyTTSProvider` will route to it based on `AppSettings`.

---

## How to Add a New Pipeline Stage

1. Create a new file in `lib/core/pipeline/stages/`.
2. Implement `PipelineStage`:
   ```dart
   class MyNewStage implements PipelineStage {
     @override
     int get priority => 55; // between 50-69 for per-scene work

     @override
     Future<void> run(NoemaProject project) async { ... }

     // Override this for true parallel execution per scene:
     @override
     Future<void> runForScene(NoemaProject project, Scene scene) async { ... }
   }
   ```
3. Register it in `CorePipelinePlugin.register()`.

---

## Project State Flow

```
User clicks Generate
        │
        ▼
StudioScreen._generateProject()
        │
        ▼
Noema.generateProject(project)
        │
        ▼
ProjectGenerationService.generateProject()
        │
        ▼
ProjectPipeline.generate()   ← DAG built here
        │
   [Planning stages run sequentially]
        │
   [Scene stages run in parallel via PipelineEngine]
        │
   [Compilation stage runs]
        │
        ▼
project.projectState = GenerationState.completed
        │
        ▼
ProjectState notifyListeners() → UI updates (Shimmer → Image)
```
