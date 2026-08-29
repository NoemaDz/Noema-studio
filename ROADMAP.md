# Noema Studio - Roadmap

This document outlines the strategic phases and technical milestones for Noema Studio. As an open-source AI orchestration platform, our goal is to build a robust, extensible core before expanding outward to support every available AI model.

---

## Phase 1: Core Hardening (Completed - Beta 1)
*Focus: Stabilize architecture, job state machine, error classification, and persistence.*

- [x] Project-centric domain model (`NoemaProject` as aggregate root)
- [x] Provider Abstraction (Interfaces for Image, Video, TTS, LLM)
- [x] True DAG Pipeline Execution (Parallel scene processing)
- [x] Strict Job State Machine (`transitionTo()` with `starting`, `retrying`, `cancelling`, `cancelled`)
- [x] Error Classification & Retry Policy (`NoemaException` & `NoemaErrorType`)
- [x] Strict Local Disk Output Verification (existence, >0 bytes, extension check)
- [x] Active Job State Persistence (`savedJobs` snapshotting & restore on startup)

## Phase 2: Product Stabilization (Completed - Beta 2)
*Focus: ComfyUI pre-flight checks, input sanitization, and UI lifecycle transparency.*

- [x] ComfyUI Pre-flight Check (`ComfyUIPreflightChecker` querying `/object_info` pre-submission)
- [x] Automatic IPAdapter Missing Model Fallback (Zero-crash fallback to standard text-to-image)
- [x] AppSettings Sanitization & Input Validation (URL normalization & whitespace trimming)
- [x] UI Granular Status Badges & Interactive Cancellation (`LiveProgressTracker`)

## Phase 3: Production Hardening (Completed - Release Candidate 1 - RC 1)
*Focus: Zero unhandled crashes, crash logging, error boundary, and VRAM memory management.*

- [x] Global Crash Logger (`CrashLogger` logging stack traces to `noema_crash.log`)
- [x] UI Subtree Error Boundary (`ErrorBoundary` widget preventing Red Screen of Death)
- [x] ComfyUI Emergency VRAM Cleanup (`/free` and `/interrupt` signal dispatch on cancellation)
- [x] End-to-End Test Suite & Static Analysis Verification (`flutter analyze`: 0 issues)

## Phase 4: Plugin Ecosystem & Pro Features (Current Target)
*Focus: Opening the platform to external contributors and commercial cloud APIs.*

- [ ] Formalize `IPlugin` SDK and capabilities
- [ ] Cloud Video Providers: Runway ML, Sora, Veo integrations
- [ ] Lip-syncing integration (Wav2Lip / SadTalker)
- [ ] Automatic Sound Effects (SFX) and Music Generation based on scene mood
- [ ] Capability-Based Orchestration (`If VRAM < 8GB, route to Cloud Provider`)

---
*Note: This roadmap is a living document and will evolve based on community feedback and open-source contributions.*
