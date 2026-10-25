class_name SpaceViewport
extends Node3D

## Главное Пространство UniCORE (SpaceViewport)
## Центральная сцена приложения. Инициализирует стерильное Ядро, Менеджер Настроек,
## Менеджер Пространств, Менеджер Модулей, Агента и интерфейс в стиле Detroit: Become Human.

const SettingsManagerScript = preload("res://core/settings_manager.gd")
const SpaceManagerScript = preload("res://core/space_manager.gd")
const ModuleLibraryScript = preload("res://core/module_library.gd")
const NetworkTransportScript = preload("res://core/net/network_transport.gd")
const LANDiscoveryScript = preload("res://core/net/lan_discovery.gd")
const ModuleSharingScript = preload("res://core/net/module_sharing.gd")
const SpaceSyncScript = preload("res://core/net/space_sync.gd")
const SemanticCacheScript = preload("res://core/semantic_cache.gd")
const CacheSyncScript = preload("res://core/net/cache_sync.gd")
const InputMapperScript = preload("res://core/input_mapper.gd")
const SpaceStateMachineScript = preload("res://core/net/space_state_machine.gd")
const PresenceManagerScript = preload("res://core/net/presence_manager.gd")
const PeerChatScript = preload("res://core/net/peer_chat.gd")
const PeerMarkerScene = preload("res://ui/presence/peer_marker.tscn")
const PeerChatWindowScene = preload("res://ui/chat/peer_chat_window.tscn")
const CodeValidatorScript = preload("res://agent/code_validator.gd")
const CyberTheme = preload("res://ui/theme/cyber_theme.gd")

@onready var event_bus: EventBus = $EventBus
@onready var settings_manager: Node = $SettingsManager
@onready var module_manager: ModuleManager = $ModuleManager
@onready var space_manager: Node = $SpaceManager
@onready var world_root: Node3D = $WorldRoot
@onready var agent_brain: AgentBrain = $AgentBrain
@onready var gemini_provider: GeminiProvider = $AgentBrain/GeminiProvider

@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var top_bar: Control = $CanvasLayer/TopBar
@onready var prompt_bar: Control = $CanvasLayer/PromptBar
@onready var analysis_drawer: Control = $CanvasLayer/AnalysisDrawer
@onready var module_toolbar: ModuleToolbar = $CanvasLayer/ModuleToolbar
@onready var main_menu: Control = $CanvasLayer/MainMenu
@onready var welcome_screen: Control = $CanvasLayer/WelcomeScreen
@onready var boot_screen: Control = $CanvasLayer/BootScreen

var module_library: ModuleLibrary = null
var semantic_cache: Node = null
var cache_sync: Node = null
var network_transport: Node = null
var lan_discovery: Node = null
var module_sharing: Node = null
var space_sync: Node = null
var input_mapper: Node = null
var space_state_machine: Node = null
var presence_manager: Node = null
var peer_chat: Node = null
var peer_chat_window: Control = null
var local_llm_manager: Node = null
var local_provider: BaseLLMProvider = null
var _peer_markers: Dictionary = {} # peer_id (int) -> Node3D (PeerMarker)
var _last_user_prompt: String = ""
var _is_in_space: bool = false

func _ready() -> void:
	print("[UniCORE] Initializing Core Engine & Shell...")

	# 1. Настройки системы и графики
	settings_manager.setup(event_bus)

	# 2. Менеджер модулей и библиотека модулей
	module_manager.setup(event_bus, world_root)
	if not module_library:
		module_library = ModuleLibraryScript.new()
		module_library.name = "ModuleLibrary"
		add_child(module_library)
	module_library.setup(module_manager, event_bus)

	# 2.5 Семантический кэш модулей
	if not semantic_cache:
		semantic_cache = SemanticCacheScript.new()
		semantic_cache.name = "SemanticCache"
		add_child(semantic_cache)

	# 2.6 Диспетчер назначения клавиш (Input Mapper)
	if not input_mapper:
		input_mapper = InputMapperScript.new()
		input_mapper.name = "InputMapper"
		add_child(input_mapper)
	input_mapper.setup(settings_manager, module_manager, module_library, event_bus)

	# 3. Сетевой уровень и кэш-синхронизация
	_setup_network_layer()

	# 4. Выбор и настройка провайдера LLM и AgentBrain
	_setup_llm_provider()

	# 5. Менеджер пространств
	space_manager.setup(module_manager, event_bus, world_root, self, settings_manager)

	# 6. Инициализация UI-оболочки
	top_bar.setup(settings_manager, space_manager, agent_brain, event_bus)
	main_menu.setup(settings_manager, space_manager, module_manager, event_bus, module_library, network_transport, lan_discovery, module_sharing, space_sync, semantic_cache, input_mapper, space_state_machine, presence_manager, peer_chat)
	if welcome_screen and welcome_screen.has_method("setup"):
		welcome_screen.setup(settings_manager, space_manager, module_manager, event_bus, input_mapper)
	module_toolbar.setup(module_manager, event_bus)
	prompt_bar.setup(event_bus)
	analysis_drawer.setup(event_bus)

	# 7. Связывание событий интерфейса
	_wire_ui_events()
	_wire_welcome_screen_events()

	print("[UniCORE] Shell ready. Current space: '%s', active modules: %s" % [
		space_manager.current_space_name,
		str(module_manager.get_active_module_ids())
	])

