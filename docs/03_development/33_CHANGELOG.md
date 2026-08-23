## Sprint 4

### Added

- ProjectProgress
- ProjectStatistics
- ProjectSummary
- ProjectStorage abstraction
- JsonProjectStorage
- Full project serialization

### Improved

- NoemaProject can now be serialized and restored.

## Sprint 6

### Added

- Save Project
- Open Project
- File Picker integration
- JSON persistence

### Completed

- Full project persistence workflow.
# Sprint 7

## Added

- Project Explorer widget.
- Explorer sections using ExpansionTile.
- Project overview panel.
- Character list.
- Scene list.
- Generated images list.
- Character details dialog.
- Scene details dialog.
- Responsive-ready Project Explorer layout.

## Improved

- Refactored UI into reusable widgets.
- Simplified main.dart by moving project UI into ProjectExplorer.
- Fixed SceneDetails overflow using SingleChildScrollView.
- Improved project navigation.

## Architecture

- Introduced ExplorerSection component.
- Prepared ProjectExplorer for future Inspector layout.
- Identified Job Pipeline limitation between image generation and asset retrieval.
- Deferred Inspector Panel and Job integration to Sprint 8.