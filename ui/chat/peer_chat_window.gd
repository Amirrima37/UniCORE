class_name PeerChatWindow
extends Control

## UniCORE P2P Chat Window (Detroit Liquid Glass UI)
## Плавающее окно P2P чата между узлами с поддержкой BBCode,
## неоновой подсветки и цветовой дифференциации пиров.

signal opened()
signal closed()

const PresenceManagerScript = preload("res://core/net/presence_manager.gd")

var _peer_chat: Node = null
var _is_dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

@onready var main_panel: PanelContainer = get_node_or_null("MainPanel")
@onready var title_label: Label = get_node_or_null("MainPanel/Margin/VBox/Header/TitleLabel")
@onready var close_button: Button = get_node_or_null("MainPanel/Margin/VBox/Header/CloseButton")
@onready var message_display: RichTextLabel = get_node_or_null("MainPanel/Margin/VBox/MessageDisplay")
@onready var message_input: LineEdit = get_node_or_null("MainPanel/Margin/VBox/InputBar/MessageInput")
@onready var send_button: Button = get_node_or_null("MainPanel/Margin/VBox/InputBar/SendButton")

func _ready() -> void:
	_ensure_components()
	_apply_styling()
	
	if close_button != null and not close_button.pressed.is_connected(close):
		close_button.pressed.connect(close)
	if send_button != null and not send_button.pressed.is_connected(_on_send_pressed):
		send_button.pressed.connect(_on_send_pressed)
	if message_input != null and not message_input.text_submitted.is_connected(_on_input_submitted):
		message_input.text_submitted.connect(_on_input_submitted)
		
	if main_panel != null:
		var header: Control = main_panel.get_node_or_null("Margin/VBox/Header")
		if header != null and not header.gui_input.is_connected(_on_header_gui_input):
			header.gui_input.connect(_on_header_gui_input)

func _exit_tree() -> void:
	if _peer_chat != null and is_instance_valid(_peer_chat):
		if _peer_chat.message_received.is_connected(_on_message_received):
			_peer_chat.message_received.disconnect(_on_message_received)
		if _peer_chat.history_cleared.is_connected(_on_history_cleared):
			_peer_chat.history_cleared.disconnect(_on_history_cleared)

## Инициализация окна чата с привязкой к сервису PeerChat
func setup(peer_chat: Node) -> void:
	_ensure_components()
	
	if _peer_chat != null and is_instance_valid(_peer_chat):
		if _peer_chat.message_received.is_connected(_on_message_received):
			_peer_chat.message_received.disconnect(_on_message_received)
		if _peer_chat.history_cleared.is_connected(_on_history_cleared):
			_peer_chat.history_cleared.disconnect(_on_history_cleared)
			
	_peer_chat = peer_chat
	
	if _peer_chat != null and is_instance_valid(_peer_chat):
		if not _peer_chat.message_received.is_connected(_on_message_received):
			_peer_chat.message_received.connect(_on_message_received)
		if not _peer_chat.history_cleared.is_connected(_on_history_cleared):
			_peer_chat.history_cleared.connect(_on_history_cleared)
			
		_load_history()

## Переключение видимости окна
func toggle() -> void:
	if visible:
		close()
	else:
		open()

## Открытие окна чата
func open() -> void:
	show()
	if message_input != null:
		message_input.grab_focus()
	opened.emit()

## Закрытие окна чата
func close() -> void:
	hide()
	closed.emit()

## Отправка введенного сообщения
func _on_send_pressed() -> void:
	if message_input == null or _peer_chat == null:
		return
	var text: String = message_input.text.strip_edges()
	if text.is_empty():
		return
	message_input.text = ""
	_peer_chat.send_message(text)
	message_input.grab_focus()

func _on_input_submitted(_text: String) -> void:
	_on_send_pressed()

func _on_message_received(peer_id: int, peer_name: String, text: String, timestamp: float, is_private: bool) -> void:
	append_message(peer_id, peer_name, text, timestamp, is_private)