func _setup_network_layer() -> void:
	if not network_transport:
		network_transport = NetworkTransportScript.new()
		network_transport.name = "NetworkTransport"
		add_child(network_transport)

	if not lan_discovery:
		lan_discovery = LANDiscoveryScript.new()
		lan_discovery.name = "LANDiscovery"
		add_child(lan_discovery)

	if not module_sharing:
		module_sharing = ModuleSharingScript.new()
		module_sharing.name = "ModuleSharing"
		add_child(module_sharing)

	if not space_sync:
		space_sync = SpaceSyncScript.new()
		space_sync.name = "SpaceSync"
		add_child(space_sync)

	# Configure local peer info from settings
	var player_name: String = str(settings_manager.get_setting("network", "player_name", "UniCORE Node"))
	var host_port: int = int(settings_manager.get_setting("network", "host_port", 7777))
	network_transport.set_local_peer_info({
		"name": player_name,
		"port": host_port,
		"modules_count": module_manager.get_active_module_ids().size() if module_manager else 0,
		"space_name": space_manager.current_space_name if space_manager else "Default Studio"
	})

	lan_discovery.set_broadcast_payload({
		"name": player_name,
		"port": host_port,
		"modules_count": module_manager.get_active_module_ids().size() if module_manager else 0
	})

	# Subsystems initialization
	module_sharing.setup(network_transport, module_library, CodeValidatorScript)
	space_sync.setup(network_transport, space_manager)

	# Cache Sync initialization
	if not cache_sync and network_transport and semantic_cache:
		cache_sync = CacheSyncScript.new()
		cache_sync.name = "CacheSync"
		add_child(cache_sync)
		cache_sync.setup(network_transport, semantic_cache, module_sharing)

	# Multiplayer Synchronization: State Machine, Presence, Chat
	if not space_state_machine and network_transport and module_manager:
		space_state_machine = SpaceStateMachineScript.new()
		space_state_machine.name = "SpaceStateMachine"
		add_child(space_state_machine)
		space_state_machine.setup(network_transport, module_manager, space_manager)
		space_state_machine.operation_applied.connect(_on_operation_applied)

	if not presence_manager and network_transport:
		presence_manager = PresenceManagerScript.new()
		presence_manager.name = "PresenceManager"
		add_child(presence_manager)
		presence_manager.setup(network_transport, 1, player_name)
		presence_manager.start_broadcasting_presence(0.1)
		presence_manager.peer_state_updated.connect(_on_presence_peer_state_updated)
		presence_manager.peer_left_presence.connect(_on_presence_peer_left)

	if not peer_chat and network_transport:
		peer_chat = PeerChatScript.new()
		peer_chat.name = "PeerChat"
		add_child(peer_chat)
		peer_chat.setup(network_transport, player_name)

	if not peer_chat_window and canvas_layer:
		peer_chat_window = PeerChatWindowScene.instantiate()
		peer_chat_window.name = "PeerChatWindow"
		canvas_layer.add_child(peer_chat_window)
		peer_chat_window.setup(peer_chat)
		peer_chat_window.hide()

	if agent_brain:
		agent_brain.set_space_state_machine(space_state_machine)
		agent_brain.set_presence_manager(presence_manager)

	# Wire network signals
	var update_net_hud := func(_param: Variant = null) -> void:
		var cur_status: String = network_transport.get_status()
		var count: int = network_transport.get_connected_peers().size()
		var host_name: String = ""
		if cur_status == "connected":
			var info: Dictionary = network_transport.get_peer_info(1)
			host_name = str(info.get("name", "Host"))
		top_bar.update_network_status(cur_status, count, host_name)
		main_menu.update_network_ui(cur_status)

	network_transport.connection_status_changed.connect(func(_status: String):
		update_net_hud.call()
	)
	network_transport.peer_connected.connect(func(pid: int, _info: Dictionary):
		update_net_hud.call()
		if space_state_machine and is_instance_valid(space_state_machine):
			space_state_machine.sync_state_with_peer(pid)
	)
	network_transport.peer_disconnected.connect(func(_pid: int):
		update_net_hud.call()
	)

	lan_discovery.peer_discovered.connect(main_menu.update_lan_peers)
	lan_discovery.peer_lost.connect(main_menu.update_lan_peers)

	module_sharing.module_offered.connect(main_menu.add_module_offer)

	module_sharing.module_received.connect(func(module_id: String, _code: String, sender_id: int):
		DiagnosticLogger.log_info("Модуль '%s' получен от узла #%d и добавлен в библиотеку" % [module_id, sender_id], "ModuleSharing")
		prompt_bar.set_status("Модуль '%s' получен от узла #%d!" % [module_id, sender_id], CyberTheme.COLOR_SUCCESS_LED)
		if is_instance_valid(top_bar) and top_bar.detroit_orb:
			top_bar.detroit_orb.flash_success("Модуль получен!")
	)
	module_sharing.sharing_error.connect(func(peer_id: int, error: String):
		DiagnosticLogger.log_error("Ошибка сетевого обмена с узлом #%d: %s" % [peer_id, error], "ModuleSharing")
	)

	main_menu.setup_network(network_transport, lan_discovery, module_sharing, space_sync, space_state_machine, presence_manager, peer_chat)

	# Auto-start LAN discovery listening if enabled
	var auto_disc: bool = bool(settings_manager.get_setting("network", "auto_discovery", true))
	if auto_disc:
		var disc_port: int = int(settings_manager.get_setting("network", "discovery_port", 7778))
		lan_discovery.start_listening(disc_port)

	# Keep network peer info synchronized with dynamic setting and module changes
	settings_manager.setting_changed.connect(func(cat: String, _key: String, _val: Variant):
		if cat == "network":
			_sync_network_peer_info()
	)
	if module_manager:
		module_manager.module_loaded.connect(func(_id, _inst): _sync_network_peer_info())
		module_manager.module_unloaded.connect(func(_id): _sync_network_peer_info())

