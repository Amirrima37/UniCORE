class_name AnalysisDrawer
extends Control

## Detroit CyberLife Analysis Drawer (Боковая панель диагностики Агента)
## Предоставляет глубокий разбор ошибок сети, валидации кода,
## быстрые действия (копирование отчета, настройки, повтор) и просмотр GDScript.

signal open_settings_requested(section: String)
signal retry_requested(last_prompt: String)
signal drawer_opened
signal drawer_closed

const CyberTheme = preload("res://ui/theme/cyber_theme.gd")

@onready var drawer_panel: PanelContainer = $DrawerPanel
@onready var led_marker: ColorRect = $DrawerPanel/MarginContainer/VBoxContainer/HeaderHBox/LedMarker
@onready var title_label: Label = $DrawerPanel/MarginContainer/VBoxContainer/HeaderHBox/TitleLabel
@onready var close_btn: Button = $DrawerPanel/MarginContainer/VBoxContainer/HeaderHBox/CloseButton

@onready var analysis_panel: PanelContainer = $DrawerPanel/MarginContainer/VBoxContainer/AnalysisPanel
@onready var explanation_label: Label = $DrawerPanel/MarginContainer/VBoxContainer/AnalysisPanel/MarginContainer/VBox/ExplanationLabel

@onready var copy_btn: Button = $DrawerPanel/MarginContainer/VBoxContainer/QuickActionsHBox/CopyButton
@onready var settings_btn: Button = $DrawerPanel/MarginContainer/VBoxContainer/QuickActionsHBox/SettingsButton
@onready var retry_btn: Button = $DrawerPanel/MarginContainer/VBoxContainer/QuickActionsHBox/RetryButton

@onready var tab_container: TabContainer = $DrawerPanel/MarginContainer/VBoxContainer/TabContainer
@onready var http_line_label: Label = $DrawerPanel/MarginContainer/VBoxContainer/TabContainer/TechDetails/Scroll/VBox/HttpLineLabel
@onready var url_line_label: Label = $DrawerPanel/MarginContainer/VBoxContainer/TabContainer/TechDetails/Scroll/VBox/UrlLineLabel
@onready var model_line_label: Label = $DrawerPanel/MarginContainer/VBoxContainer/TabContainer/TechDetails/Scroll/VBox/ModelLineLabel
@onready var raw_response_edit: TextEdit = $DrawerPanel/MarginContainer/VBoxContainer/TabContainer/TechDetails/Scroll/VBox/RawResponseEdit
@onready var stack_edit: TextEdit = $DrawerPanel/MarginContainer/VBoxContainer/TabContainer/TechDetails/Scroll/VBox/StackEdit

@onready var generated_code_edit: CodeEdit = $DrawerPanel/MarginContainer/VBoxContainer/TabContainer/CodeDetails/VBox/GeneratedCodeEdit
@onready var logs_edit: TextEdit = $DrawerPanel/MarginContainer/VBoxContainer/TabContainer/LogsDetails/VBox/LogsEdit
@onready var footer_close_btn: Button = $DrawerPanel/MarginContainer/VBoxContainer/FooterHBox/FooterCloseButton

var is_open: bool = false
var last_copied_report: String = ""
var _current_data: Dictionary = {}
var _event_bus: Node

func _ready() -> void:
	hide()
	_apply_cyber_styling()
	
	if not close_btn.pressed.is_connected(close):
		close_btn.pressed.connect(close)
	if not footer_close_btn.pressed.is_connected(close):
		footer_close_btn.pressed.connect(close)
	if not copy_btn.pressed.is_connected(_on_copy_pressed):
		copy_btn.pressed.connect(_on_copy_pressed)
	if not settings_btn.pressed.is_connected(_on_settings_pressed):
		settings_btn.pressed.connect(_on_settings_pressed)
	if not retry_btn.pressed.is_connected(_on_retry_pressed):
		retry_btn.pressed.connect(_on_retry_pressed)
	
	tab_container.set_tab_title(0, " ТЕХ. ДЕТАЛИ ")
	tab_container.set_tab_title(1, " КОД GDSCRIPT ")
	tab_container.set_tab_title(2, " ЖУРНАЛ ЛОГОВ ")