func _on_history_cleared() -> void:
	if message_display != null:
		message_display.text = ""

## Добавление сообщения в RichTextLabel с цветным форматированием
func append_message(peer_id: int, peer_name: String, text: String, timestamp: float, is_private: bool) -> void:
	if message_display == null:
		return
	
	var time_str: String = _format_timestamp(timestamp)
	var color_hex: String = PresenceManagerScript.generate_peer_color(peer_id).to_html(false)
	var sanitized_text: String = text.replace("[", "［").replace("]", "］")
	
	var line: String = ""
	if is_private:
		line = "[color=#6B788C][%s][/color] [color=#FFB020][ЛИЧНОЕ][/color] [color=#%s][b]%s[/b][/color]: %s\n" % [
			time_str, color_hex, peer_name, sanitized_text
		]
	else:
		line = "[color=#6B788C][%s][/color] [color=#%s][b]%s[/b][/color]: %s\n" % [
			time_str, color_hex, peer_name, sanitized_text
		]
	
	message_display.append_text(line)

func _load_history() -> void:
	if message_display != null:
		message_display.text = ""
	if _peer_chat == null:
		return
	var hist: Array[Dictionary] = _peer_chat.get_history(100)
	for m in hist:
		append_message(
			int(m.get("peer_id", 0)),
			String(m.get("peer_name", "Peer")),
			String(m.get("text", "")),
			float(m.get("timestamp", 0.0)),
			bool(m.get("is_private", false))
		)

func _format_timestamp(ts: float) -> String:
	var d: Dictionary = Time.get_time_dict_from_unix_time(int(ts))
	return "%02d:%02d:%02d" % [d.get("hour", 0), d.get("minute", 0), d.get("second", 0)]

func _on_header_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_dragging = true
				_drag_offset = get_global_mouse_position() - global_position
			else:
				_is_dragging = false
	elif event is InputEventMouseMotion and _is_dragging:
		global_position = get_global_mouse_position() - _drag_offset

func _apply_styling() -> void:
	if main_panel == null:
		return
	
	var panel_style: StyleBoxFlat = _create_panel_style()
	main_panel.add_theme_stylebox_override("panel", panel_style)
	
	if close_button != null:
		var c_normal: StyleBoxFlat = _create_btn_style(Color(0.18, 0.08, 0.1, 0.6), Color(1.0, 0.2, 0.25, 1.0))
		var c_hover: StyleBoxFlat = _create_btn_style(Color(0.35, 0.1, 0.15, 0.9), Color(1.0, 0.4, 0.4, 1.0))
		close_button.add_theme_stylebox_override("normal", c_normal)
		close_button.add_theme_stylebox_override("hover", c_hover)
		close_button.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 1.0))
		
	if send_button != null:
		var btn_normal: StyleBoxFlat = _create_btn_style(Color(0.06, 0.14, 0.26, 0.8), Color(0.0, 0.85, 1.0, 0.5))
		var btn_hover: StyleBoxFlat = _create_btn_style(Color(0.1, 0.24, 0.42, 0.95), Color(0.0, 0.9, 1.0, 1.0))
		var btn_pressed: StyleBoxFlat = _create_btn_style(Color(0.0, 0.45, 0.75, 0.95), Color(0.0, 0.9, 1.0, 1.0))
		send_button.add_theme_stylebox_override("normal", btn_normal)
		send_button.add_theme_stylebox_override("hover", btn_hover)
		send_button.add_theme_stylebox_override("pressed", btn_pressed)
		send_button.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 1.0))
		send_button.add_theme_color_override("font_hover_color", Color(0.0, 0.9, 1.0, 1.0))
		
	if message_input != null:
		var input_style: StyleBoxFlat = StyleBoxFlat.new()
		input_style.bg_color = Color(0.03, 0.05, 0.09, 0.9)
		input_style.border_color = Color(0.0, 0.8, 1.0, 0.35)
		input_style.set_border_width_all(1)
		input_style.set_corner_radius_all(4)
		message_input.add_theme_stylebox_override("normal", input_style)
		message_input.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 1.0))
		message_input.add_theme_color_override("placeholder_color", Color(0.65, 0.72, 0.8, 0.7))
		
	if message_display != null:
		var chat_box_style: StyleBoxFlat = StyleBoxFlat.new()
		chat_box_style.bg_color = Color(0.02, 0.04, 0.08, 0.8)
		chat_box_style.border_color = Color(0.0, 0.8, 1.0, 0.15)
		chat_box_style.set_border_width_all(1)
		chat_box_style.set_corner_radius_all(4)
		message_display.add_theme_stylebox_override("normal", chat_box_style)

