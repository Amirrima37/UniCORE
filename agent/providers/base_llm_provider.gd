class_name BaseLLMProvider
extends Node

## Base LLM Provider for UniCORE Agent.
## Defines the contract, signals, and virtual methods for all LLM providers (Gemini, OpenAI, Ollama, etc.).

signal response_received(content: String)
signal request_failed(error_message: String)

## Virtual method to send a prompt to the LLM backend.
## Must be overridden by subclasses.
## [param system_prompt]: Instructions guiding LLM persona and output constraints.
## [param user_prompt]: Prompt text submitted by the user or agent orchestrator.
## [param api_key]: Authentication key for the provider API.
func send_prompt(system_prompt: String, user_prompt: String, api_key: String) -> void:
	push_error("BaseLLMProvider: send_prompt() is abstract and must be implemented by subclass.")