func setup(event_bus: Node = null) -> void:
	_event_bus = event_bus

func _apply_cyber_styling() -> void:
	var glass_style := CyberTheme.create_glass_panel_style(
		Color(0.0, 0.85, 1.0, 0.4),
		Color(0.03, 0.06, 0.12, 0.95),
		1,
		6,
		10,
		Color(0.0, 0.85, 1.0, 0.25)
	)
	drawer_panel.add_theme_stylebox_override("panel", glass_style)

	# Аналитический блок разбора
	var analysis_box := CyberTheme.create_glass_panel_style(
		Color(0.0, 0.85, 1.0, 0.5),
		Color(0.04, 0.08, 0.15, 0.9),
		1,
		4,
		4,
		Color(0.0, 0.85, 1.0, 0.15)
	)
	analysis_panel.add_theme_stylebox_override("panel", analysis_box)

	# Стили кнопок
	var btn_normal := CyberTheme.create_cyber_button_style(Color(0.06, 0.12, 0.22, 0.8), Color(0.0, 0.75, 1.0, 0.4), 1, 4)
	var btn_hover := CyberTheme.create_cyber_button_style(Color(0.1, 0.22, 0.38, 0.95), CyberTheme.COLOR_CYAN_GLOW, 1, 4, 3, Color(0.0, 0.85, 1.0, 0.3))
	var btn_pressed := CyberTheme.create_cyber_button_style(Color(0.0, 0.45, 0.75, 0.95), CyberTheme.COLOR_CYAN_GLOW, 2, 4)

	for btn in [copy_btn, settings_btn, retry_btn, footer_close_btn]:
		btn.add_theme_stylebox_override("normal", btn_normal)
		btn.add_theme_stylebox_override("hover", btn_hover)
		btn.add_theme_stylebox_override("pressed", btn_pressed)
		btn.add_theme_color_override("font_color", CyberTheme.COLOR_TEXT_PRIMARY)
		btn.add_theme_color_override("font_hover_color", CyberTheme.COLOR_CYAN_GLOW)
		btn.add_theme_font_size_override("font_size", 12)

	# Close button
	var c_style := CyberTheme.create_cyber_button_style(Color(0.18, 0.08, 0.1, 0.6), CyberTheme.COLOR_RED_LED, 1, 3)
	var c_hover := CyberTheme.create_cyber_button_style(Color(0.35, 0.1, 0.15, 0.9), Color(1.0, 0.4, 0.4, 1.0), 1, 3, 2, Color(1.0, 0.3, 0.3, 0.3))
	close_btn.add_theme_stylebox_override("normal", c_style)
	close_btn.add_theme_stylebox_override("hover", c_hover)
	close_btn.add_theme_color_override("font_color", CyberTheme.COLOR_TEXT_PRIMARY)

	# TextEdits / CodeEdit styling
	var editor_box := CyberTheme.create_input_style(false)
	raw_response_edit.add_theme_stylebox_override("normal", editor_box)
	raw_response_edit.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95, 0.9))
	stack_edit.add_theme_stylebox_override("normal", editor_box)
	stack_edit.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95, 0.9))
	generated_code_edit.add_theme_stylebox_override("normal", editor_box)
	generated_code_edit.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0, 1.0))
	logs_edit.add_theme_stylebox_override("normal", editor_box)
	logs_edit.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95, 0.9))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_F10:
			toggle()
			get_viewport().set_input_as_handled()
		elif is_open and event.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()

func toggle() -> void:
	if is_open:
		close()
	else:
		open()

func open(diagnostic_data: Dictionary = {}) -> void:
	is_open = true
	show()
	_current_data = diagnostic_data.duplicate(true)
	
	_populate_ui_from_data(_current_data)
	
	if DisplayServer.has_feature(DisplayServer.FEATURE_MOUSE):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
	if _event_bus:
		_event_bus.emit("modal_opened", {"source": "analysis_drawer"})
	drawer_opened.emit()

