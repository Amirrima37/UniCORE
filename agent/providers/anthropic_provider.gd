class_name AnthropicProvider
extends "res://agent/providers/base_llm_provider.gd"

## Провайдер Anthropic Claude API (Messages API)
## Работает через endpoint https://api.anthropic.com/v1/messages

const DEFAULT_API_URL: String = "https://api.anthropic.com/v1/messages"
const ANTHROPIC_VERSION: String = "2023-06-01"

@export var base_url: String = DEFAULT_API_URL
@export var model: String = "claude-3-5-sonnet-20241022"
@export var request_timeout: float = 60.0
@export var max_tokens: int = 4096

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
		_http_request.name = "AnthropicHTTPRequest"
		add_child(_http_request)
		_http_request.request_completed.connect(_on_request_completed)

	_http_request.timeout = request_timeout
	return true


func send_prompt(system_prompt: String, user_prompt: String, api_key: String) -> void:
	if not is_inside_tree():
		request_failed.emit("AnthropicProvider must be in scene tree.")
		return

	_ensure_http_request()

	if _is_requesting:
		request_failed.emit("A request is already in progress.")
		return

	var trimmed_key: String = api_key.strip_edges()
	if trimmed_key.is_empty():
		request_failed.emit("API key is empty.")
		return

	var trimmed_prompt: String = user_prompt.strip_edges()
	if trimmed_prompt.is_empty():
		request_failed.emit("Prompt cannot be empty.")
		return

	var messages: Array = [
		{
			"role": "user",
			"content": user_prompt
		}
	]

	var payload: Dictionary = {
		"model": model.strip_edges(),
		"max_tokens": max_tokens,
		"messages": messages
	}

	var trimmed_system: String = system_prompt.strip_edges()
	if not trimmed_system.is_empty():
		payload["system"] = system_prompt

	var headers: PackedStringArray = [
		"x-api-key: %s" % trimmed_key,
		"anthropic-version: %s" % ANTHROPIC_VERSION,
		"content-type: application/json"
	]

	var json_payload: String = JSON.stringify(payload)
	_http_request.timeout = request_timeout
	var target_url: String = base_url.strip_edges()
	if target_url.is_empty():
		target_url = DEFAULT_API_URL

	var err: Error = _http_request.request(target_url, headers, HTTPClient.METHOD_POST, json_payload)
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
			var err_obj = data_dict["error"]
			if err_obj is Dictionary and (err_obj as Dictionary).has("message"):
				err_msg += ": %s" % str((err_obj as Dictionary)["message"])
			else:
				err_msg += ": %s" % str(err_obj)
		request_failed.emit(err_msg)
		return

	if not data_dict.has("content") or not (data_dict["content"] is Array) or (data_dict["content"] as Array).is_empty():
		request_failed.emit("Anthropic response missing 'content' array")
		return

	var content_array: Array = data_dict["content"]
	var extracted_text: String = ""
	var found_text_block: bool = false

	for item in content_array:
		if item is Dictionary:
			var block: Dictionary = item
			if str(block.get("type", "")) == "text" and block.has("text"):
				extracted_text = str(block.get("text", ""))
				found_text_block = true
				break

	if not found_text_block:
		request_failed.emit("No text block found in Anthropic response content")
		return

	var cleaned: String = _clean_fences(extracted_text)
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
