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

var module_library: ModuleLibrary = null
var semantic_cache: Node = null
var cache_sync: Node = null
var network_transport: Node = null
var lan_discovery: Node = null
var module_sharing: Node = null
var space_sync: Node = null
var input_mapper: Node = null
var _last_user_prompt: String = ""

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
	main_menu.setup(settings_manager, space_manager, module_manager, event_bus, module_library, network_transport, lan_discovery, module_sharing, space_sync, semantic_cache, input_mapper)
	module_toolbar.setup(module_manager, event_bus)
	prompt_bar.setup(event_bus)
	analysis_drawer.setup(event_bus)

	# 7. Связывание событий интерфейса
	_wire_ui_events()

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
	network_transport.peer_connected.connect(func(_pid: int, _info: Dictionary):
		update_net_hud.call()
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

	main_menu.setup_network(network_transport, lan_discovery, module_sharing, space_sync)

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
	var active_provider: BaseLLMProvider = gemini_provider

	# Проверяем настройки из SettingsManager и системное окружение
	var saved_provider: String = settings_manager.get_setting("agent", "provider", "")
	var saved_key: String = settings_manager.get_setting("agent", "api_key", "")
	var saved_model: String = settings_manager.get_setting("agent", "model", "")

	var openrouter_key := saved_key if (saved_provider == "openrouter" and not saved_key.is_empty()) else OS.get_environment("OPENROUTER_API_KEY")
	var openai_key := saved_key if (saved_provider == "openai" and not saved_key.is_empty()) else OS.get_environment("OPENAI_API_KEY")
	var deepseek_key := saved_key if (saved_provider == "deepseek" and not saved_key.is_empty()) else OS.get_environment("DEEPSEEK_API_KEY")
	var gemini_key := saved_key if (saved_provider == "gemini" and not saved_key.is_empty()) else OS.get_environment("GEMINI_API_KEY")

	if not gemini_key.is_empty():
		agent_brain.api_key = gemini_key

	if not openrouter_key.is_empty():
		var openrouter_script = load("res://agent/providers/openai_compatible_provider.gd")
		var p = openrouter_script.new()
		p.name = "OpenRouterProvider"
		p.base_url = "https://openrouter.ai/api/v1/chat/completions"
		p.model = saved_model if not saved_model.is_empty() else "google/gemini-2.5-flash"
		agent_brain.add_child(p)
		active_provider = p
		agent_brain.api_key = openrouter_key
		print("[UniCORE] Active LLM Provider: OpenRouter (model: %s)" % p.model)
	elif not deepseek_key.is_empty():
		var deepseek_script = load("res://agent/providers/openai_compatible_provider.gd")
		var p = deepseek_script.new()
		p.name = "DeepSeekProvider"
		p.base_url = "https://api.deepseek.com/chat/completions"
		p.model = saved_model if not saved_model.is_empty() else "deepseek-chat"
		agent_brain.add_child(p)
		active_provider = p
		agent_brain.api_key = deepseek_key
		print("[UniCORE] Active LLM Provider: DeepSeek (model: %s)" % p.model)
	elif not openai_key.is_empty():
		var openai_script = load("res://agent/providers/openai_compatible_provider.gd")
		var p = openai_script.new()
		p.name = "OpenAIProvider"
		p.base_url = "https://api.openai.com/v1/chat/completions"
		p.model = saved_model if not saved_model.is_empty() else "gpt-4o-mini"
		agent_brain.add_child(p)
		active_provider = p
		agent_brain.api_key = openai_key
		print("[UniCORE] Active LLM Provider: OpenAI (model: %s)" % p.model)
	else:
		if not saved_model.is_empty():
			gemini_provider.model = saved_model
		print("[UniCORE] Active LLM Provider: Google Gemini Direct (model: %s)" % gemini_provider.model)

	agent_brain.setup(event_bus, module_manager, active_provider, null, null, module_library, semantic_cache, cache_sync)

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
		var prov_name: String = settings_manager.get_setting("agent", "provider", "gemini")
		var model_name: String = settings_manager.get_setting("agent", "model", "")
		var endpoint_url := "https://generativelanguage.googleapis.com/v1beta/models/..."
		if prov_name == "openrouter":
			endpoint_url = "https://openrouter.ai/api/v1/chat/completions"
		elif prov_name == "deepseek":
			endpoint_url = "https://api.deepseek.com/chat/completions"
		elif prov_name == "openai":
			endpoint_url = "https://api.openai.com/v1/chat/completions"
		
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
		if target_tab == "menu":
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
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return

	var is_gallery: bool = (InputMap.has_action("toggle_module_gallery") and event.is_action_pressed("toggle_module_gallery")) or event.keycode == KEY_F9
	var is_diag: bool = (InputMap.has_action("toggle_analysis_drawer") and event.is_action_pressed("toggle_analysis_drawer")) or event.keycode == KEY_F10
	var is_menu: bool = (InputMap.has_action("toggle_menu") and event.is_action_pressed("toggle_menu")) or event.keycode == KEY_ESCAPE
	var is_prompt: bool = (InputMap.has_action("toggle_prompt_bar") and event.is_action_pressed("toggle_prompt_bar")) or event.keycode == KEY_TAB or event.keycode == KEY_QUOTELEFT

	if is_gallery:
		if main_menu.is_open and main_menu.tab_container.current_tab == 2:
			main_menu.close()
		else:
			main_menu.open("library")
		get_viewport().set_input_as_handled()
	elif is_diag:
		analysis_drawer.toggle()
		get_viewport().set_input_as_handled()
	elif is_menu:
		if analysis_drawer.is_open:
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
