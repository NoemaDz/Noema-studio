# Noema Glossary

---

## Bootstrap

The composition root of the application.

Responsible for creating and wiring dependencies.

---

## Builder

A component responsible for constructing prompts or intermediate objects.

Builders contain no business logic and perform no network communication.

---

## Driver

A low-level adapter responsible for communicating with external systems.

Examples:

* OllamaDriver
* ComfyUIDriver

Drivers never contain business logic.

---

## External System

Any system outside Noema.

Examples:

* Ollama
* ComfyUI
* Local File System

---

## Infrastructure

The layer responsible for integrating external systems.

Contains Drivers, Providers, and technology-specific implementations.

---

## Job

An asynchronous operation executed by an external AI engine.

Examples:

* Image generation
* Video rendering

---

## Model

A pure data object.

Models contain no business logic.

---

## Noema

The public SDK entry point.

Acts as the Facade of the system.

---

## Project

The root object representing an AI production project.

Contains story, assets, jobs, characters, and workflow state.

---

## Provider

The abstraction layer used by workflows.

Providers expose capabilities while hiding implementation details.

Examples:

* LLMProvider
* ImageProvider

---

## Repository

A persistence abstraction responsible for loading and saving domain data.

Repositories never communicate directly with AI engines.

---

## Workflow

A business use-case executed by the Workflow Engine.

Examples:

* Story generation
* Character extraction
* Image generation

A Workflow coordinates Providers.

---

## Workflow Engine

The execution engine responsible for running workflows.

It manages execution context and step sequencing.

---

## Workflow Step

A single executable unit inside a workflow.

Each step has one responsibility.

---

## Workflow Context

A shared state object passed between workflow steps.
