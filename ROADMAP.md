# Noema Studio - Roadmap

This document outlines the strategic phases and technical milestones for Noema Studio. As an open-source AI orchestration platform, our goal is to build a robust, extensible core before expanding outward to support every available AI model.

---

## Phase 1: Core Foundation (Current)
*Focus: Stabilize the architecture and prove the End-to-End concept.*

- [x] Project-centric domain model (`NoemaProject` as aggregate root)
- [x] Provider Abstraction (V1 interfaces for Image, TTS, LLM)
- [x] True DAG Pipeline Execution (Parallel scene processing)
- [x] Job System for background polling (ComfyUI integrations)
- [x] Basic Local LLM integration (Ollama)
- [x] Auto-Installer for Local ComfyUI + Nodes
- [ ] End-to-End Pipeline stability (Idea → LLM → ComfyUI → TTS → MP4)
- [ ] Centralized `PlatformPaths` for robust cross-platform execution
- [ ] Basic Unit Tests & CI/CD workflows

## Phase 2: Refinement & Coherence
*Focus: Ensuring the generated output actually feels like a produced video, not random clips.*

- [ ] Character Consistency enforcement (IPAdapter + Reference passing)
- [ ] Scene Editor / Timeline UI (Allow users to manually edit prompts before generation)
- [ ] Robust Project Persistence (JSON serialization/deserialization for large projects)
- [ ] Fail-safe Recovery (Resume failed pipelines from the exact broken node)

## Phase 3: The Plugin Ecosystem
*Focus: Opening the platform to external contributors and commercial APIs.*

- [ ] Formalize `IPlugin` SDK and capabilities
- [ ] Cloud Providers: OpenAI, Anthropic, ElevenLabs integrations
- [ ] Video Providers: Runway ML, Sora, Veo integrations
- [ ] Dynamic Capability Resolution (e.g. `If VRAM < 8GB, route to Cloud Provider`)

## Phase 4: Pro Features
*Focus: Advanced multimedia generation and marketplace.*

- [ ] Lip-syncing integration (Wav2Lip / SadTalker)
- [ ] Automatic Sound Effects (SFX) and Music Generation based on scene mood
- [ ] Workflow Marketplace (Share and download custom pipeline stages)
- [ ] Collaborative Cloud Projects

---
*Note: This roadmap is a living document and will evolve based on community feedback and open-source contributions.*
