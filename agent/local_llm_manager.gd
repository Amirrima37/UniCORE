class_name LocalLLMServerManager
extends Node

## Manages the local embedded llama-server process and model lifecycle for UniCORE Phase 3c.
## Handles downloading server binaries and GGUF models, launching the subprocess,
## monitoring server health via HTTP endpoints, and graceful process termination.

signal server_started(port: int, pid: int)
signal server_stopped()
signal server_error(error_message: String)
signal health_checked(is_healthy: bool)
signal download_started(item_name: String)
signal download_progress(item_name: String, bytes_received: int, total_bytes: int, percent: float)
signal download_completed(item_name: String, target_path: String)
signal download_failed(item_name: String, error_message: String)
signal status_changed(new_status: String)

const STATUS_STOPPED: String = "stopped"
const STATUS_DOWNLOADING: String = "downloading"
const STATUS_STARTING: String = "starting"
const STATUS_RUNNING: String = "running"
const STATUS_ERROR: String = "error"

const DEFAULT_PORT: int = 8080
const DEFAULT_CONTEXT_SIZE: int = 4096
const DEFAULT_THREADS: int = 4
const DEFAULT_MODEL_FILENAME: String = "qwen2.5-coder-1.5b-instruct-q4_k_m.gguf"
const DEFAULT_SERVER_BINARY: String = "llama-server.exe"

# Official stable download URLs (Windows x64 and HuggingFace GGUF)
const DEFAULT_BINARY_URL: String = "https://github.com/ggerganov/llama.cpp/releases/latest/download/llama-b3560-bin-win-avx2-x64.zip"
const DEFAULT_MODEL_URL: String = "https://huggingface.co/Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF/resolve/main/qwen2.5-coder-1.5b-instruct-q4_k_m.gguf"

const MAX_HEALTH_CHECK_ATTEMPTS: int = 30

var _status: String = STATUS_STOPPED
var _server_pid: int = -1
var _server_port: int = DEFAULT_PORT
var _custom_model_path: String = ""
var _http_health: HTTPRequest = null
var _http_downloader: HTTPRequest = null
var _is_downloading: bool = false
var _current_download_item: String = ""
var _current_target_file: String = ""
var _health_timer: Timer = null

var _download_queue: Array[Dictionary] = []
var _pending_start_after_download: bool = false
var _pending_port: int = DEFAULT_PORT
var _pending_threads: int = DEFAULT_THREADS
var _pending_ctx_size: int = DEFAULT_CONTEXT_SIZE
var _health_check_attempts: int = 0


func _ready() -> void:
	set_process(false)
	_ensure_nodes()


func _exit_tree() -> void:
	stop_server()
	cancel_downloads()


func _process(_delta: float) -> void:
	if _is_downloading and is_instance_valid(_http_downloader):
		var downloaded: int = _http_downloader.get_downloaded_bytes()
		var total: int = _http_downloader.get_body_size()
		var percent: float = 0.0
		if total > 0:
			percent = clampf((float(downloaded) / float(total)) * 100.0, 0.0, 100.0)
		download_progress.emit(_current_download_item, downloaded, total, percent)


func setup(port: int = DEFAULT_PORT) -> void:
	_server_port = port
	_ensure_nodes()


func is_server_running() -> bool:
	return _server_pid > 0 and _status == STATUS_RUNNING


func is_downloading() -> bool:
	return _is_downloading


func get_status() -> String:
	return _status


func get_server_port() -> int:
	return _server_port


func set_custom_model_path(path: String) -> void:
	_custom_model_path = path


func get_custom_model_path() -> String:
	return _custom_model_path


func get_resolved_binary_path() -> String:
	var candidate_paths: Array[String] = [
		"user://bin/" + DEFAULT_SERVER_BINARY,
		"res://bin/" + DEFAULT_SERVER_BINARY,
		"bin/" + DEFAULT_SERVER_BINARY
	]

	for candidate in candidate_paths:
		if FileAccess.file_exists(candidate):
			return ProjectSettings.globalize_path(candidate)
		var global_cand: String = ProjectSettings.globalize_path(candidate)
		if FileAccess.file_exists(global_cand):
			return global_cand

	return ""


func get_resolved_model_path() -> String:
	if not _custom_model_path.strip_edges().is_empty():
		if FileAccess.file_exists(_custom_model_path):
			return ProjectSettings.globalize_path(_custom_model_path)
		var global_custom: String = ProjectSettings.globalize_path(_custom_model_path)
		if FileAccess.file_exists(global_custom):
			return global_custom

	var default_user_path: String = "user://models/" + DEFAULT_MODEL_FILENAME
	if FileAccess.file_exists(default_user_path):
		return ProjectSettings.globalize_path(default_user_path)
	var global_default_user: String = ProjectSettings.globalize_path(default_user_path)
	if FileAccess.file_exists(global_default_user):
		return global_default_user

	var default_res_path: String = "res://models/" + DEFAULT_MODEL_FILENAME
	if FileAccess.file_exists(default_res_path):
		return ProjectSettings.globalize_path(default_res_path)

	return ""


