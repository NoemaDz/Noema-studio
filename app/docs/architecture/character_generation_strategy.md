# Character Generation Strategy

This document outlines the architectural strategy for ensuring Character Consistency across generated scenes in Noema Studio.

## 1. Goal
The primary challenge in generative AI storytelling is maintaining the exact facial and bodily features of a character across multiple scenes, angles, and lighting conditions. Noema Studio aims to solve this by abstracting the complexity of character consistency away from the user interface and into the core `WorkflowEngine`.

## 2. Supported Strategies

### Strategy A: IPAdapter (Zero-Shot Face Transfer) - *Currently Implemented*
**How it works:** 
The user provides a single reference image for a character. During the `SceneImageStage`, the system injects this image into the ComfyUI workflow using an `IPAdapter Unified Loader` node. ComfyUI extracts the semantic embeddings of the face and forces the diffusion model to reconstruct a similar face in the generated scene.

**Pros:**
- **Zero-Shot:** No training required. Instant results.
- **Dynamic:** The user can swap character images on the fly.

**Cons:**
- **Fidelity:** Consistency is around 70-80%. Hair color or eye shape might slightly vary depending on the prompt's interference.
- **Resource Heavy:** Requires heavy IPAdapter models loaded into VRAM alongside the base SDXL/SD1.5 model.

### Strategy B: LoRA (Low-Rank Adaptation) - *Planned for Beta 2*
**How it works:**
The user uploads 10-20 images of a character. The system submits a training job to a remote GPU service to train a custom LoRA model. Once trained, the LoRA is injected into the ComfyUI pipeline (via `LoraLoader`) and triggered using specific keywords in the prompt (e.g., `sks character`).

**Pros:**
- **High Fidelity:** Near 100% perfect character consistency.
- **Prompt Adherence:** Better adherence to complex prompts since the character identity is baked into the model weights rather than forced via image conditioning.

**Cons:**
- **Training Time:** Takes 10-30 minutes to train before it can be used.
- **Cost:** Requires dedicated training compute.

## 3. Implementation Details

### Current Separation of Concerns
We have strictly decoupled the UI from the character consistency logic.
- **UI (`GenerationPanel`)**: Only triggers `engine.run(project)`. It does not know what an IPAdapter or LoRA is.
- **Data Layer (`Scene`, `Character`)**: The `Scene` model contains references to characters and their scene positions, but no implementation details.
- **Logic Layer (`SceneImageStage`)**: Inspects the `NoemaProject` data. If it detects character references, it maps them into `scene.extras['characters']`.
- **Infrastructure (`ComfyUIWorkflowAdapter`)**: Converts `scene.extras['characters']` into actual IPAdapter node connections (`IPAdapter Advanced`, `LoadImage`).

### The Fallback Mechanism
Because IPAdapter models are large (often ~1-2GB) and might not be installed on the user's local ComfyUI instance, `SceneImageStage` implements a robust **Automatic Fallback**. 

If the `ComfyUIDriver` throws a `NoemaException` of type `modelNotFound` (detecting missing IPAdapter nodes), the `SceneImageStage`:
1. Logs a warning.
2. Strips the character image references from the `scene.extras`.
3. Re-submits the job as a pure **Text-to-Image** generation.

This ensures that the application remains Plug-and-Play and does not completely crash the pipeline if advanced consistency models are unavailable.