func _process(_delta: float) -> void:
	if presence_manager and is_instance_valid(presence_manager) and presence_manager.is_broadcasting():
		var cam: Camera3D = get_viewport().get_camera_3d()
		if cam and is_instance_valid(cam):
			presence_manager.update_local_state(cam.global_position, cam.global_rotation)

func _on_operation_applied(op: Dictionary) -> void:
	var op_type: String = str(op.get("op_type", ""))
	var author_id: int = int(op.get("author_id", 0))
	var local_id: int = 1
	if network_transport and network_transport.has_method("get_local_peer_info"):
		local_id = int(network_transport.get_local_peer_info().get("id", 1))

	if author_id != local_id and is_instance_valid(prompt_bar):
		match op_type:
			"module_load":
				var mid: String = str(op.get("data", {}).get("module_id", ""))
				prompt_bar.set_status("Узел #%d смонтировал модуль '%s'" % [author_id, mid], CyberTheme.COLOR_SUCCESS_LED)
			"module_unload":
				var mid: String = str(op.get("data", {}).get("module_id", ""))
				prompt_bar.set_status("Узел #%d выгрузил модуль '%s'" % [author_id, mid], CyberTheme.COLOR_AMBER_LED)
			"module_edit":
				var mid: String = str(op.get("data", {}).get("module_id", ""))
				prompt_bar.set_status("Узел #%d обновил модуль '%s'" % [author_id, mid], CyberTheme.COLOR_CYAN_GLOW)

func _on_presence_peer_state_updated(peer_id: int, state: Dictionary) -> void:
	if not world_root or not is_instance_valid(world_root):
		return
	if not _peer_markers.has(peer_id):
		var marker: Node3D = PeerMarkerScene.instantiate()
		marker.name = "PeerMarker_%d" % peer_id
		world_root.add_child(marker)
		var p_name: String = str(state.get("name", "Peer #%d" % peer_id))
		var p_col: Color = state.get("color", PresenceManagerScript.generate_peer_color(peer_id))
		marker.setup(peer_id, p_name, p_col)
		_peer_markers[peer_id] = marker

	var marker_inst = _peer_markers.get(peer_id, null)
	if marker_inst and is_instance_valid(marker_inst):
		marker_inst.update_state(state)

