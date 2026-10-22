class_name SpaceViewport
extends Node3D

## Главное Пространство UniCORE (SpaceViewport)
## Центральная сцена приложения. Инициализирует стерильное Ядро, Менеджер Настроек,
## Менеджер Пространств, Менеджер Модулей, Агента и интерфейс в стиле Detroit: Become Human.

const SettingsManagerScript = preload("res://core/settings_manager.gd")
const SpaceManagerScript = preload("res://core/space_manager.gd")
const ModuleLibraryScript = preload("res://core/module_library.gd")
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

	# 3. Выбор и настройка провайдера LLM
	_setup_llm_provider()

	# 4. Менеджер пространств (загружает сохраненное или создает дефолтное пространство)
	space_manager.setup(module_manager, event_bus, world_root, self, settings_manager)

	# 5. Инициализация UI-оболочки
	top_bar.setup(settings_manager, space_manager, agent_brain, event_bus)
	main_menu.setup(settings_manager, space_manager, module_manager, event_bus, module_library)
	module_toolbar.setup(module_manager, event_bus)
	prompt_bar.setup(event_bus)
	analysis_drawer.setup(event_bus)

	# 6. Связывание событий интерфейса
	_wire_ui_events()

	print("[UniCORE] Shell ready. Current space: '%s', active modules: %s" % [
		space_manager.current_space_name,
		str(module_manager.get_active_module_ids())
	])

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

	agent_brain.setup(event_bus, module_manager, active_provider)

func _wire_ui_events() -> void:
	# Командная строка prompt_bar
	prompt_bar.prompt_submitted.connect(_on_user_prompt_submitted)
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
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_F9:
			if main_menu.is_open and main_menu.tab_container.current_tab == 2:
				main_menu.close()
			else:
				main_menu.open("library")
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F10:
			analysis_drawer.toggle()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
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
		elif event.keycode == KEY_TAB or event.keycode == KEY_QUOTELEFT:
			if not main_menu.is_open:
				prompt_bar.toggle()
				get_viewport().set_input_as_handled()

func _on_user_prompt_submitted(prompt_text: String) -> void:
	_last_user_prompt = prompt_text
	agent_brain.process_user_prompt(prompt_text)