func start_server(port: int = DEFAULT_PORT, threads: int = DEFAULT_THREADS, ctx_size: int = DEFAULT_CONTEXT_SIZE) -> bool:
	if is_server_running():
		return true

	var binary_path: String = get_resolved_binary_path()
	var model_path: String = get_resolved_model_path()

	if binary_path.is_empty() or model_path.is_empty():
		_pending_start_after_download = true
		_pending_port = port
		_pending_threads = threads
		_pending_ctx_size = ctx_size
		_set_status(STATUS_DOWNLOADING)
		ensure_binaries_and_model()
		return false

	var args: PackedStringArray = PackedStringArray([
		"-m", model_path,
		"--port", str(port),
		"-c", str(ctx_size),
		"-t", str(threads),
		"--nobrowser"
	])

	var pid: int = OS.create_process(binary_path, args, false)
	if pid <= 0:
		_set_status(STATUS_ERROR)
		server_error.emit("Failed to create llama-server process")
		return false

	_server_pid = pid
	_server_port = port
	_set_status(STATUS_STARTING)
	_health_check_attempts = 0

	_ensure_nodes()
	if is_instance_valid(_health_timer):
		_health_timer.wait_time = 1.0
		_health_timer.start()

	check_health()
	return true


func stop_server() -> void:
	if is_instance_valid(_health_timer):
		_health_timer.stop()

	if is_instance_valid(_http_health) and _http_health.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_http_health.cancel_request()

	if _server_pid > 0:
		OS.kill(_server_pid)
		_server_pid = -1

	_set_status(STATUS_STOPPED)
	server_stopped.emit()


func check_health() -> void:
	if not is_inside_tree():
		health_checked.emit(false)
		return

	_ensure_nodes()
	var url: String = "http://127.0.0.1:%d/health" % _server_port
	if _http_health.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_http_health.cancel_request()

	var err: Error = _http_health.request(url)
	if err != OK:
		health_checked.emit(false)


func ensure_binaries_and_model(model_url: String = "", bin_url: String = "") -> void:
	DirAccess.make_dir_recursive_absolute("user://bin")
	DirAccess.make_dir_recursive_absolute("user://models")

	var effective_model_url: String = model_url.strip_edges()
	if effective_model_url.is_empty():
		effective_model_url = DEFAULT_MODEL_URL

	var effective_bin_url: String = bin_url.strip_edges()
	if effective_bin_url.is_empty():
		effective_bin_url = DEFAULT_BINARY_URL

	var need_model: bool = get_resolved_model_path().is_empty()
	var need_binary: bool = get_resolved_binary_path().is_empty()

	if not need_model and not need_binary:
		if _pending_start_after_download:
			_pending_start_after_download = false
			start_server(_pending_port, _pending_threads, _pending_ctx_size)
		return

	_download_queue.clear()

	if need_model:
		_download_queue.append({
			"item_name": "model",
			"url": effective_model_url,
			"target_path": "user://models/" + DEFAULT_MODEL_FILENAME,
			"is_archive": false
		})

	if need_binary:
		var bin_filename: String = effective_bin_url.get_file()
		if bin_filename.is_empty():
			bin_filename = "llama-server-dist.zip"
		var is_zip: bool = bin_filename.ends_with(".zip")
		_download_queue.append({
			"item_name": "binary",
			"url": effective_bin_url,
			"target_path": "user://bin/" + bin_filename,
			"is_archive": is_zip
		})

	if not _is_downloading:
		_process_next_download()


func download_model_from_url(url: String, filename: String) -> void:
	DirAccess.make_dir_recursive_absolute("user://models")
	var target_name: String = filename.strip_edges()
	if target_name.is_empty():
		target_name = DEFAULT_MODEL_FILENAME

	var target_path: String = "user://models/" + target_name
	var item: Dictionary = {
		"item_name": target_name,
		"url": url.strip_edges(),
		"target_path": target_path,
		"is_archive": target_name.ends_with(".zip")
	}

	_download_queue.append(item)
	if not _is_downloading:
		_process_next_download()


func cancel_downloads() -> void:
	if _is_downloading and is_instance_valid(_http_downloader):
		_http_downloader.cancel_request()

	_is_downloading = false
	set_process(false)
	_download_queue.clear()
	_pending_start_after_download = false
	_current_download_item = ""
	_current_target_file = ""

	if _status == STATUS_DOWNLOADING:
		_set_status(STATUS_STOPPED)


func _set_status(new_status: String) -> void:
	if _status != new_status:
		_status = new_status
		status_changed.emit(_status)


