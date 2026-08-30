import 'plugin_interface.dart';
import 'plugin_context.dart';

import '../providers/image_provider.dart';
import '../providers/proxy_llm_provider.dart';

import '../pipeline/stages/agent_planner_stage.dart';
import '../pipeline/stages/character_image_stage.dart';
import '../pipeline/stages/scene_image_stage.dart';
import '../pipeline/stages/scene_video_stage.dart';
import '../providers/video_provider.dart';
import '../pipeline/stages/scene_audio_stage.dart';
import '../pipeline/stages/video_compilation_stage.dart';
import '../providers/proxy_tts_provider.dart' as import_proxy_tts;
import '../../infrastructure/tts/flutter_tts_provider.dart' as import_tts;
import '../../infrastructure/openai/openai_tts_provider.dart'
    as import_openai_tts;
import '../../infrastructure/edge_tts/edge_tts_provider.dart'
    as import_edge_tts;
import '../providers/video_compiler_provider.dart';

class CorePipelinePlugin extends IPlugin {
  @override
  String get id => 'core_pipeline';

  @override
  String get name => 'Core Pipeline';

  @override
  String get version => '1.0.0';

  @override
  void register(PluginContext context) {
    // Lazily resolve providers to allow other plugins to register them first
    // Or we assume that when the pipeline actually runs, the default provider is used.
    // Since the stages currently require providers in their constructors,
    // we must fetch them from the context.providers registry.
    // If we want it to be truly dynamic (fetching at run time), we'd modify the stages.
    // For now, we fetch the default provider during registration.

    // Note: To avoid crashing if no provider is registered yet,
    // it's better if stages resolve providers at execution time, or we register stages
    // in a post-initialization phase.

    // As a bridge for the current architecture:
    // Use ProxyLLMProvider for dynamic LLM switching based on settings
    final llmProvider = ProxyLLMProvider(context);
    final imageProvider = context.providers.getDefault<ImageProvider>();

    // Register individual TTS providers so they are available in the context
    context.providers.register(import_tts.FlutterTTSProvider());
    context.providers.register(import_openai_tts.OpenAITTSProvider());
    context.providers.register(import_edge_tts.EdgeTTSProvider());

    // We use ProxyTTSProvider to route requests dynamically
    final ttsProvider = import_proxy_tts.ProxyTTSProvider(context);

    final videoProvider = context.providers.getDefault<VideoCompilerProvider>();

    // We are now using AgentPlannerStage as the primary planner.
    // It replaces StoryStage, CharacterStage (partially), and ScenePromptStage.
    context.pipelines.register(
      AgentPlannerStage(engine: context.engine, provider: llmProvider),
    );

    // CharacterStage is now obsolete because AgentPlannerStage acts as a full Director Agent
    // context.pipelines.register(
    //   CharacterStage(engine: context.engine, provider: llmProvider),
    // );

    context.pipelines.register(
      CharacterImageStage(
        engine: context.engine,
        provider: imageProvider,
        jobManager: context.jobManager,
      ),
    );

    context.pipelines.register(
      SceneImageStage(
        engine: context.engine,
        provider: imageProvider,
        jobManager: context.jobManager,
      ),
    );

    final i2vProvider = context.providers.get<VideoProvider>('proxy_video');
    context.pipelines.register(
      SceneVideoStage(
        engine: context.engine,
        provider: i2vProvider,
        jobManager: context.jobManager,
        appSettings: context.appSettings,
      ),
    );

    context.pipelines.register(
      SceneAudioStage(
        engine: context.engine,
        provider: ttsProvider,
        jobManager: context.jobManager,
      ),
    );

    context.pipelines.register(
      VideoCompilationStage(
        engine: context.engine,
        provider: videoProvider,
        jobManager: context.jobManager,
      ),
    );
  }
}
