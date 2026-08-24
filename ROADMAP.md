# Noema Studio - Core Architecture Roadmap

This roadmap defines the prioritized stages for consolidating the core architecture of Noema Studio, ensuring a robust, scalable, and professional foundation before expanding features.

## 1. Project State / Domain Model
- **Goal:** Define solid, serializable data models.
- **Details:** Refactor `Project`, `Scene`, `Character`, and `Dialogue` classes. Implement JSON serialization/deserialization to save and load projects locally. Introduce state management (e.g., `Draft`, `Generating`, `Completed`, `Failed`) for each component.

## 2. Dependency-aware Pipeline
- **Goal:** A robust execution engine.
- **Details:** Build a pipeline manager that understands task dependencies (e.g., TTS Audio and ComfyUI Image must both complete before FFmpeg Video Compilation can begin). Handle retries, cancellations, and concurrent execution gracefully.

## 3. Agent Planner + Orchestrator
- **Goal:** Smart idea decomposition.
- **Details:** Solidify the orchestrator that takes a raw user prompt and breaks it down into structured Scenes, Characters, and Dialogue using LLMs, feeding directly into the Domain Model.

## 4. Character / Scene Consistency
- **Goal:** Visual and narrative continuity.
- **Details:** Implement logic to pass character reference images (IPAdapter) or seed data between scenes to maintain consistent appearances and styles throughout the generated video.

## 5. Provider Capability & Model Selection
- **Goal:** Abstracted provider interfaces.
- **Details:** Create a unified interface for different AI providers (Local vs Cloud). Allow dynamic selection of capabilities based on what the user has configured (e.g., fallback to basic image generation if a complex workflow fails).

## 6. Video Generation
- **Goal:** Core generation capabilities.
- **Details:** Integrate Image-to-Video models (like AnimateDiff, SVD, or Cloud APIs). Map generation statuses directly to the Domain Model.

## 7. Timeline / Editing
- **Goal:** Non-linear editing capabilities.
- **Details:** Build a visual timeline UI where users can drag, drop, trim, and reorder generated clips, audio tracks, and adjust the final composition before rendering.

## 8. المزيد من Providers (More Providers)
- **Goal:** Expand ecosystem integrations.
- **Details:** Once the core pipeline is bulletproof, add plugins for Runway, Sora, ElevenLabs, Kling, etc.
