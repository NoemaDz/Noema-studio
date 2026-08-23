## Project Storage

Project persistence is based on the ProjectStorage abstraction.

Current implementation:

- JsonProjectStorage

Responsibilities:

- Encode project
- Decode project
- Save project
- Load project

Storage implementations never contain business logic.
---

## Current Features

Implemented:

- Save Project
- Open Project
- JSON serialization
- JSON deserialization

Current storage implementation:

- JsonProjectStorage

Persistence flow:

NoemaProject
        ↓
toJson()
        ↓
JSON
        ↓
project.json
        ↓
fromJson()
        ↓
NoemaProject