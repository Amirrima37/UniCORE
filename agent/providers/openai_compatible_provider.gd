class_name OpenAICompatibleProvider
extends "res://agent/providers/base_llm_provider.gd"

## Универсальный провайдер OpenAI-совместимого API (OpenAI, OpenRouter, DeepSeek, Groq, Mistral, LocalAI, vLLM)
## Работает через стандартный endpoint /v1/chat/completions

const PRESET_OPENAI: String = "openai"
const PRESET_OPENROUTER: String = "openrouter"
const PRESET_DEEPSEEK: String = "deepseek"
const PRESET_GROQ: String = "groq"
const PRESET_MISTRAL: String = "mistral"
const PRESET_LOCAL_EMBEDDED: String = "local_embedded"
const PRESET_CUSTOM: String = "custom"

@export var current_preset: String = PRESET_OPENROUTER
@export var base_url: String = "https://openrouter.ai/api/v1/chat/completions"
@export var model: String = "google/gemini-2.5-flash"
@export var request_timeout: float = 60.0

var _http_request: HTTPRequest = null
var _is_requesting: bool = false


func _ready() -> void:
	_ensure_http_request()


func _ensure_http_request() -> bool:
	if is_instance_valid(_http_request) and _http_request.is_inside_tree():
		return true

	if not is_inside_tree():
		return false

	if not is_instance_valid(_http_request):
		_http_request = HTTPRequest.new()
		_http_request.name = "OpenAIHTTPRequest"
		add_child(_http_request)
		_http_request.request_completed.connect(_on_request_completed)

	_http_request.timeout = request_timeout
	return true


func get_supported_presets() -> Array[String]:
	var presets: Array[String] = [
		PRESET_OPENAI,
		PRESET_OPENROUTER,
		PRESET_DEEPSEEK,
		PRESET_GROQ,
		PRESET_MISTRAL,
		PRESET_LOCAL_EMBEDDED,
		PRESET_CUSTOM
	]
	return presets


func get_preset_default_model(preset_name: String) -> String:
	var norm: String = _normalize_preset_name(preset_name)
	match norm:
		PRESET_OPENAI:
			return "gpt-4o-mini"
		PRESET_OPENROUTER:
			return "google/gemini-2.5-flash"
		PRESET_DEEPSEEK:
			return "deepseek-chat"
		PRESET_GROQ:
			return "llama-3.3-70b-versatile"
		PRESET_MISTRAL:
			return "codestral-latest"
		PRESET_LOCAL_EMBEDDED:
			return "default"
		PRESET_CUSTOM:
			return ""
		_:
			return ""


func get_preset_default_url(preset_name: String) -> String:
	var norm: String = _normalize_preset_name(preset_name)
	match norm:
		PRESET_OPENAI:
			return "https://api.openai.com/v1/chat/completions"
		PRESET_OPENROUTER:
			return "https://openrouter.ai/api/v1/chat/completions"
		PRESET_DEEPSEEK:
			return "https://api.deepseek.com/chat/completions"
		PRESET_GROQ:
			return "https://api.groq.com/openai/v1/chat/completions"
		PRESET_MISTRAL:
			return "https://api.mistral.ai/v1/chat/completions"
		PRESET_LOCAL_EMBEDDED:
			return "http://127.0.0.1:8080/v1/chat/completions"
		PRESET_CUSTOM:
			return ""
		_:
			return ""


func configure_preset(preset_name: String, custom_model: String = "", custom_base_url: String = "") -> void:
	var norm: String = _normalize_preset_name(preset_name)
	current_preset = norm

	var def_url: String = get_preset_default_url(norm)
	var def_model: String = get_preset_default_model(norm)

	if not def_url.is_empty():
		base_url = def_url
	if not def_model.is_empty():
		model = def_model

	if not custom_base_url.strip_edges().is_empty():
		base_url = custom_base_url.strip_edges()
	if not custom_model.strip_edges().is_empty():
		model = custom_model.strip_edges()


func is_local_endpoint() -> bool:
	if current_preset == PRESET_LOCAL_EMBEDDED:
		return true
	var url_lower: String = base_url.to_lower()
	return url_lower.contains("127.0.0.1") or url_lower.contains("localhost")


