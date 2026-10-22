class_name PromptBar
extends Control

## Командная строка Агента в стиле "Detroit: Become Human"
## Вариант C: Чистая компактная строка ввода и плавающий контейнер StatusToast.
## Вызывается по Tab / ~, захватывает ввод пользователя для синтеза модулей.

signal prompt_submitted(user_text: String)
signal prompt_cancelled
signal prompt_opened
signal prompt_closed
signal inspect_requested(diagnostic_info: Dictionary)

const CyberTheme = preload("res://ui/theme/cyber_theme.gd")

@onready var bar_container: VBoxContainer = $BarContainer
@onready var panel_container: PanelContainer = $BarContainer/PanelContainer
@onready var prompt_symbol: Label = $BarContainer/PanelContainer/MarginContainer/HBoxContainer/PromptSymbol
@onready var line_edit: LineEdit = $BarContainer/PanelContainer/MarginContainer/HBoxContainer/LineEdit
@onready var close_btn: Button = $BarContainer/PanelContainer/MarginContainer/HBoxContainer/CloseButton

@onready var status_toast: PanelContainer = $BarContainer/StatusToast
@onready var led_marker: ColorRect = $BarContainer/StatusToast/MarginContainer/HBoxContainer/LedMarker
@onready var status_label: Label = $BarContainer/StatusToast/MarginContainer/HBoxContainer/StatusLabel
@onready var inspect_btn: Button = $BarContainer/StatusToast/MarginContainer/HBoxContainer/InspectButton
@onready var toast_close_btn: Button = $BarContainer/StatusToast/MarginContainer/HBoxContainer/ToastCloseButton

var is_open: bool = false
var _event_bus: Node
var _last_prompt: String = ""
var _current_diagnostic: Dictionary = {}
var _current_status_text: String = "Агент готов к запросу"
var _current_status_color: Color = Color(0.0, 0.9, 1.0, 1.0)

func _ready() -> void:
	hide()
	_apply_cyber_styling()
	if not line_edit.text_submitted.is_connected(_on_text_submitted):
		line_edit.text_submitted.connect(_on_text_submitted)
	if not line_edit.gui_input.is_connected(_on_line_edit_gui_input):
		line_edit.gui_input.connect(_on_line_edit_gui_input)
	if close_btn:
		if not close_btn.pressed.is_connected(close):
			close_btn.pressed.connect(close)
		close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if inspect_btn:
		if not inspect_btn.pressed.is_connected(_on_inspect_pressed):
			inspect_btn.pressed.connect(_on_inspect_pressed)
		inspect_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if toast_close_btn:
		if not toast_close_btn.pressed.is_connected(hide_toast):
			toast_close_btn.pressed.connect(hide_toast)
		toast_close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	# Гарантируем перенос слов в StatusLabel
	if status_label:
		status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func setup(event_bus: Node = null) -> void:
	_event_bus = event_bus
	if _event_bus:
		_event_bus.subscribe("interface_settings_changed", func(_data): _apply_cyber_styling())

func _apply_cyber_styling() -> void:
	var is_white := CyberTheme.is_white_theme()
	# 1. Стилизация строки ввода (Cyber HUD Frosted Glass)
	var glass_style := CyberTheme.create_glass_panel_style(
		CyberTheme.COLOR_ELECTRIC_BLUE if is_white else CyberTheme.COLOR_CYAN_GLOW,
		Color(-1, -1, -1, -1),
		1,
		6,
		int(round(6 * CyberTheme.get_led_intensity()))
	)
	panel_container.add_theme_stylebox_override("panel", glass_style)

	line_edit.add_theme_stylebox_override("normal", CyberTheme.create_input_style(false))
	line_edit.add_theme_stylebox_override("focus", CyberTheme.create_input_style(true))
	line_edit.add_theme_color_override("font_color", CyberTheme.get_text_primary_color())
	line_edit.add_theme_color_override("caret_color", CyberTheme.COLOR_ELECTRIC_BLUE if is_white else CyberTheme.COLOR_CYAN_GLOW)
	prompt_symbol.add_theme_color_override("font_color", CyberTheme.COLOR_ELECTRIC_BLUE if is_white else CyberTheme.COLOR_CYAN_GLOW)

	if close_btn:
		var c_style := CyberTheme.create_cyber_button_style(
			Color(0.95, 0.85, 0.85, 0.8) if is_white else Color(0.18, 0.08, 0.1, 0.6),
			CyberTheme.COLOR_RED_LED,
			1,
			3
		)
		var c_hover := CyberTheme.create_cyber_button_style(
			Color(1.0, 0.8, 0.8, 0.95) if is_white else Color(0.35, 0.1, 0.15, 0.9),
			Color(1.0, 0.4, 0.4, 1.0),
			1,
			3,
			2,
			Color(1.0, 0.3, 0.3, 0.3)
		)
		close_btn.add_theme_stylebox_override("normal", c_style)
		close_btn.add_theme_stylebox_override("hover", c_hover)
		close_btn.add_theme_color_override("font_color", CyberTheme.COLOR_RED_LED if is_white else CyberTheme.COLOR_TEXT_PRIMARY)

	# 2. Стилизация StatusToast
	_update_toast_style(_current_status_color)

	if inspect_btn:
		var i_style := CyberTheme.create_cyber_button_style(
			Color(0.85, 0.92, 0.98, CyberTheme.get_glass_opacity()) if is_white else Color(0.05, 0.14, 0.22, 0.85),
			CyberTheme.COLOR_ELECTRIC_BLUE if is_white else Color(0.0, 0.75, 1.0, 0.5),
			1,
			3
		)
		var i_hover := CyberTheme.create_cyber_button_style(
			Color(0.78, 0.88, 0.98, 0.95) if is_white else Color(0.08, 0.25, 0.38, 0.95),
			CyberTheme.COLOR_CYAN_GLOW,
			1,
			3,
			3,
			Color(0.0, 0.85, 1.0, 0.3)
		)
		inspect_btn.add_theme_stylebox_override("normal", i_style)
		inspect_btn.add_theme_stylebox_override("hover", i_hover)
		inspect_btn.add_theme_color_override("font_color", CyberTheme.COLOR_ELECTRIC_BLUE if is_white else CyberTheme.COLOR_CYAN_GLOW)
		inspect_btn.add_theme_color_override("font_hover_color", CyberTheme.COLOR_CYAN_GLOW if is_white else Color.WHITE)
		inspect_btn.add_theme_font_size_override("font_size", 11)

	if toast_close_btn:
		var tc_style := CyberTheme.create_cyber_button_style(
			Color(0.95, 0.85, 0.85, 0.7) if is_white else Color(0.12, 0.08, 0.1, 0.6),
			Color(0.8, 0.3, 0.3, 0.4),
			1,
			3
		)
		var tc_hover := CyberTheme.create_cyber_button_style(
			Color(1.0, 0.8, 0.8, 0.9) if is_white else Color(0.3, 0.1, 0.12, 0.9),
			CyberTheme.COLOR_RED_LED,
			1,
			3,
			2,
			Color(1.0, 0.3, 0.3, 0.3)
		)
		toast_close_btn.add_theme_stylebox_override("normal", tc_style)
		toast_close_btn.add_theme_stylebox_override("hover", tc_hover)
		toast_close_btn.add_theme_color_override("font_color", CyberTheme.COLOR_RED_LED if is_white else CyberTheme.COLOR_TEXT_PRIMARY)

