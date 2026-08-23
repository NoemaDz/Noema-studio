# Contributing to Noema Studio 🛠️

First of all, thank you for considering contributing to Noema Studio! It's people like you that make Noema such a powerful tool for creators.

## Architecture Overview
Noema Studio is built on a **Pipeline and Plugin Architecture**. The core app knows *nothing* about ComfyUI, Ollama, or OpenAI directly. It only knows about `IPlugin`, `PipelineStage`, and `Provider`.

If you want to add a new AI model (like Runway, Luma, or a new TTS engine), you don't need to touch the core codebase. You just write a Plugin!

### How to add a new Provider Plugin
1. **Create your Provider:**
   Implement one of the core provider interfaces (`ImageProvider`, `LLMProvider`, `TTSProvider`, `VideoCompilerProvider`).
   ```dart
   class RunwayVideoProvider extends ImageProvider {
     @override
     String get id => 'runway_gen3';
     
     @override
     Future<Job> generateImage(String prompt, {Map<String, dynamic>? options}) async {
       // Call Runway API
       return Job(id: '123', type: 'video', status: JobStatus.completed);
     }
   }
   ```
2. **Create your Plugin:**
   ```dart
   class RunwayPlugin implements IPlugin {
     @override
     String get name => 'Runway ML Plugin';
     
     @override
     void register(PluginContext context) {
       context.providers.register(RunwayVideoProvider());
     }
   }
   ```
3. **Register it in `main.dart`:**
   Add it to the `noema.init([...])` list.

## How to add a new Pipeline Stage
Want to add automatic Lip-Syncing? Or Auto-Color Grading? You can insert a new stage into the pipeline.
1. Implement `PipelineStage`.
2. Give it a priority (e.g., `60` to run between Image Generation and Video Compilation).
3. Register it in your plugin: `context.pipelines.register(MyLipSyncStage());`.

## Best Practices
When contributing to Noema, please adhere to the following best practices:
1. **Security First:** Never concatenate external or API-provided filenames directly into local paths. Always use `path.basename(filename)` to prevent Path Traversal vulnerabilities.
2. **Surface Errors:** Do not silently catch exceptions in `PipelineStage`s. If a stage fails, let the error bubble up so the `ProjectPipeline` can catch it and surface it to the UI (so the user isn't stuck waiting forever).
3. **Graceful Fallbacks:** If an external asset or advanced feature is missing (e.g. an advanced ComfyUI workflow JSON), try to fallback to a simpler version rather than crashing the pipeline.
4. **Rich Metadata:** When creating Jobs, inject descriptive data into `job.metadata["title"]` so the `LiveProgressTracker` can give users context-aware progress updates.

## Submitting Pull Requests
1. Fork the repo and create your branch from `main`.
2. Make sure your code is clean and well-commented.
3. Test your changes locally.
4. Submit a PR with a clear description of what you've added or fixed.

Happy Coding! 🎬