func _on_presence_peer_left(peer_id: int) -> void:
	if _peer_markers.has(peer_id):
		var marker = _peer_markers[peer_id]
		if is_instance_valid(marker):
			marker.queue_free()
		_peer_markers.erase(peer_id)

func _sync_network_peer_info() -> void:
	if not network_transport or not lan_discovery or not settings_manager:
		return
	var player_name: String = str(settings_manager.get_setting("network", "player_name", "UniCORE Node"))
	var host_port: int = int(settings_manager.get_setting("network", "host_port", 7777))
	var mod_count: int = module_manager.get_active_module_ids().size() if module_manager else 0
	var s_name: String = space_manager.current_space_name if space_manager else "Default Studio"

	network_transport.set_local_peer_info({
		"name": player_name,
		"port": host_port,
		"modules_count": mod_count,
		"space_name": s_name
	})
	lan_discovery.set_broadcast_payload({
		"name": player_name,
		"port": host_port,
		"modules_count": mod_count
	})


func _setup_llm_provider() -> void:
	# 1. Монтирование local_llm_manager (LocalLLMServerManager) при наличии скрипта
	var local_mgr_path := "res://agent/local_llm_manager.gd"
	if ResourceLoader.exists(local_mgr_path):
		var mgr_script = load(local_mgr_path)
		if mgr_script:
			local_llm_manager = mgr_script.new()
			local_llm_manager.name = "LocalLLMServerManager"
			add_child(local_llm_manager)

			if local_llm_manager.has_signal("download_progress"):
				local_llm_manager.connect("download_progress", Callable(self, "_on_local_llm_download_progress"))
			if local_llm_manager.has_signal("download_completed"):
				local_llm_manager.connect("download_completed", Callable(self, "_on_local_llm_download_completed"))
			if local_llm_manager.has_signal("server_started"):
				local_llm_manager.connect("server_started", Callable(self, "_on_local_llm_server_started"))
			if local_llm_manager.has_signal("server_error"):
				local_llm_manager.connect("server_error", Callable(self, "_on_local_llm_server_error"))

	# 2. Создание локального OpenAICompatibleProvider (preset local_embedded на порт local_server_port)
	var local_server_port: int = int(settings_manager.get_setting("agent", "local_server_port", 8080))
	var local_server_threads: int = int(settings_manager.get_setting("agent", "local_server_threads", 4))
	var auto_fallback: bool = bool(settings_manager.get_setting("agent", "auto_fallback_to_local", true))

	var openai_compat_script = load("res://agent/providers/openai_compatible_provider.gd")
	local_provider = openai_compat_script.new()
	local_provider.name = "LocalLLMProvider"
	var local_url: String = "http://127.0.0.1:%d/v1/chat/completions" % local_server_port
	if (local_provider as Object).has_method("configure_preset"):
		(local_provider as Object).call("configure_preset", "local_embedded", "qwen2.5-coder-1.5b", local_url)
	else:
		local_provider.set("base_url", local_url)
		local_provider.set("model", "qwen2.5-coder-1.5b")
	agent_brain.add_child(local_provider)
	agent_brain.set_local_provider(local_provider)
	agent_brain.set_auto_fallback_to_local(auto_fallback)

	# 3. Определение активного провайдера из настроек
	var active_prov_name: String = ""
	if settings_manager.has_method("get_agent_provider"):
		active_prov_name = settings_manager.get_agent_provider()
	else:
		active_prov_name = str(settings_manager.get_setting("agent", "provider", "local_embedded"))

	# Запуск локального сервера при необходимости
	if local_llm_manager != null and (active_prov_name == "local_embedded" or auto_fallback):
		if local_llm_manager.has_method("start_server"):
			local_llm_manager.start_server(local_server_port, local_server_threads)

	# 4. Ветвление создания активного провайдера
	var active_provider: BaseLLMProvider = gemini_provider

	match active_prov_name:
		"local_embedded":
			active_provider = local_provider
			agent_brain.api_key = ""
			print("[UniCORE] Active LLM Provider: Local Embedded (model: %s, port: %d)" % [str(local_provider.get("model")), local_server_port])

		"anthropic":
			var anthropic_path := "res://agent/providers/anthropic_provider.gd"
			var anthropic_model: String = settings_manager.get_agent_model("anthropic") if settings_manager.has_method("get_agent_model") else "claude-3-5-sonnet-20241022"
			var anthropic_key: String = settings_manager.get_agent_api_key("anthropic") if settings_manager.has_method("get_agent_api_key") else ""
			if ResourceLoader.exists(anthropic_path):
				var anthropic_script = load(anthropic_path)
				var p = anthropic_script.new()
				p.name = "AnthropicProvider"
				p.set("model", anthropic_model)
				agent_brain.add_child(p)
				active_provider = p
				agent_brain.api_key = anthropic_key
				print("[UniCORE] Active LLM Provider: Anthropic (model: %s)" % anthropic_model)
			else:
				push_warning("[UniCORE] AnthropicProvider script not found. Falling back to local/gemini.")
				active_provider = local_provider if local_provider else gemini_provider

		"groq", "mistral", "deepseek", "openrouter", "openai", "custom":
			var p_model: String = settings_manager.get_agent_model(active_prov_name) if settings_manager.has_method("get_agent_model") else ""
			var p_key: String = settings_manager.get_agent_api_key(active_prov_name) if settings_manager.has_method("get_agent_api_key") else ""
			var custom_url: String = str(settings_manager.get_setting("agent", "custom_base_url", "")) if active_prov_name == "custom" else ""
			var p_inst = openai_compat_script.new()
			p_inst.name = active_prov_name.capitalize() + "Provider"

			var default_endpoints: Dictionary = {
				"groq": "https://api.groq.com/openai/v1/chat/completions",
				"mistral": "https://api.mistral.ai/v1/chat/completions",
				"deepseek": "https://api.deepseek.com/chat/completions",
				"openrouter": "https://openrouter.ai/api/v1/chat/completions",
				"openai": "https://api.openai.com/v1/chat/completions",
				"custom": custom_url
			}

			if (p_inst as Object).has_method("configure_preset"):
				(p_inst as Object).call("configure_preset", active_prov_name, p_model, custom_url)
			else:
				var target_url: String = str(default_endpoints.get(active_prov_name, "https://api.openai.com/v1/chat/completions"))
				if active_prov_name == "custom" and target_url.is_empty():
					target_url = "http://127.0.0.1:8080/v1/chat/completions"
				p_inst.set("base_url", target_url)
				p_inst.set("model", p_model)

			agent_brain.add_child(p_inst)
			active_provider = p_inst
			agent_brain.api_key = p_key
			print("[UniCORE] Active LLM Provider: %s (model: %s)" % [p_inst.name, p_model])

		"gemini":
			var gemini_model: String = settings_manager.get_agent_model("gemini") if settings_manager.has_method("get_agent_model") else "gemini-2.5-flash"
			var gemini_key: String = settings_manager.get_agent_api_key("gemini") if settings_manager.has_method("get_agent_api_key") else ""
			if not gemini_model.is_empty():
				gemini_provider.model = gemini_model
			active_provider = gemini_provider
			agent_brain.api_key = gemini_key
			print("[UniCORE] Active LLM Provider: Google Gemini Direct (model: %s)" % gemini_provider.model)

		_:
			if local_provider:
				active_provider = local_provider
				agent_brain.api_key = ""
			else:
				active_provider = gemini_provider

	agent_brain.setup(event_bus, module_manager, active_provider, null, null, module_library, semantic_cache, cache_sync, space_state_machine, presence_manager)