func close() -> void:
	is_open = false
	hide()
	if _event_bus:
		_event_bus.emit("modal_closed", {"source": "analysis_drawer"})
	drawer_closed.emit()

func _populate_ui_from_data(data: Dictionary) -> void:
	var status_color: Color = data.get("status_color", CyberTheme.COLOR_RED_LED)
	if led_marker:
		led_marker.color = status_color

	var title: String = data.get("title", "[ДИАГНОСТИКА CYBERLIFE] Анализ состояния системы")
	if title_label:
		title_label.text = title

	# Анализ причины сбоя
	var human_cause := _analyze_root_cause(data)
	if explanation_label:
		explanation_label.text = human_cause

	# Технические подробности
	var http_code = data.get("http_code", data.get("response_code", 0))
	if http_line_label:
		if int(http_code) > 0:
			http_line_label.text = "HTTP Код: %s" % str(http_code)
		else:
			http_line_label.text = "HTTP Код: N/A (Сбой до отправки или ошибка валидации)"

	var url_str: String = data.get("url", "https://generativelanguage.googleapis.com/v1beta/models/...")
	if url_line_label:
		url_line_label.text = "URL Endpoint: %s" % url_str

	var prov_str: String = data.get("provider", "Gemini / OpenAI Compatible")
	var model_str: String = data.get("model", "Default Model")
	if model_line_label:
		model_line_label.text = "Провайдер: %s | Модель: %s" % [prov_str, model_str]

	var raw_body: String = str(data.get("raw_response", data.get("error_body", data.get("raw_error", data.get("error", "")))))
	if raw_response_edit:
		raw_response_edit.text = raw_body if not raw_body.is_empty() else "// Сырые данные ответа отсутствуют"

	var stack_str: String = str(data.get("stack", data.get("call_stack", "AgentBrain.process_user_prompt -> LLMProvider")))
	if stack_edit:
		stack_edit.text = stack_str

	# Сгенерированный код
	var code_str: String = str(data.get("code", data.get("generated_code", "")))
	if generated_code_edit:
		if not code_str.is_empty():
			generated_code_edit.text = code_str
		else:
			generated_code_edit.text = "# Сгенерированный код GDScript отсутствует для данного события"

	# Журнал логов
	if logs_edit:
		if data.has("logs") and data["logs"] is Array and not data["logs"].is_empty():
			var log_lines: PackedStringArray = []
			for l in data["logs"]:
				if l is Dictionary:
					log_lines.append("[%s] [%s] [%s] %s" % [
						l.get("timestamp", "--:--"),
						l.get("level", "INFO"),
						l.get("category", "SYSTEM"),
						l.get("message", "")
					])
				else:
					log_lines.append(str(l))
			logs_edit.text = "\n".join(log_lines)
		elif DiagnosticLogger:
			logs_edit.text = DiagnosticLogger.get_formatted_logs_text()
		else:
			logs_edit.text = "// Журнал событий пуст"