func _create_panel_style() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.07, 0.13, 0.92)
	sb.border_color = Color(0.0, 0.85, 1.0, 0.4)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.shadow_color = Color(0.0, 0.85, 1.0, 0.2)
	sb.shadow_size = 8
	return sb

func _create_btn_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	return sb

func _ensure_components() -> void:
	if main_panel == null:
		var p: Node = get_node_or_null("MainPanel")
		if p is PanelContainer:
			main_panel = p
		else:
			main_panel = PanelContainer.new()
			main_panel.name = "MainPanel"
			main_panel.custom_minimum_size = Vector2(380, 440)
			add_child(main_panel)
			
	var margin: MarginContainer = main_panel.get_node_or_null("Margin")
	if margin == null:
		margin = MarginContainer.new()
		margin.name = "Margin"
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_top", 12)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_bottom", 12)
		main_panel.add_child(margin)
		
	var vbox: VBoxContainer = margin.get_node_or_null("VBox")
	if vbox == null:
		vbox = VBoxContainer.new()
		vbox.name = "VBox"
		vbox.add_theme_constant_override("separation", 8)
		margin.add_child(vbox)
		
	var header: HBoxContainer = vbox.get_node_or_null("Header")
	if header == null:
		header = HBoxContainer.new()
		header.name = "Header"
		vbox.add_child(header)
		
	if title_label == null:
		var tl: Node = header.get_node_or_null("TitleLabel")
		if tl is Label:
			title_label = tl
		else:
			title_label = Label.new()
			title_label.name = "TitleLabel"
			title_label.text = "P2P КАНАЛ СВЯЗИ"
			title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			header.add_child(title_label)
			
	if close_button == null:
		var cb: Node = header.get_node_or_null("CloseButton")
		if cb is Button:
			close_button = cb
		else:
			close_button = Button.new()
			close_button.name = "CloseButton"
			close_button.text = " ✕ "
			header.add_child(close_button)
			
	if message_display == null:
		var md: Node = vbox.get_node_or_null("MessageDisplay")
		if md is RichTextLabel:
			message_display = md
		else:
			message_display = RichTextLabel.new()
			message_display.name = "MessageDisplay"
			message_display.bbcode_enabled = true
			message_display.scroll_following = true
			message_display.size_flags_vertical = Control.SIZE_EXPAND_FILL
			message_display.custom_minimum_size = Vector2(0, 260)
			vbox.add_child(message_display)
			
	var input_bar: HBoxContainer = vbox.get_node_or_null("InputBar")
	if input_bar == null:
		input_bar = HBoxContainer.new()
		input_bar.name = "InputBar"
		input_bar.add_theme_constant_override("separation", 6)
		vbox.add_child(input_bar)
		
	if message_input == null:
		var mi: Node = input_bar.get_node_or_null("MessageInput")
		if mi is LineEdit:
			message_input = mi
		else:
			message_input = LineEdit.new()
			message_input.name = "MessageInput"
			message_input.placeholder_text = "Введите сообщение..."
			message_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			input_bar.add_child(message_input)
			
	if send_button == null:
		var sb: Node = input_bar.get_node_or_null("SendButton")
		if sb is Button:
			send_button = sb
		else:
			send_button = Button.new()
			send_button.name = "SendButton"
			send_button.text = "ОТПРАВИТЬ"
			input_bar.add_child(send_button)
