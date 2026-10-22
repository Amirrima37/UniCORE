class_name OpenAICompatibleProvider
extends "res://agent/providers/base_llm_provider.gd"

## Универсальный провайдер OpenAI-совместимого API (OpenAI, OpenRouter, Groq, DeepSeek, LocalAI, vLLM)
## Работает через стандартный endpoint /v1/chat/completions с заголовком Authorization: Bearer <KEY>

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

func send_prompt(system_prompt: String, user_prompt: String, api_key: String) -> void:
	if not is_inside_tree():
		request_failed.emit("OpenAICompatibleProvider must be in scene tree.")
		return

	_ensure_http_request()

	if _is_requesting:
		request_failed.emit("A request is already in progress.")
		return

	if api_key.strip_edges().is_empty():
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
		"Authorization: Bearer %s" % api_key.strip_edges(),
		"HTTP-Referer: https://unicore.dev",
		"X-Title: UniCORE Engine"
	]

	var json_payload: String = JSON.stringify(payload)
	_http_request.timeout = request_timeout
	var err: Error = _http_request.request(base_url.strip_edges(), headers, HTTPClient.METHOD_POST, json_payload)
	if err != OK:
		_is_requesting = false
		request_failed.emit("Failed to send HTTP request (code: %d)." % err)
		return

	_is_requesting = true

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

	if response_code != 200:
		var err_msg = "HTTP %d" % response_code
		if data.has("error"):
			if data["error"] is Dictionary and data["error"].has("message"):
				err_msg += ": %s" % data["error"]["message"]
			else:
				err_msg += ": %s" % str(data["error"])
		request_failed.emit(err_msg)
		return

	if not data.has("choices") or not (data["choices"] is Array) or data["choices"].is_empty():
		request_failed.emit("No choices returned from LLM")
		return

	var choice = data["choices"][0]
	if not choice.has("message") or not (choice["message"] is Dictionary):
		request_failed.emit("Malformed choice structure")
		return

	var raw_content: String = str(choice["message"].get("content", ""))
	var cleaned = _clean_fences(raw_content)
	response_received.emit(cleaned)

func _clean_fences(text: String) -> String:
	var cleaned: String = text.strip_edges()
	var block_regex: RegEx = RegEx.new()
	block_regex.compile("```(?:gdscript|GDScript|gd)?[ \\t]*\\r?\\n([\\s\\S]*?)\\r?\\n```")
	var block_match: RegExMatch = block_regex.search(cleaned)
	if block_match:
		return block_match.get_string(1).strip_edges()

	if cleaned.begins_with("```") and cleaned.ends_with("```") and cleaned.length() >= 6:
		var start := cleaned.find("\n")
		var end := cleaned.rfind("```")
		if start != -1 and end > start:
			return cleaned.substr(start + 1, end - start - 1).strip_edges()

	return cleaned
