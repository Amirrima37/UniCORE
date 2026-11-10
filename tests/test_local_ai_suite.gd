extends SceneTree

## Всесторонний интеграционный тестовый сьют для встроенного Локального ИИ и провайдеров (Фаза 3c).

const LocalLLMServerManagerScript = preload("res://agent/local_llm_manager.gd")
const AnthropicProviderScript = preload("res://agent/providers/anthropic_provider.gd")
const OpenAICompatibleProviderScript = preload("res://agent/providers/openai_compatible_provider.gd")

var passed_count: int = 0
var failed_count: int = 0

var _mock_server: TCPServer = null
var _mock_port: int = 18088
var _mock_running: bool = false
var _active_clients: Array[StreamPeerTCP] = []
var _step: int = 0
var _timer: float = 0.0

var _settings_manager: SettingsManager = null
var _event_bus: EventBus = null
var _module_manager: ModuleManager = null
var _agent_brain: AgentBrain = null
var _local_provider: Node = null
var _local_manager: Node = null
var _root_node: Node = null
var _generation_completed: bool = false

func assert_true(condition: bool, test_name: String, error_msg: String = "") -> void:
	if condition:
		print("  [PASS] %s" % test_name)
		passed_count += 1
	else:
		print("  [FAIL] %s - %s" % [test_name, error_msg])
		failed_count += 1

func assert_false(condition: bool, test_name: String, error_msg: String = "") -> void:
	assert_true(not condition, test_name, error_msg)

func assert_eq(a: Variant, b: Variant, test_name: String) -> void:
	if a == b:
		print("  [PASS] %s" % test_name)
		passed_count += 1
	else:
		print("  [FAIL] %s: Expected '%s', got '%s'" % [test_name, str(b), str(a)])
		failed_count += 1

func _init() -> void:
	print("==================================================")
	print("Запуск комплексного теста встроенного Локального ИИ")
	print("==================================================")

func _process(delta: float) -> bool:
	_timer += delta
	_poll_mock_server()

	match _step:
		0:
			_run_sync_tests()
			_start_mock_llama_server()
			_step = 1
			_timer = 0.0

		1:
			if _timer > 0.3:
				_test_local_server_health_and_query()
				_step = 2
				_timer = 0.0

		2:
			if _generation_completed or _timer > 5.0:
				_finish_suite()
				return true

	return false

func _run_sync_tests() -> void:
	print("\n--- 1. Тестирование SettingsManager и модели данных ---")
	_event_bus = EventBus.new()
	_settings_manager = SettingsManager.new()
	_settings_manager.setup(_event_bus)

	var def_agent: Dictionary = SettingsManager.DEFAULT_SETTINGS.get("agent", {})
	assert_eq(def_agent.get("provider", ""), "local_embedded", "Константа DEFAULT_SETTINGS: провайдер по умолчанию - local_embedded")
	assert_true(def_agent.get("auto_fallback_to_local", false), "Константа DEFAULT_SETTINGS: auto-fallback включен")
	assert_eq(def_agent.get("local_server_port", 0), 8080, "Константа DEFAULT_SETTINGS: порт локального сервера 8080")

	_settings_manager.set_agent_provider("local_embedded")
	assert_eq(_settings_manager.get_agent_provider(), "local_embedded", "Активный провайдер переключен на local_embedded")
	assert_true(_settings_manager.is_auto_fallback_to_local_enabled(), "Auto-fallback на локальную модель активен")

	var prov_info: Dictionary = _settings_manager.get_active_provider_info()
	assert_eq(prov_info.get("provider", ""), "local_embedded", "get_active_provider_info возвращает local_embedded")

	_settings_manager.set_agent_api_key("anthropic", "sk-ant-test-key-12345")
	assert_eq(_settings_manager.get_agent_api_key("anthropic"), "sk-ant-test-key-12345", "Изолированное сохранение ключа Anthropic")
	_settings_manager.set_agent_api_key("groq", "gsk_test_key_67890")
	assert_eq(_settings_manager.get_agent_api_key("groq"), "gsk_test_key_67890", "Изолированное сохранение ключа Groq")

	print("\n--- 2. Тестирование OpenAICompatibleProvider для локального ИИ ---")
	_local_provider = OpenAICompatibleProviderScript.new()
	_local_provider.configure_preset("local_embedded")
	assert_true(_local_provider.is_local_endpoint(), "is_local_endpoint определяет локальный адрес 127.0.0.1:8080")
	assert_eq(_local_provider.base_url, "http://127.0.0.1:8080/v1/chat/completions", "Базовый URL локального сервера")

	print("\n--- 3. Тестирование менеджера LocalLLMServerManager ---")
	_local_manager = LocalLLMServerManagerScript.new()
	_local_manager.setup(8080)
	assert_eq(_local_manager.get_status(), "stopped", "Статус сервера при старте - stopped")
	assert_false(_local_manager.is_server_running(), "Сервер изначально не запущен")

	_local_manager.set_custom_model_path("user://models/custom_test.gguf")
	assert_eq(_local_manager.get_custom_model_path(), "user://models/custom_test.gguf", "Кастомный путь модели сохраняется")
	_local_manager.set_custom_model_path("")

	print("\n--- 4. Тестирование AnthropicProvider ---")
	var anthropic_prov: Node = AnthropicProviderScript.new()
	assert_eq(anthropic_prov.model, "claude-3-5-sonnet-20241022", "Дефолтная модель Anthropic - Claude 3.5 Sonnet")
	anthropic_prov.free()

