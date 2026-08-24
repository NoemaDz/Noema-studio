# Contributing to Noema Studio 🤝

First off, thank you for considering contributing to Noema Studio! It's people like you that make Noema Studio such a great tool for AI orchestration and video generation.

## How Can I Contribute?

### Reporting Bugs
If you find a bug, please create an issue using the bug report template. Be sure to include:
- A clear and descriptive title.
- Steps to reproduce the behavior.
- Your OS and Flutter version.

### Suggesting Enhancements
We are always looking for new features (new AI models, UI improvements, etc.). Please create an issue with the feature request template.

### Code Contributions
Noema Studio is built on a very solid foundation. If you want to contribute code, here is what you need to know about our Architecture:

## Understanding the Core Architecture

### 1. The Pipeline Engine (DAG)
The core of Noema Studio is the **Directed Acyclic Graph (DAG) Pipeline Engine**. 
Instead of running tasks sequentially in a for-loop, tasks are instances of `TaskNode`. The `PipelineEngine` dynamically schedules tasks in parallel while ensuring that `maxConcurrentTasks` (currently set to 2 to prevent GPU OOM on ComfyUI) is respected.
If you add a new heavy operation (like generating audio), wrap it in a `TaskNode` and define its dependencies (`dependsOn`).

### 2. Pipeline Stages
We separated the AI Orchestration logic into modular `PipelineStage` classes.
If you want to add a new AI model (e.g., ElevenLabs for Voice), you should:
1. Create a new file in `lib/core/pipeline/stages/`.
2. Implement the `PipelineStage` interface.
3. Register your stage in `ProjectPipeline`.

### 3. Agent Planner & Workflow Context
We use a Context-based workflow. The `WorkflowContext` object is passed between workflows, ensuring state is kept without tightly coupling components.
If an LLM returns unpredictable JSON with markdown (like ```json ... ```), you **must** use the `JsonExtractor.extract(response)` utility to safely extract the raw JSON string before parsing it.

## Pull Request Process
1. Fork the repo and create your branch from `main`.
2. Make your changes following the Architecture rules.
3. Ensure your code compiles without warnings by running `dart analyze`.
4. Issue a Pull Request with a clear description of what you've done.

Thank you for helping us make the best open-source AI Studio!