func _wire_ui_events() -> void:
	# Командная строка prompt_bar
	prompt_bar.prompt_submitted.connect(_on_user_prompt_submitted)
	if agent_brain.has_signal("module_resolved"):
		agent_brain.module_resolved.connect(func(mod_id: String, source_type: String, duration: float):
			if prompt_bar.has_method("set_resolution_status"):
				prompt_bar.set_resolution_status(mod_id, source_type, duration)
			if main_menu.has_method("update_cache_source"):
				main_menu.update_cache_source(source_type)
		)
	agent_brain.request_started.connect(func(p):
		_last_user_prompt = p
		DiagnosticLogger.log_info("Генерация модуля: '%s'" % p, "AgentBrain")
		prompt_bar.set_status("Генерация модуля...", CyberTheme.COLOR_AMBER_LED, {
			"title": "Генерация модуля",
			"description": "Запрос отправлен Агенту: '%s'" % p,
			"status_color": CyberTheme.COLOR_AMBER_LED,
			"last_prompt": p,
			"timestamp": Time.get_datetime_string_from_system()
		})
	)
	agent_brain.request_completed.connect(func(mod_id):
		DiagnosticLogger.log_info("Модуль '%s' успешно смонтирован" % mod_id, "ModuleManager")
		prompt_bar.set_status("Модуль '%s' смонтирован!" % mod_id, CyberTheme.COLOR_SUCCESS_LED, {
			"title": "Модуль смонтирован",
			"description": "Модуль '%s' успешно синтезирован и подключен в сцену." % mod_id,
			"status_color": CyberTheme.COLOR_SUCCESS_LED,
			"module_id": mod_id,
			"last_prompt": _last_user_prompt,
			"timestamp": Time.get_datetime_string_from_system()
		})
		var autoclose: bool = bool(settings_manager.get_setting("interface", "prompt_bar_autoclose", true))
		if autoclose:
			var timer := get_tree().create_timer(2.5)
			timer.timeout.connect(func(): if prompt_bar.is_open: prompt_bar.close())
	)
	agent_brain.request_failed.connect(func(err):
		DiagnosticLogger.log_error("Сбой запроса: %s" % err, "AgentBrain")
		var prov_name: String = settings_manager.get_setting("agent", "provider", "local_embedded")
		var model_name: String = settings_manager.get_agent_model(prov_name) if settings_manager.has_method("get_agent_model") else str(settings_manager.get_setting("agent", "model", ""))
		var endpoint_url := "https://generativelanguage.googleapis.com/v1beta/models/..."
		match prov_name:
			"openrouter": endpoint_url = "https://openrouter.ai/api/v1/chat/completions"
			"deepseek": endpoint_url = "https://api.deepseek.com/chat/completions"
			"openai": endpoint_url = "https://api.openai.com/v1/chat/completions"
			"groq": endpoint_url = "https://api.groq.com/openai/v1/chat/completions"
			"mistral": endpoint_url = "https://api.mistral.ai/v1/chat/completions"
			"anthropic": endpoint_url = "https://api.anthropic.com/v1/messages"
			"local_embedded": endpoint_url = "http://127.0.0.1:%d/v1/chat/completions" % int(settings_manager.get_setting("agent", "local_server_port", 8080))
			"custom": endpoint_url = str(settings_manager.get_setting("agent", "custom_base_url", ""))
		
		var diag := {
			"title": "[СБОЙ СЕТИ / АГЕНТА] Ошибка выполнения запроса",
			"description": err,
			"error": err,
			"raw_error": err,
			"status_color": CyberTheme.COLOR_RED_LED,
			"provider": prov_name.to_upper(),
			"model": model_name,
			"url": endpoint_url,
			"last_prompt": _last_user_prompt,
			"timestamp": Time.get_datetime_string_from_system()
		}
		prompt_bar.set_status("Ошибка: %s" % err, CyberTheme.COLOR_RED_LED, diag)
	)

	# Сигналы TopBar
	top_bar.menu_button_pressed.connect(func(target_tab: String):
		if target_tab == "welcome":
			_return_to_welcome_screen()
		elif target_tab == "menu":
			main_menu.toggle()
		else:
			main_menu.open(target_tab)
	)
	top_bar.prompt_toggle_pressed.connect(func():
		prompt_bar.toggle()
	)
	top_bar.log_button_pressed.connect(func():
		analysis_drawer.toggle()
	)
	top_bar.fullscreen_toggle_pressed.connect(func():
		settings_manager.toggle_fullscreen()
	)

	# Интеграция AnalysisDrawer
	prompt_bar.inspect_requested.connect(func(diagnostic: Dictionary):
		analysis_drawer.open(diagnostic)
	)
	analysis_drawer.open_settings_requested.connect(func(_section: String):
		analysis_drawer.close()
		main_menu.open("settings")
	)
	analysis_drawer.retry_requested.connect(func(prompt_text: String):
		analysis_drawer.close()
		if not prompt_text.is_empty():
			_on_user_prompt_submitted(prompt_text)
	)

	# Управление курсором и событиями открытия/закрытия оверлеев
	main_menu.menu_opened.connect(func():
		if prompt_bar.is_open:
			prompt_bar.close()
		if analysis_drawer.is_open:
			analysis_drawer.close()
		if event_bus:
			event_bus.emit("modal_opened", {"source": "main_menu"})
	)
	main_menu.menu_closed.connect(func():
		if event_bus:
			event_bus.emit("modal_closed", {"source": "main_menu"})
		if not _is_in_space and welcome_screen:
			if welcome_screen.has_method("open_welcome"):
				welcome_screen.open_welcome()
			else:
				welcome_screen.visible = true
	)
	prompt_bar.prompt_opened.connect(func():
		if main_menu.is_open:
			main_menu.close()
		if analysis_drawer.is_open:
			analysis_drawer.close()
		if event_bus:
			event_bus.emit("modal_opened", {"source": "prompt_bar"})
	)
	prompt_bar.prompt_closed.connect(func():
		if event_bus:
			event_bus.emit("modal_closed", {"source": "prompt_bar"})
	)
	analysis_drawer.drawer_opened.connect(func():
		if prompt_bar.is_open:
			prompt_bar.close()
		if main_menu.is_open:
			main_menu.close()
		if event_bus:
			event_bus.emit("modal_opened", {"source": "analysis_drawer"})
	)
	analysis_drawer.drawer_closed.connect(func():
		if event_bus:
			event_bus.emit("modal_closed", {"source": "analysis_drawer"})
	)

	# 5. Связывание событий галереи модулей ModuleGallery
	if main_menu.module_gallery:
		main_menu.module_gallery.view_code_requested.connect(func(mod_id: String, source_code: String):
			analysis_drawer.open({
				"title": "[ИСХОДНЫЙ КОД] Модуль '%s'" % mod_id,
				"code": source_code,
				"description": "Просмотр исходного кода модуля из Галереи Модулей.",
				"status_color": CyberTheme.COLOR_CYAN_GLOW
			})
		)
		main_menu.module_gallery.delete_requested.connect(func(mod_id: String):
			if module_library:
				module_library.delete_module(mod_id)
		)
		main_menu.module_gallery.import_requested.connect(func(file_path: String):
			if module_library:
				module_library.import_module(file_path)
		)
		main_menu.module_gallery.module_load_requested.connect(func(mod_id: String):
			if module_library and module_manager:
				var src := module_library.get_module_source(mod_id)
				if not src.is_empty():
					module_manager.load_module_from_source(mod_id, src)
		)
		main_menu.module_gallery.module_unload_requested.connect(func(mod_id: String):
			if module_manager:
				module_manager.unload_module(mod_id)
		)

