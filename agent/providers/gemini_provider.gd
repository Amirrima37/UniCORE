class_name GeminiProvider
extends "res://agent/providers/base_llm_provider.gd"

## Google Gemini LLM Provider for UniCORE Agent.
## Communicates with the Google Gemini REST API using native Godot 4 HTTPRequest.

const DEFAULT_MODEL: String = "gemini-3.8-flash"
const API_URL_TEMPLATE: String = "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=%s"

@export var model: String = DEFAULT_MODEL
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
		_http_request.name = "GeminiHTTPRequest"
		add_child(_http_request)
		_http_request.request_completed.connect(_on_request_completed)
	
	_http_request.timeout = request_timeout
	return true


## Sends a prompt to the Google Gemini API.
## [param system_prompt]: Instructions guiding LLM persona and output constraints.
## [param user_prompt]: Prompt text submitted by the user or agent orchestrator.
## [param api_key]: Authentication key for Google Gemini API.
func send_prompt(system_prompt: String, user_prompt: String, api_key: String) -> void:
	if not is_inside_tree():
		request_failed.emit("GeminiProvider must be added to the scene tree before sending requests.")
		return
	
	_ensure_http_request()
	
	if _is_requesting:
		request_failed.emit("A request is already in progress.")
		return
	
	if api_key.strip_edges().is_empty():
		request_failed.emit("Gemini API key is empty.")
		return
	
	if user_prompt.strip_edges().is_empty():
		request_failed.emit("User prompt cannot be empty.")
		return
	
	var url: String = API_URL_TEMPLATE % [model.strip_edges(), api_key.strip_edges()]
	
	var payload: Dictionary = {
		"contents": [
			{
				"parts": [
					{"text": user_prompt}
				]
			}
		]
	}
	
	if not system_prompt.strip_edges().is_empty():
		payload["systemInstruction"] = {
			"parts": [
				{"text": system_prompt}
			]
		}
	
	var headers: PackedStringArray = [
		"Content-Type: application/json"
	]
	
	var json_payload: String = JSON.stringify(payload)
	_http_request.timeout = request_timeout
	var err: Error = _http_request.request(url, headers, HTTPClient.METHOD_POST, json_payload)
	if err != OK:
		_is_requesting = false
		request_failed.emit("Failed to send HTTP request (error code: %d)." % err)
		return
	
	_is_requesting = true


## Cancels any ongoing HTTP request.
func cancel_request() -> void:
	if is_instance_valid(_http_request) and _is_requesting:
		_http_request.cancel_request()
		_is_requesting = false