func send_prompt(system_prompt: String, user_prompt: String, api_key: String) -> void:
	if not is_inside_tree():
		request_failed.emit("OpenAICompatibleProvider must be in scene tree.")
		return

	_ensure_http_request()

	if _is_requesting:
		request_failed.emit("A request is already in progress.")
		return

	var is_local: bool = is_local_endpoint()
	var trimmed_key: String = api_key.strip_edges()

	if not is_local and trimmed_key.is_empty():
		request_failed.emit("API key is empty.")
		return

	if user_prompt.strip_edges().is_empty():
		request_failed.emit("Prompt cannot be empty.")
		return

	var messages: Array = []
	if not system_prompt.strip_edges().is_empty():
		messages.append({
			"role": "system",
			"content": system_prompt
		})
	messages.append({
		"role": "user",
		"content": user_prompt
	})

	var payload: Dictionary = {
		"model": model.strip_edges(),
		"messages": messages,
		"temperature": 0.2
	}

	var headers: PackedStringArray = [
		"Content-Type: application/json",
		"HTTP-Referer: https://unicore.dev",
		"X-Title: UniCORE Engine"
	]

	if not trimmed_key.is_empty():
		headers.append("Authorization: Bearer %s" % trimmed_key)
	elif is_local:
		headers.append("Authorization: Bearer local")

	var json_payload: String = JSON.stringify(payload)
	_http_request.timeout = request_timeout
	var err: Error = _http_request.request(base_url.strip_edges(), headers, HTTPClient.METHOD_POST, json_payload)
	if err != OK:
		_is_requesting = false
		request_failed.emit("Failed to send HTTP request (code: %d)." % err)
		return

	_is_requesting = true


func cancel_request() -> void:
	if is_instance_valid(_http_request) and _is_requesting:
		_http_request.cancel_request()
		_is_requesting = false


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_is_requesting = false

	if result != HTTPRequest.RESULT_SUCCESS:
		request_failed.emit("HTTP request failed (code: %d)" % result)
		return

	var response_text: String = body.get_string_from_utf8()
	var json: JSON = JSON.new()
	var parse_err: Error = json.parse(response_text)
	if parse_err != OK:
		request_failed.emit("Failed to parse JSON response: %s" % json.get_error_message())
		return

	var data = json.data
	if not (data is Dictionary):
		request_failed.emit("Expected Dictionary in response")
		return

	var data_dict: Dictionary = data
	if response_code != 200:
		var err_msg: String = "HTTP %d" % response_code
		if data_dict.has("error"):
			if data_dict["error"] is Dictionary and (data_dict["error"] as Dictionary).has("message"):
				err_msg += ": %s" % str((data_dict["error"] as Dictionary)["message"])
			else:
				err_msg += ": %s" % str(data_dict["error"])
		request_failed.emit(err_msg)
		return

	if not data_dict.has("choices") or not (data_dict["choices"] is Array) or (data_dict["choices"] as Array).is_empty():
		request_failed.emit("No choices returned from LLM")
		return

	var choices_array: Array = data_dict["choices"]
	var choice = choices_array[0]
	if not (choice is Dictionary) or not (choice as Dictionary).has("message") or not ((choice as Dictionary)["message"] is Dictionary):
		request_failed.emit("Malformed choice structure")
		return

	var choice_dict: Dictionary = choice
	var message_dict: Dictionary = choice_dict["message"]
	var raw_content: String = str(message_dict.get("content", ""))
	var cleaned: String = _clean_fences(raw_content)
	response_received.emit(cleaned)


func _clean_fences(text: String) -> String:
	var cleaned: String = text.strip_edges()
	var block_regex: RegEx = RegEx.new()
	block_regex.compile("```(?:gdscript|GDScript|gd)?[ \\t]*\\r?\\n([\\s\\S]*?)\\r?\\n```")
	var block_match: RegExMatch = block_regex.search(cleaned)
	if block_match:
		return block_match.get_string(1).strip_edges()

	if cleaned.begins_with("```") and cleaned.ends_with("```") and cleaned.length() >= 6:
		var start: int = cleaned.find("\n")
		var end: int = cleaned.rfind("```")
		if start != -1 and end > start:
			return cleaned.substr(start + 1, end - start - 1).strip_edges()

	return cleaned


func _normalize_preset_name(preset_name: String) -> String:
	var norm: String = preset_name.strip_edges().to_lower()
	if norm.begins_with("preset_"):
		norm = norm.substr(7)
	if norm == "local":
		norm = PRESET_LOCAL_EMBEDDED
	return norm