func _wire_welcome_screen_events() -> void:
	if not welcome_screen:
		return

	if DisplayServer.get_name() == "headless":
		_is_in_space = true
		welcome_screen.visible = false
		if boot_screen:
			boot_screen.visible = false
	else:
		_is_in_space = false
		if welcome_screen.has_method("open_welcome"):
			welcome_screen.open_welcome()
		else:
			welcome_screen.visible = true
		if event_bus:
			event_bus.emit("modal_opened", {"source": "welcome_screen"})

	welcome_screen.resume_requested.connect(func():
		_is_in_space = true
		if event_bus:
			event_bus.emit("modal_closed", {"source": "welcome_screen"})
	)

	welcome_screen.spaces_requested.connect(func():
		main_menu.open("spaces")
	)

	welcome_screen.modules_requested.connect(func():
		main_menu.open("library")
	)

	welcome_screen.network_requested.connect(func():
		main_menu.open("network")
	)

	welcome_screen.settings_requested.connect(func():
		main_menu.open("settings")
	)

	welcome_screen.quit_requested.connect(func():
		get_tree().quit()
	)

	if main_menu.has_signal("title_screen_requested"):
		main_menu.title_screen_requested.connect(_return_to_welcome_screen)

	if boot_screen:
		boot_screen.boot_completed.connect(func():
			if not _is_in_space and welcome_screen:
				if welcome_screen.has_method("open_welcome"):
					welcome_screen.open_welcome()
				else:
					welcome_screen.visible = true
		)