func _update_toast_style(color: Color) -> void:
	if not is_inside_tree() or not status_toast:
		return
	
	if led_marker:
		led_marker.color = color

	var toast_style := CyberTheme.create_glass_panel_style(
		Color(color.r, color.g, color.b, 0.65),
		Color(-1, -1, -1, -1),
		1,
		4,
		int(round(4 * CyberTheme.get_led_intensity()))
	)
	status_toast.add_theme_stylebox_override("panel", toast_style)

func _on_line_edit_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed():
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_QUOTELEFT:
			close()
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_TAB or event.keycode == KEY_QUOTELEFT: # Tab или ~
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

func open() -> void:
	is_open = true
	show()
	line_edit.text = ""
	set_status("Агент готов к запросу", CyberTheme.COLOR_TEXT_CYAN)
	line_edit.grab_focus()
	if DisplayServer.has_feature(DisplayServer.FEATURE_MOUSE):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if _event_bus:
		_event_bus.emit("modal_opened", {"source": "prompt_bar"})
	prompt_opened.emit()

func close() -> void:
	is_open = false
	hide()
	line_edit.release_focus()
	if _event_bus:
		_event_bus.emit("modal_closed", {"source": "prompt_bar"})
	prompt_cancelled.emit()
	prompt_closed.emit()

func set_status(status_text: String, color: Color = Color.WHITE, diagnostic: Dictionary = {}) -> void:
	_current_status_text = status_text
	_current_status_color = color
	
	if not diagnostic.is_empty():
		_current_diagnostic = diagnostic.duplicate(true)
	else:
		var is_err := (color == CyberTheme.COLOR_RED_LED)
		_current_diagnostic = {
			"title": "[СБОЙ АГЕНТА] Ошибка выполнения" if is_err else "Статус Агента",
			"description": status_text,
			"status_color": color,
			"last_prompt": _last_prompt,
			"timestamp": Time.get_datetime_string_from_system()
		}

	if status_label:
		status_label.text = status_text
		status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		status_label.modulate = color

	_update_toast_style(color)
	show_toast()

func show_toast() -> void:
	if status_toast:
		status_toast.show()

func hide_toast() -> void:
	if status_toast:
		status_toast.hide()

func _on_inspect_pressed() -> void:
	if _current_diagnostic.is_empty():
		_current_diagnostic = {
			"title": "Диагностика Агента",
			"description": _current_status_text,
			"status_color": _current_status_color,
			"last_prompt": _last_prompt,
			"timestamp": Time.get_datetime_string_from_system()
		}
	inspect_requested.emit(_current_diagnostic)

func _on_text_submitted(new_text: String) -> void:
	var trimmed = new_text.strip_edges()
	if trimmed.is_empty():
		close()
		return

	_last_prompt = trimmed
	set_status("Генерация модуля...", CyberTheme.COLOR_AMBER_LED, {
		"title": "Генерация модуля",
		"description": "Запрос отправлен Агенту: '%s'" % trimmed,
		"status_color": CyberTheme.COLOR_AMBER_LED,
		"last_prompt": trimmed,
		"timestamp": Time.get_datetime_string_from_system()
	})
	prompt_submitted.emit(trimmed)