func _ensure_nodes() -> void:
	if not is_instance_valid(_http_health):
		_http_health = HTTPRequest.new()
		_http_health.name = "HealthHTTPRequest"
		_http_health.timeout = 5.0
		add_child(_http_health)
		_http_health.request_completed.connect(_on_health_request_completed)

	if not is_instance_valid(_http_downloader):
		_http_downloader = HTTPRequest.new()
		_http_downloader.name = "DownloaderHTTPRequest"
		_http_downloader.timeout = 0.0
		_http_downloader.max_redirects = 8
		add_child(_http_downloader)
		_http_downloader.request_completed.connect(_on_download_request_completed)

	if not is_instance_valid(_health_timer):
		_health_timer = Timer.new()
		_health_timer.name = "HealthCheckTimer"
		_health_timer.wait_time = 1.0
		_health_timer.one_shot = false
		add_child(_health_timer)
		_health_timer.timeout.connect(_on_health_timer_timeout)


func _process_next_download() -> void:
	if _download_queue.is_empty():
		return

	var item: Dictionary = _download_queue.pop_front()
	_current_download_item = str(item.get("item_name", ""))
	var url: String = str(item.get("url", ""))
	_current_target_file = str(item.get("target_path", ""))

	_ensure_nodes()

	var dir_path: String = _current_target_file.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)

	_http_downloader.download_file = ProjectSettings.globalize_path(_current_target_file)
	_is_downloading = true
	set_process(true)
	_set_status(STATUS_DOWNLOADING)
	download_started.emit(_current_download_item)

	var err: Error = _http_downloader.request(url)
	if err != OK:
		_on_download_failed_internal("HTTPRequest.request failed with code: %d" % err)


func _on_download_failed_internal(err_msg: String) -> void:
	_is_downloading = false
	set_process(false)
	_set_status(STATUS_ERROR)
	download_failed.emit(_current_download_item, err_msg)
	_download_queue.clear()
	_pending_start_after_download = false
	_current_download_item = ""
	_current_target_file = ""


func _on_download_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_on_download_failed_internal("Download failed for '%s' with result code: %d" % [_current_download_item, result])
		return

	if response_code < 200 or response_code >= 300:
		_on_download_failed_internal("Download failed for '%s' with HTTP status: %d" % [_current_download_item, response_code])
		return

	var target_path: String = _current_target_file
	var item_name: String = _current_download_item

	if target_path.ends_with(".zip"):
		var extract_err: Error = _extract_zip(target_path, "user://bin/")
		if extract_err != OK:
			_on_download_failed_internal("Failed to extract archive '%s' (error code: %d)" % [target_path, extract_err])
			return

	download_completed.emit(item_name, target_path)

	if not _download_queue.is_empty():
		_process_next_download()
	else:
		_is_downloading = false
		set_process(false)
		_current_download_item = ""
		_current_target_file = ""
		_set_status(STATUS_STOPPED)
		if _pending_start_after_download:
			_pending_start_after_download = false
			start_server(_pending_port, _pending_threads, _pending_ctx_size)


func _extract_zip(zip_path: String, destination_folder: String) -> Error:
	var reader: ZIPReader = ZIPReader.new()
	var open_err: Error = reader.open(ProjectSettings.globalize_path(zip_path))
	if open_err != OK:
		open_err = reader.open(zip_path)
		if open_err != OK:
			return open_err

	DirAccess.make_dir_recursive_absolute(destination_folder)
	var files: PackedStringArray = reader.get_files()

	for fpath in files:
		if fpath.ends_with("/"):
			DirAccess.make_dir_recursive_absolute(destination_folder.path_join(fpath))
			continue

		var file_data: PackedByteArray = reader.read_file(fpath)
		var base_name: String = fpath.get_file()
		if base_name.is_empty():
			continue

		var out_path: String = destination_folder.path_join(base_name)
		var out_file: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
		if out_file != null:
			out_file.store_buffer(file_data)
			out_file.close()

	reader.close()
	return OK


func _on_health_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	var is_ok: bool = (result == HTTPRequest.RESULT_SUCCESS and response_code == 200)
	if is_ok:
		if _status == STATUS_STARTING:
			_set_status(STATUS_RUNNING)
			server_started.emit(_server_port, _server_pid)
		health_checked.emit(true)
	else:
		health_checked.emit(false)


func _on_health_timer_timeout() -> void:
	if _server_pid > 0 and not OS.is_process_running(_server_pid):
		_server_pid = -1
		if is_instance_valid(_health_timer):
			_health_timer.stop()

		if _status == STATUS_STARTING:
			_set_status(STATUS_ERROR)
			server_error.emit("llama-server process exited unexpectedly during startup.")
		else:
			_set_status(STATUS_STOPPED)
			server_stopped.emit()
		return

	if _status == STATUS_STARTING:
		_health_check_attempts += 1
		if _health_check_attempts > MAX_HEALTH_CHECK_ATTEMPTS:
			if is_instance_valid(_health_timer):
				_health_timer.stop()
			_set_status(STATUS_ERROR)
			server_error.emit("llama-server failed to respond to health check within timeout.")
			stop_server()
			return
		check_health()
	elif _status == STATUS_RUNNING:
		check_health()