func _return_to_welcome_screen() -> void:
	_is_in_space = false
	if main_menu and main_menu.is_open:
		main_menu.close()
	if prompt_bar and prompt_bar.is_open:
		prompt_bar.close()
	if analysis_drawer and analysis_drawer.is_open:
		analysis_drawer.close()
	if welcome_screen:
		if welcome_screen.has_method("open_welcome"):
			welcome_screen.open_welcome()
		else:
			welcome_screen.visible = true
	if event_bus:
		event_bus.emit("modal_opened", {"source": "welcome_screen"})

func _input(event: InputEvent) -> void:
	var is_toggle_fs := false
	if InputMap.has_action("toggle_fullscreen") and event.is_action_pressed("toggle_fullscreen"):
		is_toggle_fs = true
	elif event is InputEventKey and event.is_pressed() and not event.is_echo() and event.keycode == KEY_F11:
		is_toggle_fs = true

	if is_toggle_fs:
		if settings_manager and settings_manager.has_method("toggle_fullscreen"):
			settings_manager.toggle_fullscreen()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not _is_in_space:
		return
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return

	var is_gallery: bool = (InputMap.has_action("toggle_module_gallery") and event.is_action_pressed("toggle_module_gallery")) or event.keycode == KEY_F9
	var is_diag: bool = (InputMap.has_action("toggle_analysis_drawer") and event.is_action_pressed("toggle_analysis_drawer")) or event.keycode == KEY_F10
	var is_menu: bool = (InputMap.has_action("toggle_menu") and event.is_action_pressed("toggle_menu")) or event.keycode == KEY_ESCAPE
	var is_prompt: bool = (InputMap.has_action("toggle_prompt_bar") and event.is_action_pressed("toggle_prompt_bar")) or event.keycode == KEY_TAB or event.keycode == KEY_QUOTELEFT
	var is_chat: bool = (InputMap.has_action("toggle_chat") and event.is_action_pressed("toggle_chat")) or (event.keycode == KEY_T and not event.is_echo())

	if is_gallery:
		if main_menu.is_open and main_menu.tab_container.current_tab == 2:
			main_menu.close()
		else:
			main_menu.open("library")
		get_viewport().set_input_as_handled()
	elif is_diag:
		analysis_drawer.toggle()
		get_viewport().set_input_as_handled()
	elif is_chat:
		if peer_chat_window and not main_menu.is_open and not prompt_bar.is_open:
			peer_chat_window.toggle()
			get_viewport().set_input_as_handled()
	elif is_menu:
		if peer_chat_window and peer_chat_window.visible:
			peer_chat_window.close()
			get_viewport().set_input_as_handled()
		elif analysis_drawer.is_open:
			analysis_drawer.close()
			get_viewport().set_input_as_handled()
		elif prompt_bar.is_open:
			prompt_bar.close()
			get_viewport().set_input_as_handled()
		elif main_menu.is_open:
			main_menu.close()
			get_viewport().set_input_as_handled()
		elif Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			if DisplayServer.has_feature(DisplayServer.FEATURE_MOUSE):
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			get_viewport().set_input_as_handled()
		else:
			main_menu.open()
			get_viewport().set_input_as_handled()
	elif is_prompt:
		if not main_menu.is_open:
			prompt_bar.toggle()
			get_viewport().set_input_as_handled()