func _analyze_root_cause(data: Dictionary) -> String:
	var desc: String = str(data.get("description", data.get("error", "")))
	var http_code: int = int(data.get("http_code", data.get("response_code", 0)))
	var lower := desc.to_lower()
	
	if "location is not supported" in lower or "user location is not supported" in lower or "location not supported" in lower:
		return "Причина: Региональное ограничение API (User location is not supported). Google напрямую блокирует запросы к Gemini API из вашего региона. Рекомендуется открыть 'Настройки API' и переключиться на OpenRouter или DeepSeek."
	elif "api key is empty" in lower or "api key is missing" in lower or "invalid api key" in lower or http_code == 401 or "unauthenticated" in lower:
		return "Причина: Отсутствует или недействителен API-ключ. Проверьте правильность ключа в Настройках API или задайте системную переменную окружения (OPENROUTER_API_KEY, GEMINI_API_KEY)."
	elif "429" in lower or http_code == 429 or "resource_exhausted" in lower or "quota" in lower:
		return "Причина: Превышен лимит запросов или квота провайдера (Rate Limit / Quota Exceeded). Подождите несколько секунд или смените модель в Настройках API."
	elif "timeout" in lower or "timed out" in lower or http_code == 504:
		return "Причина: Превышено время ожидания ответа сервера (Gateway Timeout). Проверьте сетевое подключение к серверу или попробуйте повторить запрос."
	elif "validation failed" in lower or "security" in lower:
		return "Причина: Сгенерированный LLM код не прошел валидатор безопасности или содержит синтаксическую ошибку. Ознакомьтесь с кодом на вкладке 'КОД GDSCRIPT'."
	elif http_code >= 500:
		return "Причина: Внутренняя ошибка сервера API (%d Internal Server Error). Повторите запрос через пару минут." % http_code
	elif not desc.is_empty():
		return "Причина: %s" % desc
	else:
		return "Все подсистемы ядра и Агента функционируют в штатном режиме."

func copy_report_to_clipboard() -> String:
	var report := _generate_report_string()
	last_copied_report = report
	DisplayServer.clipboard_set(report)
	
	if copy_btn:
		var orig_text := copy_btn.text
		copy_btn.text = "✓ СКОПИРОВАНО!"
		var timer := get_tree().create_timer(1.6)
		timer.timeout.connect(func(): if is_instance_valid(copy_btn): copy_btn.text = orig_text)
	
	return report

func _on_copy_pressed() -> void:
	copy_report_to_clipboard()

func _on_settings_pressed() -> void:
	open_settings_requested.emit("api")

func _on_retry_pressed() -> void:
	retry_requested.emit(_current_data.get("last_prompt", ""))

func _generate_report_string() -> String:
	var title: String = _current_data.get("title", "[ДИАГНОСТИКА CYBERLIFE]")
	var desc: String = _current_data.get("description", _current_data.get("error", "N/A"))
	var cause: String = _analyze_root_cause(_current_data)
	var http_code = _current_data.get("http_code", _current_data.get("response_code", "N/A"))
	var url_str: String = _current_data.get("url", "N/A")
	var prov_str: String = _current_data.get("provider", "N/A")
	var model_str: String = _current_data.get("model", "N/A")
	var last_prompt: String = _current_data.get("last_prompt", "N/A")
	var raw_body: String = str(_current_data.get("raw_response", _current_data.get("error_body", _current_data.get("raw_error", ""))))
	var code_str: String = str(_current_data.get("code", _current_data.get("generated_code", "")))
	
	var r := "==================================================\n"
	r += "   UNICORE CYBERLIFE DIAGNOSTIC REPORT\n"
	r += "==================================================\n"
	r += "Время отчета: %s\n" % Time.get_datetime_string_from_system()
	r += "Заголовок: %s\n" % title
	r += "Промпт пользователя: %s\n" % last_prompt
	r += "Провайдер: %s | Модель: %s\n" % [prov_str, model_str]
	r += "HTTP Статус: %s\n" % str(http_code)
	r += "URL Endpoint: %s\n\n" % url_str
	r += "--- АНАЛИЗ И ПРИЧИНА ---\n"
	r += "%s\n\n" % cause
	r += "--- ОПИСАНИЕ ОШИБКИ ---\n"
	r += "%s\n\n" % desc
	if not raw_body.is_empty():
		r += "--- СЫРОЙ ОТВЕТ СЕРВЕРА ---\n"
		r += "%s\n\n" % raw_body
	if not code_str.is_empty():
		r += "--- СГЕНЕРИРОВАННЫЙ КОД GDSCRIPT ---\n"
		r += "%s\n\n" % code_str
	if DiagnosticLogger:
		r += "--- ПОСЛЕДНИЕ СОБЫТИЯ ЖУРНАЛА ---\n"
		r += "%s\n" % DiagnosticLogger.get_formatted_logs_text()
	r += "==================================================\n"
	return r