## Callback triggered when HTTPRequest completes.
func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_is_requesting = false
	
	if result != HTTPRequest.RESULT_SUCCESS:
		var result_msg: String = _get_http_result_message(result)
		request_failed.emit("HTTP request failed: %s (result code: %d)" % [result_msg, result])
		return
	
	var response_text: String = body.get_string_from_utf8()
	
	var json: JSON = JSON.new()
	var parse_err: Error = json.parse(response_text)
	if parse_err != OK:
		request_failed.emit("Failed to parse JSON response: %s (line %d)" % [json.get_error_message(), json.get_error_line()])
		return
	
	var data = json.data
	if not (data is Dictionary):
		request_failed.emit("Invalid JSON response format: expected a Dictionary.")
		return
	
	# Handle HTTP errors returned with response body (e.g. 400, 403, 404, 429, 500)
	if response_code != 200:
		var error_msg: String = "HTTP error %d" % response_code
		if data.has("error") and (data["error"] is Dictionary):
			var err_obj: Dictionary = data["error"]
			var status: String = err_obj.get("status", "UNKNOWN")
			var msg: String = err_obj.get("message", "No message provided")
			error_msg = "%s (%s): %s" % [error_msg, status, msg]
		request_failed.emit(error_msg)
		return
	
	# Check for top-level error in 200 OK body
	if data.has("error"):
		var err_dict = data["error"]
		var msg: String = str(err_dict)
		if err_dict is Dictionary and err_dict.has("message"):
			msg = str(err_dict["message"])
		request_failed.emit("Gemini API error: %s" % msg)
		return
	
	# Validate candidates array
	if not data.has("candidates") or not (data["candidates"] is Array) or data["candidates"].is_empty():
		request_failed.emit("Gemini response missing candidates.")
		return
	
	var first_candidate = data["candidates"][0]
	if not (first_candidate is Dictionary):
		request_failed.emit("Gemini candidate is malformed.")
		return
	
	# Check if generation was blocked by safety policy
	var finish_reason: String = str(first_candidate.get("finishReason", ""))
	if finish_reason in ["SAFETY", "RECITATION", "BLOCKLIST", "PROHIBITED_CONTENT"]:
		request_failed.emit("Generation blocked by Gemini safety policy (finishReason: %s)." % finish_reason)
		return
	
	# Validate content and parts
	if not first_candidate.has("content") or not (first_candidate["content"] is Dictionary):
		request_failed.emit("Gemini candidate missing content.")
		return
	
	var content: Dictionary = first_candidate["content"]
	if not content.has("parts") or not (content["parts"] is Array) or content["parts"].is_empty():
		request_failed.emit("Gemini candidate content missing parts.")
		return
	
	var first_part = content["parts"][0]
	if not (first_part is Dictionary) or not first_part.has("text"):
		request_failed.emit("Gemini response part missing text field.")
		return
	
	var raw_text: String = str(first_part["text"])
	var cleaned_text: String = clean_markdown_code_fences(raw_text)
	
	response_received.emit(cleaned_text)


## Cleans markdown code fences (```gdscript ... ``` or ``` ... ```) from the response text.
func clean_markdown_code_fences(text: String) -> String:
	var cleaned: String = text.strip_edges()
	
	# Case 1: Entire string is wrapped in code fences (e.g. ```gdscript\n...code...\n```)
	var full_wrap_regex: RegEx = RegEx.new()
	full_wrap_regex.compile("^```[a-zA-Z0-9_]*\\r?\\n([\\s\\S]*?)\\r?\\n```$")
	var match: RegExMatch = full_wrap_regex.search(cleaned)
	if match:
		return match.get_string(1).strip_edges()
	
	# Case 2: Embedded code block in conversational response (e.g. text before/after ```gdscript\n...code...\n```)
	var block_regex: RegEx = RegEx.new()
	block_regex.compile("```(?:gdscript|GDScript|gd)?[ \\t]*\\r?\\n([\\s\\S]*?)\\r?\\n```")
	var block_match: RegExMatch = block_regex.search(cleaned)
	if block_match:
		return block_match.get_string(1).strip_edges()
	
	# Case 3: Single-line or no newline fences: ```code```
	if cleaned.begins_with("```") and cleaned.ends_with("```") and cleaned.length() >= 6:
		cleaned = cleaned.substr(3, cleaned.length() - 6).strip_edges()
		if cleaned.to_lower().begins_with("gdscript"):
			cleaned = cleaned.substr(8).strip_edges()
		return cleaned
	
	return cleaned


## Translates HTTPRequest result enum to human-readable string.
func _get_http_result_message(result: int) -> String:
	match result:
		HTTPRequest.RESULT_SUCCESS:
			return "Success"
		HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH:
			return "Chunked body size mismatch"
		HTTPRequest.RESULT_CANT_CONNECT:
			return "Cannot connect to host"
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "Cannot resolve hostname"
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "Connection error"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "TLS handshake error"
		HTTPRequest.RESULT_NO_RESPONSE:
			return "No response from server"
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
			return "Body size limit exceeded"
		HTTPRequest.RESULT_REQUEST_FAILED:
			return "Request failed"
		HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN:
			return "Cannot open download file"
		HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
			return "Download file write error"
		HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED:
			return "Redirect limit reached"
		HTTPRequest.RESULT_TIMEOUT:
			return "Request timeout"
		_:
			return "Unknown HTTP error (%d)" % result