func _on_user_prompt_submitted(prompt_text: String) -> void:
	_last_user_prompt = prompt_text
	agent_brain.process_user_prompt(prompt_text)

func _on_local_llm_download_progress(percent: float, speed_kb: float) -> void:
	var msg: String = "Загрузка локальной модели: %.1f%% (%.1f KB/s)" % [percent, speed_kb]
	if prompt_bar and is_instance_valid(prompt_bar):
		prompt_bar.set_status(msg, CyberTheme.COLOR_AMBER_LED)
	if top_bar and is_instance_valid(top_bar) and top_bar.detroit_orb:
		top_bar.detroit_orb.flash_amber()

func _on_local_llm_download_completed(model_path: String) -> void:
	var msg: String = "Локальная модель загружена: %s" % model_path.get_file()
	DiagnosticLogger.log_info(msg, "LocalLLM")
	if prompt_bar and is_instance_valid(prompt_bar):
		prompt_bar.set_status(msg, CyberTheme.COLOR_SUCCESS_LED)
	if top_bar and is_instance_valid(top_bar) and top_bar.detroit_orb:
		top_bar.detroit_orb.flash_success("Модель готова!")

func _on_local_llm_server_started(port: int) -> void:
	var msg: String = "Локальный ИИ запущен на порту %d" % port
	DiagnosticLogger.log_info(msg, "LocalLLM")
	if prompt_bar and is_instance_valid(prompt_bar):
		prompt_bar.set_status(msg, CyberTheme.COLOR_CYAN_GLOW)

func _on_local_llm_server_error(error_msg: String) -> void:
	var msg: String = "Ошибка локального сервера ИИ: %s" % error_msg
	DiagnosticLogger.log_error(msg, "LocalLLM")
	if prompt_bar and is_instance_valid(prompt_bar):
		prompt_bar.set_status(msg, CyberTheme.COLOR_RED_LED)
