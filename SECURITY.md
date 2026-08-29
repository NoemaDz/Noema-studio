# Security Policy

## Overview
Noema Studio is an open-source, AI-native multimedia production studio built for local-first execution. Security and data privacy are core design principles of Noema Studio.

## Credential & Data Security
- **Local-First Processing:** Noema Studio connects directly to your local ComfyUI, Ollama, and FFmpeg instances on your machine. Project files, generated audio, and video assets remain stored exclusively on your local disk (`ApplicationSupportDirectory/noema`).
- **Cloud API Keys:** When using optional cloud providers (such as OpenAI for LLM or TTS), API keys are used solely for direct HTTPS connections to provider endpoints and are never transmitted to third-party tracking servers.

## Network Security
- All external API calls to Cloud AI Providers (OpenAI, Sora, Runway, etc.) enforce strict `HTTPS` with TLS validation.
- Local service endpoints (`ComfyUI` on port `8188`, `Ollama` on port `11434`) operate strictly over loopback interfaces (`127.0.0.1` / `localhost`).

## Reporting Vulnerabilities
If you discover a security vulnerability or security bug in Noema Studio:

1. **Do not** report security vulnerabilities through public GitHub issues.
2. Send an email describing the issue, impact, and reproduction steps directly to the maintainers at **security@noemastudio.ai** or open a confidential security advisory on GitHub.
3. You will receive a response within 48 hours acknowledging receipt of your report.

## Supported Versions
We provide security updates for the following active releases:

| Version | Supported |
| --- | --- |
| 1.0.0-RC1 (Current) | :white_check_mark: |
| < 1.0.0-Beta | :x: |