func _start_mock_llama_server() -> void:
	print("\n--- 5. Запуск Mock Llama-Server на порту %d ---" % _mock_port)
	_mock_server = TCPServer.new()
	var err: Error = _mock_server.listen(_mock_port, "127.0.0.1")
	if err == OK:
		_mock_running = true
		assert_true(true, "Mock Llama-Server успешно открыл порт %d" % _mock_port)
	else:
		assert_true(false, "Не удалось открыть порт для Mock Llama-Server", str(err))

func _poll_mock_server() -> void:
	if not _mock_running or _mock_server == null:
		return

	if _mock_server.is_connection_available():
		var client: StreamPeerTCP = _mock_server.take_connection()
		if client != null:
			_active_clients.append(client)

	for i in range(_active_clients.size() - 1, -1, -1):
		var client: StreamPeerTCP = _active_clients[i]
		client.poll()
		var status := client.get_status()
		if status != StreamPeerTCP.STATUS_CONNECTED:
			_active_clients.remove_at(i)
			continue

		var avail := client.get_available_bytes()
		if avail <= 0:
			continue

		var req_text := client.get_utf8_string(avail)
		if "GET /health" in req_text:
			var body := '{"status": "ok"}'
			var resp := "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" % [body.length(), body]
			client.put_data(resp.to_utf8_buffer())
			_active_clients.remove_at(i)
		elif "chat/completions" in req_text:
			var code := """extends UniCoreModule

## Name: Локальный Куб
## Description: Создан локальным ИИ без внешних ключей
## Tags: local, 3d, test

var _box: MeshInstance3D

func get_module_id() -> String:
	return "local_cube_module"

func initialize(context: Dictionary) -> bool:
	super.initialize(context)
	_box = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	_box.mesh = mesh
	add_child(_box)
	return true

func cleanup() -> void:
	if is_instance_valid(_box):
		_box.queue_free()
	super.cleanup()
"""
			var escaped_code := code.c_escape()
			var body := '{"choices": [{"message": {"role": "assistant", "content": "%s"}}]}' % escaped_code
			var resp := "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" % [body.to_utf8_buffer().size(), body]
			client.put_data(resp.to_utf8_buffer())
			_active_clients.remove_at(i)

func _test_local_server_health_and_query() -> void:
	print("\n--- 6. Проверка взаимодействия с локальным сервером инференса ---")

	_root_node = Node.new()
	_root_node.name = "TestRoot"
	root.add_child(_root_node)

	# 6.1 Проверка Health Check
	_local_manager.setup(_mock_port)
	_root_node.add_child(_local_manager)

	_local_manager.health_checked.connect(func(is_healthy: bool):
		assert_true(is_healthy, "LocalLLMServerManager: /health эндпоинт вернул 200 OK (сервер готов)")
	)
	_local_manager.check_health()

	# 6.2 Подключаем провайдер к порту тестового локального сервера
	_local_provider.base_url = "http://127.0.0.1:%d/v1/chat/completions" % _mock_port
	_root_node.add_child(_local_provider)

	# 6.3 Проверка интеграции в AgentBrain
	_module_manager = ModuleManager.new()
	var world_root := Node3D.new()
	_root_node.add_child(world_root)
	_module_manager.setup(_event_bus, world_root)

	_agent_brain = AgentBrain.new()
	_root_node.add_child(_agent_brain)
	_agent_brain.setup(_event_bus, _module_manager, _local_provider)
	_agent_brain.set_local_provider(_local_provider)
	_agent_brain.set_auto_fallback_to_local(true)

	_agent_brain.request_completed.connect(func(module_id: String):
		assert_eq(module_id, "local_cube_module", "Локальный ИИ успешно синтезировал модуль 'local_cube_module'")
		var mod_node = _module_manager.get_module("local_cube_module")
		assert_true(mod_node != null, "Модуль от локального ИИ успешно смонтирован в Ядре UniCORE")
		_generation_completed = true
	)

	_agent_brain.request_failed.connect(func(err: String):
		assert_true(false, "Генерация локальным ИИ не должна выдавать ошибку", err)
		_generation_completed = true
	)

	print("  Отправка запроса на генерацию модуля в локальную модель (без API ключа)...")
	_agent_brain.process_prompt("Создай локальный куб без облачного API")

func _finish_suite() -> void:
	print("\n==================================================")
	print("Итоговые результаты теста Локального ИИ:")
	print("  Пройдено проверок: %d" % passed_count)
	print("  Ошибок: %d" % failed_count)
	print("==================================================")

	if _mock_server != null:
		_mock_server.stop()
		_mock_server = null

	for client in _active_clients:
		if is_instance_valid(client):
			client.disconnect_from_host()
	_active_clients.clear()

	if _root_node != null and is_instance_valid(_root_node):
		_root_node.queue_free()

	quit(failed_count)
