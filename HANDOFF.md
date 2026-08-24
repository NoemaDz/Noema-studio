# Noema Studio Handoff

> **Note:** This document has been deprecated as of v0.1.0-alpha.
> 
> The project architecture and technical specifications are now officially maintained in [ARCHITECTURE.md](ARCHITECTURE.md).
> For future plans and execution milestones, please refer to [ROADMAP.md](ROADMAP.md).

## Quick Summary of Recent Architectural Changes
If you are reading this from an old context, please note:
- The project no longer uses hardcoded `C:\` paths. We have introduced `PlatformPaths` (in `core/settings/platform_paths.dart`) to ensure proper cross-platform support (Windows, Linux, macOS).
- The Flutter package name has been updated to `noema_studio`.
- `NoemaProject` is the unified aggregate root.
- The pipeline now utilizes a true DAG (Directed Acyclic Graph) engine (`PipelineEngine`) allowing per-scene parallelism.

**Please read `ARCHITECTURE.md` for the current truth.**
