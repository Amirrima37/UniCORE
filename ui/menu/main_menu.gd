class_name MainMenu
extends Control

## Главное меню UniCORE (Pause / Main Menu Shell)
## Реализовано в стиле "Detroit: Become Human" (матовое стекло, неоновые линии,
## LED-индикация, управление Пространствами, Настройки, Модули и Справка).

signal menu_closed
signal menu_opened
signal title_screen_requested

const SettingsManagerScript = preload("res://core/settings_manager.gd")
const SpaceManagerScript = preload("res://core/space_manager.gd")
const ModuleGalleryScene = preload("res://ui/module_gallery/module_gallery.tscn")
const InputMapperScript = preload("res://core/input_mapper.gd")

var is_open: bool = false

var _settings_manager: Node
var _space_manager: Node
var _module_manager: Node
var _event_bus: Node
var _module_library: Node
var module_gallery: ModuleGallery = null
var _module_gallery: ModuleGallery = null

var _network_transport: Node = null
var _lan_discovery: Node = null
var _module_sharing: Node = null
var _space_sync: Node = null
var _pending_module_offers: Array[Dictionary] = []

# Input Mapper References
var _input_mapper: Node = null
var keybindings_section_panel: PanelContainer = null
var active_bindings_container: VBoxContainer = null
var library_bindings_container: VBoxContainer = null
var system_bindings_container: VBoxContainer = null
var reset_all_bindings_btn: Button = null

# Key Capture Modal
var _key_capture_modal: Control = null
var _key_capture_action: String = ""
var _key_capture_label: String = ""
var _key_capture_module: String = ""
var _key_capture_desc: Label = null
var _key_capture_prompt: Label = null
var _key_capture_conflict_lbl: Label = null
var _key_capture_pending_key: int = KEY_NONE

# Agent Settings Extended References (Phase 3c: Multi-Provider & Local LLM)
const AGENT_PROVIDER_DATA: Array[Dictionary] = [
	{"id": "local_embedded", "label": "0: Встроенный локальный ИИ (llama-server)", "type": "local"},
	{"id": "gemini", "label": "1: Google Gemini Direct", "type": "cloud"},
	{"id": "anthropic", "label": "2: Anthropic Claude", "type": "cloud"},
	{"id": "openai", "label": "3: OpenAI (ChatGPT)", "type": "cloud"},
	{"id": "openrouter", "label": "4: OpenRouter", "type": "cloud"},
	{"id": "deepseek", "label": "5: DeepSeek API", "type": "cloud"},
	{"id": "groq", "label": "6: Groq (Llama 3.3 / DeepSeek R1)", "type": "cloud"},
	{"id": "mistral", "label": "7: Mistral AI / Codestral", "type": "cloud"},
	{"id": "custom", "label": "8: Кастомный OpenAI-совместимый", "type": "custom"}
]

const AGENT_PROVIDER_IDS: Array[String] = [
	"local_embedded",
	"gemini",
	"anthropic",
	"openai",
	"openrouter",
	"deepseek",
	"groq",
	"mistral",
	"custom"
]

const AGENT_DEFAULT_MODELS: Dictionary = {
	"local_embedded": "qwen2.5-coder-1.5b",
	"anthropic": "claude-3-5-sonnet-20241022",
	"gemini": "gemini-2.5-flash",
	"openai": "gpt-4o-mini",
	"deepseek": "deepseek-chat",
	"groq": "llama-3.3-70b-versatile",
	"mistral": "codestral-latest",
	"openrouter": "google/gemini-2.5-flash",
	"custom": "default"
}

var _local_llm_manager: Node = null
var _current_editing_provider: String = "local_embedded"

var _key_label: Label = null
var _toggle_key_vis_btn: Button = null

var _custom_url_label: Label = null
var _agent_custom_url_edit: LineEdit = null

var _agent_zero_key_panel: PanelContainer = null

var _agent_local_card: PanelContainer = null
var _local_status_lbl: Label = null
var _local_download_box: VBoxContainer = null
var _local_download_lbl: Label = null
var _local_download_bar: ProgressBar = null
var _local_gguf_edit: LineEdit = null
var _local_gguf_browse_btn: Button = null
var _local_gguf_clear_btn: Button = null
var _local_gguf_dialog: FileDialog = null

var _agent_fallback_check: CheckBox = null

# Node References
@onready var modal_backdrop: ColorRect = $ModalBackdrop
@onready var main_panel: PanelContainer = $MainPanel
@onready var tab_container: TabContainer = $MainPanel/MarginContainer/VBoxContainer/TabContainer
@onready var close_btn: Button = $MainPanel/MarginContainer/VBoxContainer/HeaderHBox/CloseButton
@onready var resume_btn: Button = $MainPanel/MarginContainer/VBoxContainer/FooterHBox/ResumeButton
@onready var quit_btn: Button = $MainPanel/MarginContainer/VBoxContainer/FooterHBox/QuitButton
var title_screen_btn: Button = null

# Spaces Tab References
@onready var current_space_label: Label = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SpacesTab/VBox/CurrentSpaceBanner/CurrentSpaceLabel
@onready var btn_quick_save: Button = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SpacesTab/VBox/ActionsHBox/QuickSaveButton
@onready var btn_show_new_space: Button = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SpacesTab/VBox/ActionsHBox/NewSpaceButton
@onready var btn_show_save_as: Button = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SpacesTab/VBox/ActionsHBox/SaveAsButton

@onready var new_space_form: PanelContainer = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SpacesTab/VBox/NewSpaceForm
@onready var new_space_name_edit: LineEdit = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SpacesTab/VBox/NewSpaceForm/VBox/NameEdit
@onready var new_space_template_opt: OptionButton = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SpacesTab/VBox/NewSpaceForm/VBox/TemplateOption
@onready var new_space_create_btn: Button = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SpacesTab/VBox/NewSpaceForm/VBox/ButtonsHBox/CreateButton
@onready var new_space_cancel_btn: Button = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SpacesTab/VBox/NewSpaceForm/VBox/ButtonsHBox/CancelButton

@onready var save_as_form: PanelContainer = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SpacesTab/VBox/SaveAsForm
@onready var save_as_name_edit: LineEdit = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SpacesTab/VBox/SaveAsForm/VBox/SaveAsNameEdit
@onready var save_as_confirm_btn: Button = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SpacesTab/VBox/SaveAsForm/VBox/ButtonsHBox/ConfirmButton
@onready var save_as_cancel_btn: Button = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SpacesTab/VBox/SaveAsForm/VBox/ButtonsHBox/CancelButton

@onready var spaces_list_container: VBoxContainer = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SpacesTab/VBox/Scroll/SpacesList

# Settings Tab References
@onready var fullscreen_check: CheckBox = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/DisplaySection/FullscreenCheck
@onready var resolution_opt: OptionButton = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/DisplaySection/ResolutionOption
@onready var vsync_check: CheckBox = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/DisplaySection/VsyncCheck
@onready var fps_opt: OptionButton = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/DisplaySection/FpsOption

# Interface Section References
@onready var interface_theme_opt: OptionButton = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/InterfaceSection/ThemeOption
@onready var glass_opacity_slider: HSlider = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/InterfaceSection/OpacitySlider
@onready var glass_opacity_val_label: Label = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/InterfaceSection/OpacityValLabel
@onready var led_intensity_slider: HSlider = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/InterfaceSection/LedSlider
@onready var led_intensity_val_label: Label = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/InterfaceSection/LedValLabel
@onready var prompt_autoclose_check: CheckBox = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/InterfaceSection/AutocloseCheck

@onready var mouse_sens_slider: HSlider = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/ControlsSection/SensitivitySlider
@onready var mouse_sens_val_label: Label = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/ControlsSection/SensitivityValLabel
@onready var invert_y_check: CheckBox = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/ControlsSection/InvertYCheck
@onready var move_speed_slider: HSlider = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/ControlsSection/SpeedSlider
@onready var move_speed_val_label: Label = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/ControlsSection/SpeedValLabel

@onready var master_vol_slider: HSlider = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/AudioSection/VolumeSlider
@onready var master_vol_val_label: Label = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/AudioSection/VolumeValLabel

@onready var agent_provider_opt: OptionButton = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/AgentSection/ProviderOption
@onready var agent_model_edit: LineEdit = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/AgentSection/ModelEdit
@onready var agent_key_edit: LineEdit = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/AgentSection/KeyEdit
@onready var save_settings_btn: Button = $MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/SaveSettingsButton

# Library & Modules Tab References
@onready var library_tab: MarginContainer = $MainPanel/MarginContainer/VBoxContainer/TabContainer/LibraryTab
@onready var modules_list_container: VBoxContainer = $MainPanel/MarginContainer/VBoxContainer/TabContainer/ModulesTab/Scroll/ModulesList

# Network Tab References
@onready var network_tab: MarginContainer = $MainPanel/MarginContainer/VBoxContainer/TabContainer/NetworkTab
@onready var session_status_label: Label = $MainPanel/MarginContainer/VBoxContainer/TabContainer/NetworkTab/Scroll/VBox/SessionSection/VBox/HeaderHBox/StatusLabel
@onready var host_session_btn: Button = $MainPanel/MarginContainer/VBoxContainer/TabContainer/NetworkTab/Scroll/VBox/SessionSection/VBox/ControlsHBox/HostButton
@onready var session_ip_port_edit: LineEdit = $MainPanel/MarginContainer/VBoxContainer/TabContainer/NetworkTab/Scroll/VBox/SessionSection/VBox/ControlsHBox/IpPortEdit
@onready var connect_session_btn: Button = $MainPanel/MarginContainer/VBoxContainer/TabContainer/NetworkTab/Scroll/VBox/SessionSection/VBox/ControlsHBox/ConnectButton
@onready var disconnect_session_btn: Button = $MainPanel/MarginContainer/VBoxContainer/TabContainer/NetworkTab/Scroll/VBox/SessionSection/VBox/ControlsHBox/DisconnectButton

@onready var refresh_lan_btn: Button = $MainPanel/MarginContainer/VBoxContainer/TabContainer/NetworkTab/Scroll/VBox/LanSection/VBox/HeaderHBox/RefreshLanButton
@onready var lan_peers_list: VBoxContainer = $MainPanel/MarginContainer/VBoxContainer/TabContainer/NetworkTab/Scroll/VBox/LanSection/VBox/LanPeersList

@onready var connected_peers_list: VBoxContainer = $MainPanel/MarginContainer/VBoxContainer/TabContainer/NetworkTab/Scroll/VBox/ConnectedSection/VBox/ConnectedPeersList

@onready var offer_module_btn: Button = $MainPanel/MarginContainer/VBoxContainer/TabContainer/NetworkTab/Scroll/VBox/SharingSection/VBox/HeaderHBox/OfferModuleButton
@onready var module_offers_list: VBoxContainer = $MainPanel/MarginContainer/VBoxContainer/TabContainer/NetworkTab/Scroll/VBox/SharingSection/VBox/ModuleOffersList

# Cache UI References
var _semantic_cache: Node = null
var _last_resolved_source: String = "—"
var cache_section_panel: PanelContainer = null
var cache_stats_label: Label = null
var cache_source_label: Label = null
var cache_popular_list: VBoxContainer = null
var clear_cache_btn: Button = null

# Multiplayer UI References
var _space_state_machine: Node = null
var _presence_manager: Node = null
var _peer_chat: Node = null
var presence_section_panel: PanelContainer = null
var presence_peers_list: VBoxContainer = null
var ops_log_section_panel: PanelContainer = null
var ops_log_list: VBoxContainer = null

# Confirm Dialog
@onready var confirm_dialog: ConfirmationDialog = $ConfirmDialog

func _ready() -> void:
	hide()
	new_space_form.hide()
	save_as_form.hide()

	# Detroit: Become Human Tabs naming
	tab_container.set_tab_title(0, " ПРОСТРАНСТВА ")
	tab_container.set_tab_title(1, " НАСТРОЙКИ ")
	tab_container.set_tab_title(2, " БИБЛИОТЕКА ")
	tab_container.set_tab_title(3, " МОДУЛИ ")
	tab_container.set_tab_title(4, " СЕТЬ ")
	tab_container.set_tab_title(5, " СИСТЕМА ")

	if is_instance_valid(library_tab) and not module_gallery:
		module_gallery = ModuleGalleryScene.instantiate()
		library_tab.add_child(module_gallery)
		_module_gallery = module_gallery

	_apply_styling()
	_setup_base_signals()
	_setup_cache_ui()
	_setup_keybindings_ui()
	_setup_multiplayer_ui()
	_setup_agent_settings_ui()

func setup(settings_mgr: Node, space_mgr: Node, module_mgr: Node, event_bus: Node, module_library: Node = null, transport: Node = null, discovery: Node = null, sharing: Node = null, sync: Node = null, cache: Node = null, input_mapper: Node = null, state_machine: Node = null, presence: Node = null, chat: Node = null, local_llm_mgr: Node = null) -> void:
	_settings_manager = settings_mgr
	_space_manager = space_mgr
	_module_manager = module_mgr
	_event_bus = event_bus
	_module_library = module_library
	_space_state_machine = state_machine
	_presence_manager = presence
	_peer_chat = chat

	if module_gallery and _module_library:
		module_gallery.setup(_module_library, _module_manager)

	if _space_manager:
		_space_manager.space_loaded.connect(_on_space_loaded)
		_space_manager.space_list_updated.connect(_on_space_list_updated)
		_refresh_spaces_ui()

	if _settings_manager:
		_settings_manager.setting_changed.connect(_on_setting_changed)

	if _module_manager:
		_module_manager.module_loaded.connect(func(_id, _inst): _refresh_modules_ui())
		_module_manager.module_unloaded.connect(func(_id): _refresh_modules_ui())

	if _event_bus:
		_event_bus.subscribe("interface_settings_changed", func(_data):
			_apply_styling()
			_refresh_spaces_ui()
			_refresh_modules_ui()
			_refresh_keybindings_ui()
			_refresh_cache_ui()
		)

	if transport != null or discovery != null:
		setup_network(transport, discovery, sharing, sync)

	if cache != null:
		setup_cache(cache)

	if input_mapper != null:
		setup_input_mapper(input_mapper)

	if local_llm_mgr != null:
		setup_local_llm(local_llm_mgr)
	else:
		_find_local_llm_manager()
		_connect_local_llm_signals()

	_load_settings_into_ui()

func _setup_base_signals() -> void:
	close_btn.pressed.connect(close)
	resume_btn.pressed.connect(close)
	quit_btn.pressed.connect(_on_quit_pressed)

	if not title_screen_btn and resume_btn and resume_btn.get_parent():
		title_screen_btn = Button.new()
		title_screen_btn.name = "TitleScreenButton"
		title_screen_btn.text = "⌂ В СТАРТОВЫЙ ЭКРАН"
		title_screen_btn.custom_minimum_size = Vector2(180, 36)
		title_screen_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var footer: HBoxContainer = resume_btn.get_parent() as HBoxContainer
		if footer:
			footer.add_child(title_screen_btn)
			footer.move_child(title_screen_btn, resume_btn.get_index() + 1)
		title_screen_btn.pressed.connect(func():
			close()
			title_screen_requested.emit()
		)

	btn_show_new_space.pressed.connect(func():
		new_space_form.visible = not new_space_form.visible
		save_as_form.hide()
		if new_space_form.visible:
			new_space_name_edit.grab_focus()
	)
	new_space_cancel_btn.pressed.connect(func(): new_space_form.hide())
	new_space_create_btn.pressed.connect(_on_create_space_clicked)

	btn_show_save_as.pressed.connect(func():
		save_as_form.visible = not save_as_form.visible
		new_space_form.hide()
		if save_as_form.visible:
			if _space_manager:
				save_as_name_edit.text = "%s (Copy)" % _space_manager.current_space_name
			save_as_name_edit.grab_focus()
	)
	save_as_cancel_btn.pressed.connect(func(): save_as_form.hide())
	save_as_confirm_btn.pressed.connect(_on_save_as_clicked)

	btn_quick_save.pressed.connect(func():
		if _space_manager:
			_space_manager.save_current_space()
			_refresh_spaces_ui()
	)

	# Settings controls
	fullscreen_check.toggled.connect(func(pressed):
		if _settings_manager:
			_settings_manager.set_fullscreen(pressed)
	)
	resolution_opt.item_selected.connect(func(idx):
		if _settings_manager:
			_settings_manager.set_resolution_by_index(idx)
	)
	vsync_check.toggled.connect(func(pressed):
		if _settings_manager:
			_settings_manager.set_vsync(pressed)
	)
	fps_opt.item_selected.connect(func(idx):
		var fps_vals := [0, 60, 120, 144]
		if idx >= 0 and idx < fps_vals.size() and _settings_manager:
			_settings_manager.set_setting("display", "fps_limit", fps_vals[idx])
			Engine.max_fps = fps_vals[idx]
	)

	# Interface controls
	if is_instance_valid(interface_theme_opt):
		interface_theme_opt.item_selected.connect(func(idx: int):
			var th_name := "cyberlife_white" if idx == 0 else "cyber_void"
			if _settings_manager:
				_settings_manager.set_setting("interface", "theme", th_name, true)
			_apply_styling()
		)

	if is_instance_valid(glass_opacity_slider):
		glass_opacity_slider.value_changed.connect(func(val: float):
			if is_instance_valid(glass_opacity_val_label):
				glass_opacity_val_label.text = "%d%%" % int(round(val * 100.0))
			if _settings_manager:
				_settings_manager.set_setting("interface", "glass_opacity", val, true)
			_apply_styling()
		)

	if is_instance_valid(led_intensity_slider):
		led_intensity_slider.value_changed.connect(func(val: float):
			if is_instance_valid(led_intensity_val_label):
				led_intensity_val_label.text = "%d%%" % int(round(val * 100.0))
			if _settings_manager:
				_settings_manager.set_setting("interface", "led_intensity", val, true)
			_apply_styling()
		)

	if is_instance_valid(prompt_autoclose_check):
		prompt_autoclose_check.toggled.connect(func(pressed: bool):
			if _settings_manager:
				_settings_manager.set_setting("interface", "prompt_bar_autoclose", pressed, true)
		)

	mouse_sens_slider.value_changed.connect(func(val):
		mouse_sens_val_label.text = "%.4f" % val
		if _settings_manager:
			_settings_manager.set_mouse_sensitivity(val)
	)
	invert_y_check.toggled.connect(func(pressed):
		if _settings_manager:
			_settings_manager.set_invert_y(pressed)
	)
	move_speed_slider.value_changed.connect(func(val):
		move_speed_val_label.text = "%.1f m/s" % val
		if _settings_manager:
			_settings_manager.set_move_speed(val)
	)

	master_vol_slider.value_changed.connect(func(val):
		master_vol_val_label.text = "%d%%" % int(val * 100.0)
		if _settings_manager:
			_settings_manager.set_master_volume(val)
	)

	save_settings_btn.pressed.connect(_on_save_settings_pressed)

	if is_instance_valid(host_session_btn):
		host_session_btn.pressed.connect(_on_host_session_pressed)
	if is_instance_valid(connect_session_btn):
		connect_session_btn.pressed.connect(_on_connect_session_pressed)
	if is_instance_valid(disconnect_session_btn):
		disconnect_session_btn.pressed.connect(_on_disconnect_session_pressed)
	if is_instance_valid(refresh_lan_btn):
		refresh_lan_btn.pressed.connect(func(): update_lan_peers())
	if is_instance_valid(offer_module_btn):
		offer_module_btn.pressed.connect(_on_offer_module_pressed)

func _on_space_error(message: String) -> void:
	if current_space_label:
		current_space_label.text = "ОШИБКА ПРОСТРАНСТВА: %s" % message.to_upper()
		current_space_label.modulate = CyberTheme.COLOR_RED_LED

func _unhandled_input(event: InputEvent) -> void:
	if _key_capture_modal and _key_capture_modal.visible:
		if event is InputEventKey and event.is_pressed() and not event.is_echo():
			var kc: int = event.keycode if event.keycode != 0 else event.physical_keycode
			_handle_captured_key(kc)
			get_viewport().set_input_as_handled()
			return

	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_ESCAPE:
			if is_open:
				close()
				get_viewport().set_input_as_handled()

func toggle() -> void:
	if is_open:
		close()
	else:
		open()

func open(target_tab: String = "") -> void:
	is_open = true
	show()
	if DisplayServer.has_feature(DisplayServer.FEATURE_MOUSE):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if not target_tab.is_empty():
		match target_tab.to_lower():
			"spaces":
				tab_container.current_tab = 0
			"settings":
				tab_container.current_tab = 1
			"library", "gallery":
				tab_container.current_tab = 2
				if module_gallery and module_gallery.has_method("refresh_gallery"):
					module_gallery.refresh_gallery()
			"modules":
				tab_container.current_tab = 3
			"network", "net":
				tab_container.current_tab = 4
				update_network_ui()
			"about", "system":
				tab_container.current_tab = 5
			_:
				tab_container.current_tab = 0

	_refresh_spaces_ui()
	_refresh_modules_ui()
	_load_settings_into_ui()
	_refresh_keybindings_ui()
	if _event_bus:
		_event_bus.emit("modal_opened", {"source": "main_menu"})
	menu_opened.emit()

func close() -> void:
	is_open = false
	hide()
	new_space_form.hide()
	save_as_form.hide()
	_close_key_capture()
	if _event_bus:
		_event_bus.emit("modal_closed", {"source": "main_menu"})
	menu_closed.emit()

func _on_space_loaded(_data: Dictionary) -> void:
	_refresh_spaces_ui()
	_refresh_modules_ui()

func _on_space_list_updated(_spaces: Array) -> void:
	_refresh_spaces_ui()

func _refresh_spaces_ui() -> void:
	if not _space_manager or not is_instance_valid(current_space_label):
		return

	var current_name: String = _space_manager.current_space_name
	var current_id: String = _space_manager.current_space_id
	var mod_count: int = 0
	if _module_manager:
		mod_count = _module_manager.get_active_module_ids().size()

	current_space_label.text = "ТЕКУЩЕЕ ПРОСТРАНСТВО: %s (ID: %s) | АКТИВНЫХ МОДУЛЕЙ: %d" % [current_name.to_upper(), current_id, mod_count]

	# Очистка списка
	for child in spaces_list_container.get_children():
		child.queue_free()

	var spaces: Array[Dictionary] = _space_manager.list_spaces()
	var is_white := CyberTheme.is_white_theme()
	for s_info in spaces:
		var sid: String = s_info.get("id", "")
		var sname: String = s_info.get("name", "Unnamed")
		var sdate: String = s_info.get("updated_at", "")
		var smods: int = s_info.get("module_count", 0)
		var stemplate: String = s_info.get("template", "custom")
		var is_current: bool = (sid == current_id)

		var card := PanelContainer.new()
		var card_border := (CyberTheme.COLOR_ELECTRIC_BLUE if is_white else CyberTheme.COLOR_CYAN_GLOW) if is_current else (Color(0.0, 0.45, 0.85, 0.3) if is_white else Color(0.0, 0.6, 0.8, 0.3))
		var card_bg := Color(0.93, 0.96, 0.99, 0.9) if is_white else Color(0.05, 0.09, 0.16, 0.85)
		var card_style := CyberTheme.create_glass_panel_style(
			card_border,
			card_bg,
			1,
			4
		)
		card.add_theme_stylebox_override("panel", card_style)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)

		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var title_lbl := Label.new()
		title_lbl.text = sname + (" [АКТИВНО]" if is_current else "")
		var title_color := (CyberTheme.COLOR_ELECTRIC_BLUE if is_white else CyberTheme.COLOR_CYAN_GLOW) if is_current else (CyberTheme.COLOR_TEXT_DARK if is_white else CyberTheme.COLOR_TEXT_PRIMARY)
		title_lbl.add_theme_color_override("font_color", title_color)
		title_lbl.add_theme_font_size_override("font_size", 14)
		info_vbox.add_child(title_lbl)

		var meta_lbl := Label.new()
		meta_lbl.text = "Шаблон: %s | Модулей: %d | Изменено: %s" % [stemplate, smods, sdate]
		meta_lbl.add_theme_color_override("font_color", CyberTheme.get_text_muted_color())
		meta_lbl.add_theme_font_size_override("font_size", 11)
		info_vbox.add_child(meta_lbl)

		hbox.add_child(info_vbox)

		# Кнопка Загрузить
		var load_btn := Button.new()
		load_btn.text = "ЗАГРУЗИТЬ"
		load_btn.disabled = is_current
		load_btn.custom_minimum_size = Vector2(100, 30)
		load_btn.add_theme_font_size_override("font_size", 12)
		var btn_style := CyberTheme.create_cyber_button_style(
			Color(0.85, 0.92, 0.98, 0.9) if is_white else Color(0.08, 0.16, 0.28, 0.8),
			CyberTheme.COLOR_ELECTRIC_BLUE if is_white else CyberTheme.COLOR_CYAN_GLOW,
			1,
			3
		)
		load_btn.add_theme_stylebox_override("normal", btn_style)
		load_btn.add_theme_color_override("font_color", CyberTheme.COLOR_ELECTRIC_BLUE if is_white else CyberTheme.COLOR_CYAN_GLOW)
		load_btn.pressed.connect(func():
			_space_manager.load_space(sid)
			_refresh_spaces_ui()
		)
		hbox.add_child(load_btn)

		# Кнопка Удалить
		var del_btn := Button.new()
		del_btn.text = "УДАЛИТЬ"
		del_btn.custom_minimum_size = Vector2(80, 30)
		del_btn.add_theme_font_size_override("font_size", 12)
		var del_style := CyberTheme.create_cyber_button_style(
			Color(0.96, 0.86, 0.88, 0.85) if is_white else Color(0.2, 0.05, 0.08, 0.8),
			CyberTheme.COLOR_RED_LED,
			1,
			3
		)
		del_btn.add_theme_stylebox_override("normal", del_style)
		del_btn.add_theme_color_override("font_color", CyberTheme.COLOR_RED_LED)
		del_btn.pressed.connect(func():
			_show_confirm("Удалить пространство '%s'?" % sname, func():
				_space_manager.delete_space(sid)
			)
		)
		hbox.add_child(del_btn)

		card.add_child(hbox)
		spaces_list_container.add_child(card)

func _refresh_modules_ui() -> void:
	if not _module_manager or not is_instance_valid(modules_list_container):
		return

	for child in modules_list_container.get_children():
		child.queue_free()

	var active_ids: Array = _module_manager.get_active_module_ids()
	if active_ids.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Нет загруженных модулей."
		empty_lbl.add_theme_color_override("font_color", CyberTheme.get_text_muted_color())
		modules_list_container.add_child(empty_lbl)
		return

	var is_white := CyberTheme.is_white_theme()
	for mod_id in active_ids:
		var inst: Node = _module_manager.get_module(mod_id)
		var is_enabled := true
		var mod_title: String = mod_id
		if inst and is_instance_valid(inst):
			is_enabled = (inst.process_mode != Node.PROCESS_MODE_DISABLED)
			if inst.has_method("get_module_name"):
				mod_title = inst.get_module_name()

		var card := PanelContainer.new()
		var card_style := CyberTheme.create_glass_panel_style(
			Color(0.0, 0.45, 0.85, 0.3) if is_white else Color(0.0, 0.7, 0.9, 0.3),
			Color(0.93, 0.96, 0.99, 0.9) if is_white else Color(0.04, 0.08, 0.14, 0.8),
			1,
			3
		)
		card.add_theme_stylebox_override("panel", card_style)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)

		var chk := CheckBox.new()
		chk.text = "%s (%s)" % [mod_title, mod_id]
		chk.button_pressed = is_enabled
		chk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chk.add_theme_font_size_override("font_size", 13)
		chk.add_theme_color_override("font_color", CyberTheme.COLOR_TEXT_DARK if is_white else CyberTheme.COLOR_TEXT_PRIMARY)
		chk.add_theme_color_override("font_pressed_color", CyberTheme.COLOR_ELECTRIC_BLUE if is_white else CyberTheme.COLOR_CYAN_GLOW)
		chk.toggled.connect(func(pressed: bool):
			if inst and is_instance_valid(inst):
				inst.process_mode = Node.PROCESS_MODE_INHERIT if pressed else Node.PROCESS_MODE_DISABLED
				if inst is Node3D or inst is CanvasItem:
					inst.visible = pressed
		)
		hbox.add_child(chk)

		var unload_btn := Button.new()
		unload_btn.text = "ВЫГРУЗИТЬ"
		unload_btn.custom_minimum_size = Vector2(90, 28)
		unload_btn.add_theme_font_size_override("font_size", 11)
		var u_style := CyberTheme.create_cyber_button_style(
			Color(0.96, 0.86, 0.88, 0.85) if is_white else Color(0.18, 0.08, 0.1, 0.7),
			CyberTheme.COLOR_RED_LED,
			1,
			3
		)
		unload_btn.add_theme_stylebox_override("normal", u_style)
		unload_btn.add_theme_color_override("font_color", CyberTheme.COLOR_RED_LED)
		unload_btn.pressed.connect(func():
			_module_manager.unload_module(mod_id)
		)
		hbox.add_child(unload_btn)

		card.add_child(hbox)
		modules_list_container.add_child(card)

func _load_settings_into_ui() -> void:
	if not _settings_manager:
		return

	if is_instance_valid(fullscreen_check):
		fullscreen_check.set_pressed_no_signal(bool(_settings_manager.get_setting("display", "fullscreen", false)))
	if is_instance_valid(vsync_check):
		vsync_check.set_pressed_no_signal(bool(_settings_manager.get_setting("display", "vsync", true)))

	var res_idx: int = int(_settings_manager.get_setting("display", "resolution_index", 0))
	if is_instance_valid(resolution_opt) and res_idx >= 0 and res_idx < resolution_opt.item_count:
		resolution_opt.selected = res_idx

	var fps_limit: int = int(_settings_manager.get_setting("display", "fps_limit", 0))
	if is_instance_valid(fps_opt):
		match fps_limit:
			0: fps_opt.selected = 0
			60: fps_opt.selected = 1
			120: fps_opt.selected = 2
			144: fps_opt.selected = 3
			_: fps_opt.selected = 0

	# Interface settings
	var cur_theme: String = str(_settings_manager.get_setting("interface", "theme", "cyberlife_white"))
	if is_instance_valid(interface_theme_opt):
		interface_theme_opt.selected = 0 if cur_theme == "cyberlife_white" else 1

	var cur_opacity: float = float(_settings_manager.get_setting("interface", "glass_opacity", 0.75))
	if is_instance_valid(glass_opacity_slider):
		glass_opacity_slider.set_value_no_signal(cur_opacity)
	if is_instance_valid(glass_opacity_val_label):
		glass_opacity_val_label.text = "%d%%" % int(round(cur_opacity * 100.0))

	var cur_led: float = float(_settings_manager.get_setting("interface", "led_intensity", 1.0))
	if is_instance_valid(led_intensity_slider):
		led_intensity_slider.set_value_no_signal(cur_led)
	if is_instance_valid(led_intensity_val_label):
		led_intensity_val_label.text = "%d%%" % int(round(cur_led * 100.0))

	var cur_autoclose: bool = bool(_settings_manager.get_setting("interface", "prompt_bar_autoclose", true))
	if is_instance_valid(prompt_autoclose_check):
		prompt_autoclose_check.set_pressed_no_signal(cur_autoclose)

	var sens: float = float(_settings_manager.get_setting("controls", "mouse_sensitivity", 0.002))
	if is_instance_valid(mouse_sens_slider):
		mouse_sens_slider.set_value_no_signal(sens)
	if is_instance_valid(mouse_sens_val_label):
		mouse_sens_val_label.text = "%.4f" % sens

	if is_instance_valid(invert_y_check):
		invert_y_check.set_pressed_no_signal(bool(_settings_manager.get_setting("controls", "invert_y", false)))

	var spd: float = float(_settings_manager.get_setting("controls", "move_speed", 10.0))
	if is_instance_valid(move_speed_slider):
		move_speed_slider.set_value_no_signal(spd)
	if is_instance_valid(move_speed_val_label):
		move_speed_val_label.text = "%.1f m/s" % spd

	var vol: float = float(_settings_manager.get_setting("audio", "master_volume", 0.8))
	if is_instance_valid(master_vol_slider):
		master_vol_slider.set_value_no_signal(vol)
	if is_instance_valid(master_vol_val_label):
		master_vol_val_label.text = "%d%%" % int(vol * 100.0)

	var prov: String = str(_settings_manager.get_setting("agent", "provider", "local_embedded"))
	var prov_idx: int = AGENT_PROVIDER_IDS.find(prov)
	if prov_idx == -1:
		prov_idx = 0
	if is_instance_valid(agent_provider_opt):
		agent_provider_opt.selected = prov_idx

	_current_editing_provider = AGENT_PROVIDER_IDS[prov_idx]
	_update_agent_ui_for_provider(_current_editing_provider)

	if is_instance_valid(_agent_fallback_check):
		_agent_fallback_check.set_pressed_no_signal(_settings_manager.is_auto_fallback_to_local_enabled())

	if is_instance_valid(_local_gguf_edit):
		_local_gguf_edit.text = str(_settings_manager.get_setting("agent", "local_model_path", ""))

	if is_instance_valid(_agent_custom_url_edit):
		_agent_custom_url_edit.text = str(_settings_manager.get_setting("agent", "custom_base_url", ""))

func _on_save_settings_pressed() -> void:
	if not _settings_manager:
		return

	var idx: int = agent_provider_opt.selected if is_instance_valid(agent_provider_opt) else 0
	var selected_prov: String = AGENT_PROVIDER_IDS[idx] if idx >= 0 and idx < AGENT_PROVIDER_IDS.size() else "local_embedded"

	var cur_model: String = agent_model_edit.text.strip_edges() if is_instance_valid(agent_model_edit) else ""
	var cur_key: String = agent_key_edit.text.strip_edges() if is_instance_valid(agent_key_edit) else ""

	# 1. Save active provider, model, key
	_settings_manager.set_agent_config(selected_prov, cur_model, cur_key)
	_settings_manager.set_agent_api_key(selected_prov, cur_key)
	_settings_manager.set_agent_model(selected_prov, cur_model)

	# 2. Save custom base URL if set
	if is_instance_valid(_agent_custom_url_edit):
		_settings_manager.set_setting("agent", "custom_base_url", _agent_custom_url_edit.text.strip_edges(), false)

	# 3. Save local model path if set
	if is_instance_valid(_local_gguf_edit):
		var p: String = _local_gguf_edit.text.strip_edges()
		_settings_manager.set_setting("agent", "local_model_path", p, false)
		var mgr := _find_local_llm_manager()
		if mgr and mgr.has_method("set_custom_model_path"):
			mgr.call("set_custom_model_path", p)

	# 4. Save fallback flag
	if is_instance_valid(_agent_fallback_check):
		_settings_manager.set_auto_fallback_to_local(_agent_fallback_check.button_pressed)

	_settings_manager.save_settings()
	_settings_manager.apply_all_settings()

	# Visual Detroit confirmation toast on the button
	if is_instance_valid(save_settings_btn):
		var orig_text: String = save_settings_btn.text
		save_settings_btn.text = "✓ НАСТРОЙКИ УСПЕШНО СОХРАНЕНЫ"
		save_settings_btn.modulate = CyberTheme.COLOR_SUCCESS_LED
		var t := create_tween()
		t.tween_interval(1.8)
		t.tween_property(save_settings_btn, "modulate", Color.WHITE, 0.4)
		t.tween_callback(func():
			if is_instance_valid(save_settings_btn):
				save_settings_btn.text = orig_text
		)

func _on_setting_changed(category: String, key: String, value: Variant) -> void:
	if category == "display":
		if key == "fullscreen" and is_instance_valid(fullscreen_check):
			fullscreen_check.set_pressed_no_signal(bool(value))
		elif key == "vsync" and is_instance_valid(vsync_check):
			vsync_check.set_pressed_no_signal(bool(value))
		elif key == "resolution_index" and is_instance_valid(resolution_opt):
			var idx: int = int(value)
			if idx >= 0 and idx < resolution_opt.item_count:
				resolution_opt.selected = idx
		elif key == "fps_limit" and is_instance_valid(fps_opt):
			match int(value):
				0: fps_opt.selected = 0
				60: fps_opt.selected = 1
				120: fps_opt.selected = 2
				144: fps_opt.selected = 3
				_: fps_opt.selected = 0
	elif category == "controls":
		if key == "mouse_sensitivity" and is_instance_valid(mouse_sens_slider):
			var sens: float = float(value)
			mouse_sens_slider.set_value_no_signal(sens)
			if is_instance_valid(mouse_sens_val_label):
				mouse_sens_val_label.text = "%.4f" % sens
		elif key == "invert_y" and is_instance_valid(invert_y_check):
			invert_y_check.set_pressed_no_signal(bool(value))
		elif key == "move_speed" and is_instance_valid(move_speed_slider):
			var spd: float = float(value)
			move_speed_slider.set_value_no_signal(spd)
			if is_instance_valid(move_speed_val_label):
				move_speed_val_label.text = "%.1f m/s" % spd
	elif category == "audio":
		if key == "master_volume" and is_instance_valid(master_vol_slider):
			var vol: float = float(value)
			master_vol_slider.set_value_no_signal(vol)
			if is_instance_valid(master_vol_val_label):
				master_vol_val_label.text = "%d%%" % int(vol * 100.0)
	elif category == "interface":
		if key == "theme" and is_instance_valid(interface_theme_opt):
			var th_str: String = str(value)
			interface_theme_opt.selected = 0 if th_str == "cyberlife_white" else 1
			_apply_styling()
		elif key == "glass_opacity" and is_instance_valid(glass_opacity_slider):
			var op_val: float = float(value)
			glass_opacity_slider.set_value_no_signal(op_val)
			if is_instance_valid(glass_opacity_val_label):
				glass_opacity_val_label.text = "%d%%" % int(round(op_val * 100.0))
			_apply_styling()
		elif key == "led_intensity" and is_instance_valid(led_intensity_slider):
			var led_val: float = float(value)
			led_intensity_slider.set_value_no_signal(led_val)
			if is_instance_valid(led_intensity_val_label):
				led_intensity_val_label.text = "%d%%" % int(round(led_val * 100.0))
			_apply_styling()
		elif key == "prompt_bar_autoclose" and is_instance_valid(prompt_autoclose_check):
			prompt_autoclose_check.set_pressed_no_signal(bool(value))
	elif category == "agent":
		if key == "provider" and is_instance_valid(agent_provider_opt):
			var prov_idx: int = AGENT_PROVIDER_IDS.find(str(value))
			if prov_idx != -1:
				agent_provider_opt.selected = prov_idx
				_current_editing_provider = str(value)
				_update_agent_ui_for_provider(_current_editing_provider)
		elif key == "model" and is_instance_valid(agent_model_edit):
			agent_model_edit.text = str(value)
		elif key == "api_key" and is_instance_valid(agent_key_edit):
			agent_key_edit.text = str(value)
		elif key == "auto_fallback_to_local" and is_instance_valid(_agent_fallback_check):
			_agent_fallback_check.set_pressed_no_signal(bool(value))
		elif key == "custom_base_url" and is_instance_valid(_agent_custom_url_edit):
			_agent_custom_url_edit.text = str(value)
		elif key == "local_model_path" and is_instance_valid(_local_gguf_edit):
			_local_gguf_edit.text = str(value)

func _on_create_space_clicked() -> void:
	if not _space_manager:
		return

	var sname: String = new_space_name_edit.text.strip_edges()
	if sname.is_empty():
		sname = "New Space"

	var template_map := ["default", "cyber_void", "clean_slate", "tool_studio"]
	var t_idx: int = new_space_template_opt.selected
	var template_type: String = template_map[t_idx] if t_idx < template_map.size() else "default"

	_space_manager.create_new_space(sname, template_type)
	new_space_form.hide()
	new_space_name_edit.text = ""
	_refresh_spaces_ui()

func _on_save_as_clicked() -> void:
	if not _space_manager:
		return

	var new_name: String = save_as_name_edit.text.strip_edges()
	if not new_name.is_empty():
		_space_manager.save_space_as(new_name)
		save_as_form.hide()
		_refresh_spaces_ui()

func _on_quit_pressed() -> void:
	_show_confirm("Вы действительно хотите выйти из UniCORE?", func():
		get_tree().quit()
	)

func _show_confirm(text: String, on_ok: Callable) -> void:
	confirm_dialog.dialog_text = text
	# Disconnect any previous ok connections
	for conn in confirm_dialog.confirmed.get_connections():
		confirm_dialog.confirmed.disconnect(conn.callable)
	confirm_dialog.confirmed.connect(on_ok, CONNECT_ONE_SHOT)
	confirm_dialog.popup_centered()

func _apply_styling() -> void:
	var is_white := CyberTheme.is_white_theme()

	# Фоновый полупрозрачный блюр-оверлей (высокая плотность для предотвращения просвечивания текста стартового меню)
	if is_white:
		modal_backdrop.color = Color(0.92, 0.94, 0.97, 0.92)
	else:
		modal_backdrop.color = Color(0.01, 0.02, 0.05, 0.85)

	# Главная панель в стиле Detroit Liquid Glass
	var main_style := CyberTheme.create_glass_panel_style(
		CyberTheme.COLOR_CYAN_GLOW if not is_white else CyberTheme.COLOR_ELECTRIC_BLUE,
		Color(-1, -1, -1, -1),
		2,
		6,
		int(round(6 * CyberTheme.get_led_intensity()))
	)
	main_panel.add_theme_stylebox_override("panel", main_style)

	var subpanel_style := CyberTheme.create_glass_panel_style(
		CyberTheme.COLOR_ELECTRIC_BLUE if is_white else Color(0.0, 0.75, 1.0, 0.4),
		Color(-1, -1, -1, -1),
		1,
		4,
		int(round(4 * CyberTheme.get_led_intensity()))
	)
	new_space_form.add_theme_stylebox_override("panel", subpanel_style)
	save_as_form.add_theme_stylebox_override("panel", subpanel_style)

	# Применение кибер-темы к TabContainer
	tab_container.theme = CyberTheme.build_theme()

	# Шапка окна (Title & Subtitle)
	var header_title: Label = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/HeaderHBox/TitleLabel") as Label
	if header_title:
		header_title.add_theme_color_override("font_color", CyberTheme.COLOR_ELECTRIC_BLUE if is_white else CyberTheme.COLOR_CYAN_GLOW)
	var header_sub: Label = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/HeaderHBox/SubLabel") as Label
	if header_sub:
		header_sub.add_theme_color_override("font_color", CyberTheme.get_text_muted_color())

	# Кнопка закрытия (Header Close Button)
	var close_btn_style := CyberTheme.create_cyber_button_style(
		Color(0.95, 0.85, 0.85, 0.8) if is_white else Color(0.18, 0.05, 0.08, 0.7),
		CyberTheme.COLOR_RED_LED,
		1,
		3
	)
	var close_btn_hover := CyberTheme.create_cyber_button_style(
		Color(1.0, 0.8, 0.8, 0.95) if is_white else Color(0.35, 0.08, 0.12, 0.95),
		Color(1.0, 0.4, 0.4, 1.0),
		1,
		3
	)
	close_btn.add_theme_stylebox_override("normal", close_btn_style)
	close_btn.add_theme_stylebox_override("hover", close_btn_hover)
	close_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	close_btn.add_theme_color_override("font_color", CyberTheme.COLOR_RED_LED if is_white else Color.WHITE)

	# Кнопки действий Пространств
	var action_btn_style := CyberTheme.create_cyber_button_style(
		Color(0.85, 0.91, 0.98, CyberTheme.get_glass_opacity()) if is_white else Color(0.06, 0.12, 0.22, 0.8),
		CyberTheme.COLOR_ELECTRIC_BLUE if is_white else Color(0.0, 0.7, 0.9, 0.4),
		1,
		3
	)
	var action_btn_hover := CyberTheme.create_cyber_button_style(
		Color(0.78, 0.88, 0.98, min(CyberTheme.get_glass_opacity() + 0.1, 1.0)) if is_white else Color(0.09, 0.18, 0.32, 0.95),
		CyberTheme.COLOR_CYAN_GLOW,
		1,
		3
	)
	for b in [btn_show_new_space, btn_quick_save, btn_show_save_as]:
		b.add_theme_stylebox_override("normal", action_btn_style)
		b.add_theme_stylebox_override("hover", action_btn_hover)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.add_theme_color_override("font_color", CyberTheme.COLOR_TEXT_DARK if is_white else CyberTheme.COLOR_TEXT_PRIMARY)
		b.add_theme_color_override("font_hover_color", CyberTheme.COLOR_ELECTRIC_BLUE if is_white else CyberTheme.COLOR_CYAN_GLOW)
		b.add_theme_font_size_override("font_size", 12)

	# Кнопки диалогов Пространств (Создать / Сохранить / Отмена)
	for fb in [new_space_create_btn, new_space_cancel_btn, save_as_confirm_btn, save_as_cancel_btn]:
		if is_instance_valid(fb):
			var is_create: bool = (fb == new_space_create_btn or fb == save_as_confirm_btn)
			var b_norm := CyberTheme.create_cyber_button_style(
				(Color(0.85, 0.92, 0.98, 0.9) if is_white else Color(0.08, 0.16, 0.28, 0.8)) if is_create else (Color(0.95, 0.88, 0.9, 0.85) if is_white else Color(0.18, 0.08, 0.1, 0.7)),
				CyberTheme.COLOR_ELECTRIC_BLUE if (is_create and is_white) else (CyberTheme.COLOR_CYAN_GLOW if is_create else CyberTheme.COLOR_RED_LED),
				1,
				3
			)
			fb.add_theme_stylebox_override("normal", b_norm)
			fb.add_theme_color_override("font_color", (CyberTheme.COLOR_ELECTRIC_BLUE if is_white else CyberTheme.COLOR_CYAN_GLOW) if is_create else CyberTheme.COLOR_RED_LED)

	# Заголовки вкладки Пространств
	if is_instance_valid(current_space_label):
		current_space_label.add_theme_color_override("font_color", CyberTheme.COLOR_ELECTRIC_BLUE if is_white else CyberTheme.COLOR_CYAN_GLOW)
	var list_hdr: Label = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/TabContainer/SpacesTab/VBox/ListHeader") as Label
	if list_hdr:
		list_hdr.add_theme_color_override("font_color", CyberTheme.COLOR_ELECTRIC_BLUE if is_white else Color(0.5, 0.75, 1, 1))
	var new_sp_title: Label = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/TabContainer/SpacesTab/VBox/NewSpaceForm/VBox/FormTitle") as Label
	if new_sp_title:
		new_sp_title.add_theme_color_override("font_color", CyberTheme.COLOR_ELECTRIC_BLUE if is_white else Color(0.2, 0.8, 1, 1))
	var save_as_title: Label = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/TabContainer/SpacesTab/VBox/SaveAsForm/VBox/FormTitle") as Label
	if save_as_title:
		save_as_title.add_theme_color_override("font_color", CyberTheme.COLOR_ELECTRIC_BLUE if is_white else Color(0.2, 0.8, 1, 1))

	# Секционные заголовки настроек
	for hdr_path in [
		"MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/DisplayHeader",
		"MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/InterfaceHeader",
		"MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/ControlsHeader",
		"MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/AudioHeader",
		"MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/AgentHeader"
	]:
		var hdr: Label = get_node_or_null(hdr_path) as Label
		if hdr:
			hdr.add_theme_color_override("font_color", CyberTheme.COLOR_ELECTRIC_BLUE if is_white else CyberTheme.COLOR_CYAN_GLOW)

	# Вкладка "О системе" (About)
	var about_title: Label = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/TabContainer/AboutTab/Scroll/VBox/AboutTitle") as Label
	if about_title:
		about_title.add_theme_color_override("font_color", CyberTheme.COLOR_ELECTRIC_BLUE if is_white else CyberTheme.COLOR_CYAN_GLOW)
	var about_desc: Label = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/TabContainer/AboutTab/Scroll/VBox/AboutDesc") as Label
	if about_desc:
		about_desc.add_theme_color_override("font_color", CyberTheme.get_text_primary_color())
	var keys_title: Label = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/TabContainer/AboutTab/Scroll/VBox/KeysTitle") as Label
	if keys_title:
		keys_title.add_theme_color_override("font_color", CyberTheme.COLOR_ELECTRIC_BLUE if is_white else CyberTheme.COLOR_CYAN_GLOW)
	var keys_grid: GridContainer = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/TabContainer/AboutTab/Scroll/VBox/KeysGrid") as GridContainer
	if keys_grid:
		for child in keys_grid.get_children():
			if child is Label:
				if child.name.begins_with("K"):
					child.add_theme_color_override("font_color", CyberTheme.COLOR_ELECTRIC_BLUE if is_white else Color(0.4, 0.85, 1, 1))
				else:
					child.add_theme_color_override("font_color", CyberTheme.get_text_primary_color())

	# Заголовки секций вкладки "Сеть"
	for net_title_path in [
		"MainPanel/MarginContainer/VBoxContainer/TabContainer/NetworkTab/Scroll/VBox/SessionSection/VBox/HeaderHBox/Title",
		"MainPanel/MarginContainer/VBoxContainer/TabContainer/NetworkTab/Scroll/VBox/LanSection/VBox/HeaderHBox/Title",
		"MainPanel/MarginContainer/VBoxContainer/TabContainer/NetworkTab/Scroll/VBox/SharingSection/VBox/HeaderHBox/Title"
	]:
		var n_lbl: Label = get_node_or_null(net_title_path) as Label
		if n_lbl:
			n_lbl.add_theme_color_override("font_color", CyberTheme.COLOR_ELECTRIC_BLUE if is_white else CyberTheme.COLOR_CYAN_GLOW)

	# Стилизация полей ввода
	for le in [new_space_name_edit, save_as_name_edit, agent_model_edit, agent_key_edit, session_ip_port_edit, _agent_custom_url_edit, _local_gguf_edit]:
		if is_instance_valid(le):
			le.add_theme_stylebox_override("normal", CyberTheme.create_input_style(false))
			le.add_theme_stylebox_override("focus", CyberTheme.create_input_style(true))
			le.add_theme_color_override("font_color", CyberTheme.get_text_primary_color())
			le.add_theme_color_override("placeholder_color", CyberTheme.get_text_muted_color())

	# Стилизация панелей и элементов расширенной секции ИИ-агента
	if is_instance_valid(_agent_zero_key_panel):
		var z_style := CyberTheme.create_glass_panel_style(
			CyberTheme.COLOR_ELECTRIC_BLUE if is_white else CyberTheme.COLOR_CYAN_GLOW,
			Color(0.92, 0.96, 1.0, 0.85) if is_white else Color(0.02, 0.08, 0.16, 0.65),
			1, 4, 6
		)
		_agent_zero_key_panel.add_theme_stylebox_override("panel", z_style)

	if is_instance_valid(_agent_local_card):
		var c_style := CyberTheme.create_glass_panel_style(
			Color(0.2, 0.55, 0.88, 0.5) if is_white else Color(0.0, 0.75, 1.0, 0.4),
			Color(0.92, 0.95, 0.99, 0.9) if is_white else Color(0.03, 0.06, 0.12, 0.8),
			1, 4, 10
		)
		_agent_local_card.add_theme_stylebox_override("panel", c_style)

	var sub_btn_norm := CyberTheme.create_cyber_button_style(
		Color(0.85, 0.92, 0.99, 0.8) if is_white else Color(0.06, 0.1, 0.16, 0.7),
		CyberTheme.COLOR_ELECTRIC_BLUE if is_white else CyberTheme.COLOR_CYAN_GLOW,
		1, 2
	)
	var sub_btn_hov := CyberTheme.create_cyber_button_style(
		Color(0.75, 0.88, 0.99, 0.95) if is_white else Color(0.08, 0.16, 0.26, 0.85),
		CyberTheme.COLOR_CYAN_GLOW if is_white else Color.WHITE,
		1, 2
	)
	for b in [_local_gguf_browse_btn, _local_gguf_clear_btn]:
		if is_instance_valid(b):
			b.add_theme_stylebox_override("normal", sub_btn_norm)
			b.add_theme_stylebox_override("hover", sub_btn_hov)
			b.add_theme_stylebox_override("pressed", sub_btn_hov)
			b.add_theme_color_override("font_color", CyberTheme.get_text_primary_color())

	if is_instance_valid(_agent_fallback_check):
		_agent_fallback_check.add_theme_color_override("font_color", CyberTheme.get_text_primary_color())

	if is_instance_valid(_toggle_key_vis_btn):
		_toggle_key_vis_btn.add_theme_color_override("font_color", CyberTheme.COLOR_ELECTRIC_BLUE if is_white else CyberTheme.COLOR_CYAN_GLOW)

	# Кнопка сохранения настроек
	var save_btn_style := CyberTheme.create_cyber_button_style(
		Color(0.8, 0.9, 0.98, 0.9) if is_white else Color(0.0, 0.3, 0.5, 0.85),
		CyberTheme.COLOR_ELECTRIC_BLUE if is_white else CyberTheme.COLOR_CYAN_GLOW,
		1,
		4
	)
	var save_btn_hover := CyberTheme.create_cyber_button_style(
		Color(0.7, 0.85, 0.98, 0.98) if is_white else Color(0.0, 0.45, 0.75, 0.95),
		CyberTheme.COLOR_CYAN_GLOW if is_white else Color.WHITE,
		2,
		4
	)
	save_settings_btn.add_theme_stylebox_override("normal", save_btn_style)
	save_settings_btn.add_theme_stylebox_override("hover", save_btn_hover)
	save_settings_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	save_settings_btn.add_theme_color_override("font_color", CyberTheme.COLOR_ELECTRIC_BLUE if is_white else CyberTheme.COLOR_CYAN_GLOW)
	save_settings_btn.add_theme_color_override("font_hover_color", CyberTheme.COLOR_CYAN_GLOW if is_white else Color.WHITE)

	# Стили кнопок футера
	var resume_style := CyberTheme.create_cyber_button_style(
		Color(0.8, 0.9, 0.98, 0.9) if is_white else Color(0.0, 0.35, 0.55, 0.85),
		CyberTheme.COLOR_ELECTRIC_BLUE if is_white else CyberTheme.COLOR_CYAN_GLOW,
		1,
		4
	)
	var resume_hover := CyberTheme.create_cyber_button_style(
		Color(0.7, 0.85, 0.98, 0.98) if is_white else Color(0.0, 0.5, 0.8, 0.95),
		CyberTheme.COLOR_CYAN_GLOW if is_white else Color.WHITE,
		2,
		4
	)
	resume_btn.add_theme_stylebox_override("normal", resume_style)
	resume_btn.add_theme_stylebox_override("hover", resume_hover)
	resume_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	resume_btn.add_theme_color_override("font_color", CyberTheme.COLOR_ELECTRIC_BLUE if is_white else Color.WHITE)

	var quit_style := CyberTheme.create_cyber_button_style(
		Color(0.96, 0.86, 0.88, 0.8) if is_white else Color(0.2, 0.06, 0.08, 0.75),
		CyberTheme.COLOR_RED_LED,
		1,
		4
	)
	var quit_hover := CyberTheme.create_cyber_button_style(
		Color(1.0, 0.8, 0.84, 0.95) if is_white else Color(0.38, 0.08, 0.12, 0.95),
		Color(1.0, 0.4, 0.4, 1.0),
		2,
		4
	)
	quit_btn.add_theme_stylebox_override("normal", quit_style)
	quit_btn.add_theme_stylebox_override("hover", quit_hover)
	quit_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	quit_btn.add_theme_color_override("font_color", CyberTheme.COLOR_RED_LED if is_white else Color.WHITE)

	if title_screen_btn:
		var title_btn_style := CyberTheme.create_cyber_button_style(
			Color(0.88, 0.92, 0.96, 0.8) if is_white else Color(0.08, 0.12, 0.16, 0.75),
			CyberTheme.COLOR_ELECTRIC_BLUE if is_white else CyberTheme.COLOR_CYAN_GLOW,
			1,
			4
		)
		var title_btn_hover := CyberTheme.create_cyber_button_style(
			Color(0.92, 0.96, 1.0, 0.95) if is_white else Color(0.12, 0.2, 0.28, 0.9),
			CyberTheme.COLOR_CYAN_GLOW,
			2,
			4
		)
		title_screen_btn.add_theme_stylebox_override("normal", title_btn_style)
		title_screen_btn.add_theme_stylebox_override("hover", title_btn_hover)
		title_screen_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		title_screen_btn.add_theme_color_override("font_color", CyberTheme.COLOR_ELECTRIC_BLUE if is_white else Color.WHITE)

	# Network Buttons Styling
	var net_btn_style := CyberTheme.create_cyber_button_style(
		Color(0.85, 0.91, 0.98, CyberTheme.get_glass_opacity()) if is_white else Color(0.06, 0.12, 0.22, 0.8),
		CyberTheme.COLOR_ELECTRIC_BLUE if is_white else Color(0.0, 0.7, 0.9, 0.4),
		1,
		3
	)
	var net_btn_hover := CyberTheme.create_cyber_button_style(
		Color(0.78, 0.88, 0.98, min(CyberTheme.get_glass_opacity() + 0.1, 1.0)) if is_white else Color(0.09, 0.18, 0.32, 0.95),
		CyberTheme.COLOR_CYAN_GLOW,
		1,
		3
	)
	for b in [host_session_btn, connect_session_btn, disconnect_session_btn, refresh_lan_btn, offer_module_btn]:
		if is_instance_valid(b):
			b.add_theme_stylebox_override("normal", net_btn_style)
			b.add_theme_stylebox_override("hover", net_btn_hover)
			b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
			b.add_theme_color_override("font_color", CyberTheme.COLOR_TEXT_DARK if is_white else CyberTheme.COLOR_TEXT_PRIMARY)
			b.add_theme_color_override("font_hover_color", CyberTheme.COLOR_ELECTRIC_BLUE if is_white else CyberTheme.COLOR_CYAN_GLOW)
			b.add_theme_font_size_override("font_size", 12)

# ----------------------------------------------------
# Network Layer Integration & Handlers
# ----------------------------------------------------

func setup_network(transport: Node, discovery: Node, sharing: Node = null, sync: Node = null, state_machine: Node = null, presence: Node = null, chat: Node = null) -> void:
	_network_transport = transport
	_lan_discovery = discovery
	_module_sharing = sharing
	_space_sync = sync
	if state_machine:
		_space_state_machine = state_machine
	if presence:
		_presence_manager = presence
	if chat:
		_peer_chat = chat

	if _network_transport:
		if not _network_transport.connection_status_changed.is_connected(update_network_ui):
			_network_transport.connection_status_changed.connect(update_network_ui)
		if not _network_transport.peer_connected.is_connected(_on_peer_connected_event):
			_network_transport.peer_connected.connect(_on_peer_connected_event)
		if not _network_transport.peer_disconnected.is_connected(_on_peer_disconnected_event):
			_network_transport.peer_disconnected.connect(_on_peer_disconnected_event)

	if _lan_discovery:
		if not _lan_discovery.peer_discovered.is_connected(update_lan_peers):
			_lan_discovery.peer_discovered.connect(update_lan_peers)
		if not _lan_discovery.peer_lost.is_connected(update_lan_peers):
			_lan_discovery.peer_lost.connect(update_lan_peers)

	if _module_sharing:
		if not _module_sharing.module_offered.is_connected(add_module_offer):
			_module_sharing.module_offered.connect(add_module_offer)

	if _presence_manager:
		if not _presence_manager.peer_state_updated.is_connected(update_presence_ui):
			_presence_manager.peer_state_updated.connect(update_presence_ui)
		if not _presence_manager.peer_left_presence.is_connected(update_presence_ui):
			_presence_manager.peer_left_presence.connect(update_presence_ui)

	if _space_state_machine:
		if not _space_state_machine.operation_applied.is_connected(update_ops_log_ui):
			_space_state_machine.operation_applied.connect(update_ops_log_ui)

	update_network_ui()
	update_presence_ui()
	update_ops_log_ui()

func setup_multiplayer(state_machine: Node, presence: Node, chat: Node) -> void:
	_space_state_machine = state_machine
	_presence_manager = presence
	_peer_chat = chat
	if _presence_manager:
		if not _presence_manager.peer_state_updated.is_connected(update_presence_ui):
			_presence_manager.peer_state_updated.connect(update_presence_ui)
		if not _presence_manager.peer_left_presence.is_connected(update_presence_ui):
			_presence_manager.peer_left_presence.connect(update_presence_ui)
	if _space_state_machine:
		if not _space_state_machine.operation_applied.is_connected(update_ops_log_ui):
			_space_state_machine.operation_applied.connect(update_ops_log_ui)
	update_presence_ui()
	update_ops_log_ui()

func _on_peer_connected_event(_pid: int, _info: Dictionary) -> void:
	_refresh_connected_peers()
	if is_instance_valid(session_status_label) and _network_transport:
		update_network_ui(_network_transport.get_status())

func _on_peer_disconnected_event(_pid: int) -> void:
	_refresh_connected_peers()
	if is_instance_valid(session_status_label) and _network_transport:
		update_network_ui(_network_transport.get_status())

func _on_host_session_pressed() -> void:
	if not _network_transport:
		return
	if _network_transport.is_hosting():
		_network_transport.disconnect_session()
		if _lan_discovery:
			_lan_discovery.stop_broadcasting()
	else:
		var port: int = int(_settings_manager.get_setting("network", "host_port", 7777)) if _settings_manager else 7777
		var err: int = int(_network_transport.host_session(port))
		if err == OK:
			if _lan_discovery and bool(_settings_manager.get_setting("network", "auto_discovery", true) if _settings_manager else true):
				_lan_discovery.start_broadcasting(int(_settings_manager.get_setting("network", "discovery_port", 7778) if _settings_manager else 7778))
	update_network_ui()

func _on_connect_session_pressed() -> void:
	if not _network_transport:
		return
	if _lan_discovery and _network_transport.is_hosting():
		_lan_discovery.stop_broadcasting()
	var text: String = session_ip_port_edit.text.strip_edges() if is_instance_valid(session_ip_port_edit) else "127.0.0.1:7777"
	var addr: String = "127.0.0.1"
	var port: int = int(_settings_manager.get_setting("network", "host_port", 7777)) if _settings_manager else 7777
	if text.contains(":"):
		var parts := text.split(":")
		addr = parts[0].strip_edges()
		if addr.is_empty():
			addr = "127.0.0.1"
		if parts.size() > 1 and parts[1].is_valid_int():
			port = int(parts[1])
	elif not text.is_empty():
		addr = text
	_network_transport.join_session(addr, port)
	update_network_ui()

func _on_disconnect_session_pressed() -> void:
	if _network_transport:
		_network_transport.disconnect_session()
	if _lan_discovery:
		_lan_discovery.stop_broadcasting()
	update_network_ui()

func update_network_ui(_status_str: String = "") -> void:
	var cur_status: String = _network_transport.get_status() if _network_transport else "disconnected"
	var peer_count: int = _network_transport.get_connected_peers().size() if _network_transport else 0

	if cur_status.to_lower() == "disconnected" and _lan_discovery and _lan_discovery.is_broadcasting():
		_lan_discovery.stop_broadcasting()

	if is_instance_valid(session_status_label):
		match cur_status.to_lower():
			"hosting":
				session_status_label.text = "СТАТУС: ХОСТ (УЗЛОВ: %d)" % peer_count
				session_status_label.modulate = CyberTheme.COLOR_CYAN_GLOW
				if is_instance_valid(host_session_btn):
					host_session_btn.text = "ОСТАНОВИТЬ ХОСТ"
				if is_instance_valid(disconnect_session_btn):
					disconnect_session_btn.visible = true
			"connected":
				session_status_label.text = "СТАТУС: ПОДКЛЮЧЕН (УЗЛОВ: %d)" % peer_count
				session_status_label.modulate = CyberTheme.COLOR_SUCCESS_LED
				if is_instance_valid(host_session_btn):
					host_session_btn.text = "СОЗДАТЬ СЕССИЮ (ХОСТ)"
				if is_instance_valid(disconnect_session_btn):
					disconnect_session_btn.visible = true
			"connecting":
				session_status_label.text = "СТАТУС: ПОДКЛЮЧЕНИЕ..."
				session_status_label.modulate = CyberTheme.COLOR_AMBER_LED
				if is_instance_valid(disconnect_session_btn):
					disconnect_session_btn.visible = true
			_:
				session_status_label.text = "СТАТУС: OFFLINE"
				session_status_label.modulate = CyberTheme.get_text_muted_color()
				if is_instance_valid(host_session_btn):
					host_session_btn.text = "СОЗДАТЬ СЕССИЮ (ХОСТ)"
				if is_instance_valid(disconnect_session_btn):
					disconnect_session_btn.visible = false

	_refresh_connected_peers()
	update_lan_peers()
	_refresh_module_offers_ui()

func update_lan_peers(_arg: Variant = null) -> void:
	if not is_instance_valid(lan_peers_list):
		return

	for child in lan_peers_list.get_children():
		lan_peers_list.remove_child(child)
		child.queue_free()

	var peers: Array[Dictionary] = []
	if _lan_discovery:
		peers = _lan_discovery.get_discovered_peers()

	if peers.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Узлы в локальной сети не обнаружены (нажмите [ОБНОВИТЬ])."
		empty_lbl.add_theme_color_override("font_color", CyberTheme.get_text_muted_color())
		empty_lbl.add_theme_font_size_override("font_size", 12)
		lan_peers_list.add_child(empty_lbl)
		return

	var is_white := CyberTheme.is_white_theme()
	for p_info in peers:
		var card := PanelContainer.new()
		var card_style := CyberTheme.create_glass_panel_style(
			Color(0.0, 0.75, 1.0, 0.4) if not is_white else CyberTheme.COLOR_ELECTRIC_BLUE,
			Color(0.03, 0.08, 0.15, 0.75) if not is_white else Color(0.9, 0.94, 0.98, 0.9),
			1,
			3
		)
		card.add_theme_stylebox_override("panel", card_style)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)

		var p_name: String = str(p_info.get("name", "UniNode"))
		var p_addr: String = str(p_info.get("address", "127.0.0.1"))
		var p_port: int = int(p_info.get("port", 7777))
		var p_mods: int = int(p_info.get("modules_count", 0))

		var info_lbl := Label.new()
		info_lbl.text = "● %s  [%s:%d]  •  Модулей: %d" % [p_name, p_addr, p_port, p_mods]
		info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_lbl.add_theme_color_override("font_color", CyberTheme.COLOR_TEXT_CYAN if not is_white else CyberTheme.COLOR_TEXT_DARK)
		info_lbl.add_theme_font_size_override("font_size", 12)
		hbox.add_child(info_lbl)

		var conn_btn := Button.new()
		conn_btn.text = "ПОДКЛЮЧИТЬСЯ"
		conn_btn.custom_minimum_size = Vector2(110, 26)
		conn_btn.add_theme_font_size_override("font_size", 11)
		var b_style := CyberTheme.create_cyber_button_style(
			Color(0.0, 0.35, 0.55, 0.85) if not is_white else Color(0.8, 0.9, 0.98, 0.9),
			CyberTheme.COLOR_CYAN_GLOW if not is_white else CyberTheme.COLOR_ELECTRIC_BLUE,
			1,
			3
		)
		conn_btn.add_theme_stylebox_override("normal", b_style)
		conn_btn.pressed.connect(func():
			_connect_to_peer_address(p_addr, p_port)
		)
		hbox.add_child(conn_btn)

		card.add_child(hbox)
		lan_peers_list.add_child(card)

func _connect_to_peer_address(address: String, port: int) -> void:
	if is_instance_valid(session_ip_port_edit):
		session_ip_port_edit.text = "%s:%d" % [address, port]
	if _network_transport:
		_network_transport.join_session(address, port)
	update_network_ui()

func _refresh_connected_peers() -> void:
	if not is_instance_valid(connected_peers_list):
		return

	for child in connected_peers_list.get_children():
		connected_peers_list.remove_child(child)
		child.queue_free()

	if not _network_transport:
		return

	var pids: Array[int] = _network_transport.get_connected_peers()
	if pids.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Нет подключенных узлов."
		empty_lbl.add_theme_color_override("font_color", CyberTheme.get_text_muted_color())
		empty_lbl.add_theme_font_size_override("font_size", 12)
		connected_peers_list.add_child(empty_lbl)
		return

	var is_white := CyberTheme.is_white_theme()
	for pid in pids:
		var p_info: Dictionary = _network_transport.get_peer_info(pid)
		var p_name: String = str(p_info.get("name", "Peer #%d" % pid))
		var p_ip: String = str(p_info.get("ip", "remote"))
		var p_mods: int = int(p_info.get("modules_count", 0))

		var card := PanelContainer.new()
		var card_style := CyberTheme.create_glass_panel_style(
			Color(0.0, 0.85, 0.45, 0.4) if not is_white else CyberTheme.COLOR_ELECTRIC_BLUE,
			Color(0.03, 0.1, 0.08, 0.75) if not is_white else Color(0.9, 0.96, 0.92, 0.9),
			1,
			3
		)
		card.add_theme_stylebox_override("panel", card_style)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)

		var lbl := Label.new()
		lbl.text = "● [ID: %d] %s (%s)  •  Модулей: %d" % [pid, p_name, p_ip, p_mods]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_color_override("font_color", CyberTheme.COLOR_SUCCESS_LED if not is_white else CyberTheme.COLOR_TEXT_DARK)
		lbl.add_theme_font_size_override("font_size", 12)
		hbox.add_child(lbl)

		var offer_btn := Button.new()
		offer_btn.text = "ПРЕДЛОЖИТЬ МОДУЛЬ"
		offer_btn.custom_minimum_size = Vector2(130, 26)
		offer_btn.add_theme_font_size_override("font_size", 11)
		var b_style := CyberTheme.create_cyber_button_style(
			Color(0.0, 0.35, 0.45, 0.85) if not is_white else Color(0.8, 0.9, 0.98, 0.9),
			CyberTheme.COLOR_CYAN_GLOW,
			1,
			3
		)
		offer_btn.add_theme_stylebox_override("normal", b_style)
		offer_btn.pressed.connect(func():
			_prompt_offer_module_to_peer(pid)
		)
		hbox.add_child(offer_btn)

		card.add_child(hbox)
		connected_peers_list.add_child(card)

func add_module_offer(peer_id: int, module_meta: Dictionary) -> void:
	var mod_id: String = str(module_meta.get("id", ""))
	for i in range(_pending_module_offers.size() - 1, -1, -1):
		var existing: Dictionary = _pending_module_offers[i]
		if existing.get("peer_id", 0) == peer_id and existing.get("module_meta", {}).get("id", "") == mod_id:
			_pending_module_offers.remove_at(i)

	_pending_module_offers.append({
		"peer_id": peer_id,
		"module_meta": module_meta
	})
	_refresh_module_offers_ui()

func _refresh_module_offers_ui() -> void:
	if not is_instance_valid(module_offers_list):
		return

	for child in module_offers_list.get_children():
		module_offers_list.remove_child(child)
		child.queue_free()

	if _pending_module_offers.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Нет входящих предложений модулей."
		empty_lbl.add_theme_color_override("font_color", CyberTheme.get_text_muted_color())
		empty_lbl.add_theme_font_size_override("font_size", 12)
		module_offers_list.add_child(empty_lbl)
		return

	var is_white := CyberTheme.is_white_theme()
	for i in range(_pending_module_offers.size()):
		var offer: Dictionary = _pending_module_offers[i]
		var pid: int = int(offer.get("peer_id", 0))
		var meta: Dictionary = offer.get("module_meta", {})
		var mod_id: String = str(meta.get("id", "unknown"))
		var mod_name: String = str(meta.get("name", mod_id))
		var mod_sz: int = int(meta.get("size", 0))
		var mod_hash: String = str(meta.get("hash", "")).substr(0, 8)

		var card := PanelContainer.new()
		var card_style := CyberTheme.create_glass_panel_style(
			CyberTheme.COLOR_AMBER_LED,
			Color(0.12, 0.08, 0.02, 0.75) if not is_white else Color(0.98, 0.95, 0.88, 0.9),
			1,
			3
		)
		card.add_theme_stylebox_override("panel", card_style)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)

		var lbl := Label.new()
		lbl.text = "📦 %s (%s) • %.1f KB • SHA: %s • от Peer #%d" % [
			mod_name, mod_id, mod_sz / 1024.0, mod_hash, pid
		]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_color_override("font_color", CyberTheme.COLOR_AMBER_LED if not is_white else CyberTheme.COLOR_TEXT_DARK)
		lbl.add_theme_font_size_override("font_size", 12)
		hbox.add_child(lbl)

		var accept_btn := Button.new()
		accept_btn.text = "ПРИНЯТЬ"
		accept_btn.custom_minimum_size = Vector2(80, 26)
		accept_btn.add_theme_font_size_override("font_size", 11)
		var acc_style := CyberTheme.create_cyber_button_style(
			Color(0.05, 0.25, 0.15, 0.85) if not is_white else Color(0.85, 0.95, 0.88, 0.9),
			CyberTheme.COLOR_SUCCESS_LED,
			1,
			3
		)
		accept_btn.add_theme_stylebox_override("normal", acc_style)
		var current_offer := offer
		accept_btn.pressed.connect(func():
			if _module_sharing:
				_module_sharing.accept_module(pid, mod_id)
			_pending_module_offers.erase(current_offer)
			_refresh_module_offers_ui()
		)
		hbox.add_child(accept_btn)

		var reject_btn := Button.new()
		reject_btn.text = "ОТКЛОНИТЬ"
		reject_btn.custom_minimum_size = Vector2(80, 26)
		reject_btn.add_theme_font_size_override("font_size", 11)
		var rej_style := CyberTheme.create_cyber_button_style(
			Color(0.25, 0.08, 0.1, 0.85) if not is_white else Color(0.96, 0.86, 0.88, 0.9),
			CyberTheme.COLOR_RED_LED,
			1,
			3
		)
		reject_btn.add_theme_stylebox_override("normal", rej_style)
		reject_btn.pressed.connect(func():
			if _module_sharing:
				_module_sharing.reject_module(pid, mod_id)
			_pending_module_offers.erase(current_offer)
			_refresh_module_offers_ui()
		)
		hbox.add_child(reject_btn)

		card.add_child(hbox)
		module_offers_list.add_child(card)

func _on_offer_module_pressed() -> void:
	if not _network_transport or _network_transport.get_connected_peers().is_empty():
		_show_confirm("Нет подключенных узлов для передачи модулей.", func(): pass)
		return

	var pids: Array[int] = _network_transport.get_connected_peers()
	_prompt_offer_module_to_peer(pids[0])

func _prompt_offer_module_to_peer(target_peer_id: int) -> void:
	if not _module_library:
		return

	var all_mods: Array[Dictionary] = _module_library.get_all_modules()
	if all_mods.is_empty():
		_show_confirm("В библиотеке нет доступных модулей для передачи.", func(): pass)
		return

	if all_mods.size() == 1:
		var mod_id: String = str(all_mods[0].get("id", ""))
		var mod_name: String = str(all_mods[0].get("name", mod_id))
		_show_confirm("Предложить модуль '%s' узлу Peer #%d?" % [mod_name, target_peer_id], func():
			if _module_sharing:
				_module_sharing.offer_module(target_peer_id, mod_id)
		)
		return

	_show_module_selection_for_offer(target_peer_id, all_mods)

func _show_module_selection_for_offer(target_peer_id: int, mods: Array[Dictionary]) -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = "Выбор модуля для отправки"
	dlg.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	dlg.size = Vector2i(380, 160)
	dlg.ok_button_text = "Отправить"
	dlg.cancel_button_text = "Отмена"

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var lbl := Label.new()
	lbl.text = "Выберите модуль для отправки пиру Peer #%d:" % target_peer_id
	lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(lbl)

	var opt := OptionButton.new()
	for i in range(mods.size()):
		var m: Dictionary = mods[i]
		var mid: String = str(m.get("id", ""))
		var mname: String = str(m.get("name", mid))
		opt.add_item("%s (%s)" % [mname, mid], i)
	vbox.add_child(opt)

	dlg.add_child(vbox)
	add_child(dlg)

	dlg.confirmed.connect(func():
		var sel_idx := opt.get_selected_id()
		if sel_idx >= 0 and sel_idx < mods.size():
			var selected_mod_id: String = str(mods[sel_idx].get("id", ""))
			if _module_sharing:
				_module_sharing.offer_module(target_peer_id, selected_mod_id)
		dlg.queue_free()
	)
	dlg.canceled.connect(func(): dlg.queue_free())
	dlg.popup_centered()

# ----------------------------------------------------
# Semantic Cache UI & Management
# ----------------------------------------------------

func setup_cache(cache: Node) -> void:
	_semantic_cache = cache
	if _semantic_cache and _semantic_cache.has_signal("cache_updated"):
		if not _semantic_cache.cache_updated.is_connected(_on_cache_updated):
			_semantic_cache.cache_updated.connect(_on_cache_updated)
	_refresh_cache_ui()

func update_cache_source(source_type: String) -> void:
	match source_type.to_lower():
		"cache": _last_resolved_source = "🔵 Локальный Кэш"
		"p2p": _last_resolved_source = "🟢 P2P Сеть"
		"registry": _last_resolved_source = "⚪ Реестр шаблонов"
		_: _last_resolved_source = "🟡 Внешнее LLM API"
	_refresh_cache_ui()

func _on_cache_updated(_mod_id: String, _action: String) -> void:
	_refresh_cache_ui()

func _setup_cache_ui() -> void:
	var net_scroll_vbox = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/TabContainer/NetworkTab/Scroll/VBox")
	if not net_scroll_vbox:
		return

	var is_white := CyberTheme.is_white_theme()

	cache_section_panel = PanelContainer.new()
	cache_section_panel.name = "CacheSection"
	var card_style := CyberTheme.create_glass_panel_style(
		Color(0.0, 0.75, 1.0, 0.4) if not is_white else CyberTheme.COLOR_ELECTRIC_BLUE,
		Color(0.03, 0.08, 0.15, 0.75) if not is_white else Color(0.9, 0.94, 0.98, 0.9),
		1,
		4
	)
	cache_section_panel.add_theme_stylebox_override("panel", card_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	cache_section_panel.add_child(vbox)

	# Header HBox
	var header_hbox := HBoxContainer.new()
	vbox.add_child(header_hbox)

	var title_lbl := Label.new()
	title_lbl.text = "// СЕМАНТИЧЕСКИЙ КЭШ МОДУЛЕЙ"
	title_lbl.add_theme_color_override("font_color", CyberTheme.COLOR_CYAN_GLOW if not is_white else CyberTheme.COLOR_ELECTRIC_BLUE)
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_lbl)

	clear_cache_btn = Button.new()
	clear_cache_btn.text = "ОЧИСТИТЬ КЭШ"
	clear_cache_btn.custom_minimum_size = Vector2(110, 24)
	clear_cache_btn.add_theme_font_size_override("font_size", 11)
	var clear_btn_style := CyberTheme.create_cyber_button_style(
		Color(0.3, 0.08, 0.1, 0.85) if not is_white else Color(0.95, 0.85, 0.88, 0.9),
		CyberTheme.COLOR_RED_LED,
		1,
		3
	)
	clear_cache_btn.add_theme_stylebox_override("normal", clear_btn_style)
	clear_cache_btn.pressed.connect(_on_clear_cache_pressed)
	header_hbox.add_child(clear_cache_btn)

	# Stats and Source
	var info_hbox := HBoxContainer.new()
	info_hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(info_hbox)

	cache_stats_label = Label.new()
	cache_stats_label.text = "Локальный кэш: 0 модулей • 0 уникальных тегов"
	cache_stats_label.add_theme_color_override("font_color", CyberTheme.COLOR_TEXT_CYAN if not is_white else CyberTheme.COLOR_TEXT_DARK)
	cache_stats_label.add_theme_font_size_override("font_size", 12)
	info_hbox.add_child(cache_stats_label)

	cache_source_label = Label.new()
	cache_source_label.text = "Источник последнего модуля: —"
	cache_source_label.add_theme_color_override("font_color", CyberTheme.COLOR_AMBER_LED if not is_white else CyberTheme.get_text_muted_color())
	cache_source_label.add_theme_font_size_override("font_size", 12)
	info_hbox.add_child(cache_source_label)

	# Popular modules subtitle
	var pop_lbl := Label.new()
	pop_lbl.text = "Популярные модули из кэша (Топ-10):"
	pop_lbl.add_theme_color_override("font_color", CyberTheme.get_text_muted_color())
	pop_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(pop_lbl)

	# Popular modules list
	cache_popular_list = VBoxContainer.new()
	cache_popular_list.add_theme_constant_override("separation", 4)
	vbox.add_child(cache_popular_list)

	net_scroll_vbox.add_child(cache_section_panel)
	_refresh_cache_ui()

func _refresh_cache_ui() -> void:
	if not is_instance_valid(cache_stats_label):
		return

	var mod_count := 0
	var tag_count := 0
	if _semantic_cache != null and is_instance_valid(_semantic_cache):
		if _semantic_cache.has_method("get_total_modules_count"):
			mod_count = _semantic_cache.get_total_modules_count()
		if _semantic_cache.has_method("get_unique_tags"):
			tag_count = _semantic_cache.get_unique_tags().size()

	cache_stats_label.text = "Локальный кэш: %d модулей • %d уникальных тегов" % [mod_count, tag_count]
	if is_instance_valid(cache_source_label):
		cache_source_label.text = "Источник последнего модуля: %s" % _last_resolved_source

	if not is_instance_valid(cache_popular_list):
		return

	for c in cache_popular_list.get_children():
		cache_popular_list.remove_child(c)
		c.queue_free()

	if _semantic_cache == null or not is_instance_valid(_semantic_cache) or mod_count == 0:
		var empty_lbl := Label.new()
		empty_lbl.text = "Кэш пуст. Проверенные модули будут автоматически кэшироваться здесь."
		empty_lbl.add_theme_color_override("font_color", CyberTheme.get_text_muted_color())
		empty_lbl.add_theme_font_size_override("font_size", 11)
		cache_popular_list.add_child(empty_lbl)
		return

	var pop_mods: Array[Dictionary] = []
	if _semantic_cache.has_method("get_popular_modules"):
		pop_mods = _semantic_cache.get_popular_modules(10)

	var is_white := CyberTheme.is_white_theme()
	for m in pop_mods:
		var card := PanelContainer.new()
		var card_style := CyberTheme.create_glass_panel_style(
			CyberTheme.COLOR_CYAN_GLOW if not is_white else CyberTheme.COLOR_ELECTRIC_BLUE,
			Color(0.04, 0.08, 0.14, 0.6) if not is_white else Color(0.92, 0.95, 0.99, 0.8),
			1,
			2
		)
		card.add_theme_stylebox_override("panel", card_style)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		card.add_child(hbox)

		var m_id: String = str(m.get("id", ""))
		var m_name: String = str(m.get("name", m_id))
		var m_uses: int = int(m.get("usage_count", 0))
		var m_rep: float = float(m.get("reputation", 0.0))
		var m_tags: Array = m.get("tags", [])
		var tags_str := ", ".join(m_tags) if not m_tags.is_empty() else "—"

		var lbl := Label.new()
		lbl.text = "📦 %s [%s] • Загрузок: %d • Репутация: %.2f • Теги: %s" % [m_name, m_id, m_uses, m_rep, tags_str]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_color_override("font_color", CyberTheme.COLOR_TEXT_PRIMARY if not is_white else CyberTheme.COLOR_TEXT_DARK)
		lbl.add_theme_font_size_override("font_size", 11)
		hbox.add_child(lbl)

		cache_popular_list.add_child(card)

func _on_clear_cache_pressed() -> void:
	_show_confirm("Вы действительно хотите полностью очистить локальный семантический кэш?", func():
		if _semantic_cache and _semantic_cache.has_method("clear_cache"):
			_semantic_cache.clear_cache()
			_refresh_cache_ui()
	)

# ----------------------------------------------------
# Multiplayer Presence & Operations Log UI
# ----------------------------------------------------

func _setup_multiplayer_ui() -> void:
	var net_scroll_vbox = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/TabContainer/NetworkTab/Scroll/VBox")
	if not net_scroll_vbox:
		return

	var is_white := CyberTheme.is_white_theme()

	# 1. Секция Присутствия
	presence_section_panel = PanelContainer.new()
	presence_section_panel.name = "PresenceSection"
	var pres_style := CyberTheme.create_glass_panel_style(
		Color(0.0, 0.85, 0.45, 0.4) if not is_white else CyberTheme.COLOR_SUCCESS_LED,
		Color(0.03, 0.08, 0.12, 0.75) if not is_white else Color(0.92, 0.96, 0.98, 0.9),
		1,
		4
	)
	presence_section_panel.add_theme_stylebox_override("panel", pres_style)

	var p_vbox := VBoxContainer.new()
	p_vbox.add_theme_constant_override("separation", 8)
	presence_section_panel.add_child(p_vbox)

	var p_title := Label.new()
	p_title.text = "// СЕТЕВОЕ ПРИСУТСТВИЕ И АКТИВНОСТЬ (PRESENCE)"
	p_title.add_theme_color_override("font_color", CyberTheme.COLOR_SUCCESS_LED if not is_white else Color(0.0, 0.5, 0.25, 1.0))
	p_title.add_theme_font_size_override("font_size", 14)
	p_vbox.add_child(p_title)

	presence_peers_list = VBoxContainer.new()
	presence_peers_list.name = "PresencePeersList"
	presence_peers_list.add_theme_constant_override("separation", 6)
	p_vbox.add_child(presence_peers_list)

	net_scroll_vbox.add_child(presence_section_panel)

	# 2. Секция Лога Операций
	ops_log_section_panel = PanelContainer.new()
	ops_log_section_panel.name = "OpsLogSection"
	var ops_style := CyberTheme.create_glass_panel_style(
		Color(1.0, 0.7, 0.0, 0.4) if not is_white else CyberTheme.COLOR_AMBER_LED,
		Color(0.08, 0.06, 0.02, 0.75) if not is_white else Color(0.98, 0.96, 0.92, 0.9),
		1,
		4
	)
	ops_log_section_panel.add_theme_stylebox_override("panel", ops_style)

	var o_vbox := VBoxContainer.new()
	o_vbox.add_theme_constant_override("separation", 8)
	ops_log_section_panel.add_child(o_vbox)

	var o_title := Label.new()
	o_title.text = "// ЖУРНАЛ СИНХРОНИЗАЦИИ ОПЕРАЦИЙ (CRDT STATE LOG)"
	o_title.add_theme_color_override("font_color", CyberTheme.COLOR_AMBER_LED if not is_white else Color(0.7, 0.45, 0.0, 1.0))
	o_title.add_theme_font_size_override("font_size", 14)
	o_vbox.add_child(o_title)

	ops_log_list = VBoxContainer.new()
	ops_log_list.name = "OpsLogList"
	ops_log_list.add_theme_constant_override("separation", 4)
	o_vbox.add_child(ops_log_list)

	net_scroll_vbox.add_child(ops_log_section_panel)
	update_presence_ui()
	update_ops_log_ui()

func update_presence_ui(_arg: Variant = null) -> void:
	if not is_instance_valid(presence_peers_list):
		return

	for child in presence_peers_list.get_children():
		presence_peers_list.remove_child(child)
		child.queue_free()

	if _presence_manager == null or not is_instance_valid(_presence_manager):
		var lbl := Label.new()
		lbl.text = "Система присутствия не активна (офлайн)."
		lbl.add_theme_color_override("font_color", CyberTheme.get_text_muted_color())
		lbl.add_theme_font_size_override("font_size", 12)
		presence_peers_list.add_child(lbl)
		return

	var all_states: Dictionary = _presence_manager.get_all_peer_states()
	if all_states.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Другие пользователи в пространстве не обнаружены."
		empty_lbl.add_theme_color_override("font_color", CyberTheme.get_text_muted_color())
		empty_lbl.add_theme_font_size_override("font_size", 12)
		presence_peers_list.add_child(empty_lbl)
		return

	var is_white := CyberTheme.is_white_theme()
	for pid in all_states:
		var st: Dictionary = all_states[pid]
		var p_name: String = str(st.get("name", "Peer #%d" % int(pid)))
		var p_act: String = str(st.get("activity", "idle"))
		var p_col: Color = st.get("color", Color.CYAN)
		var p_pos: Vector3 = st.get("position", Vector3.ZERO)

		var card := PanelContainer.new()
		var card_style := CyberTheme.create_glass_panel_style(
			p_col,
			Color(0.04, 0.08, 0.14, 0.7) if not is_white else Color(0.94, 0.96, 0.98, 0.9),
			1,
			3
		)
		card.add_theme_stylebox_override("panel", card_style)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)

		var lbl := Label.new()
		lbl.text = "● [ID: %d] %s — Позиция: (%.1f, %.1f, %.1f) | Активность: %s" % [int(pid), p_name, p_pos.x, p_pos.y, p_pos.z, p_act]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_color_override("font_color", p_col if not is_white else CyberTheme.COLOR_TEXT_DARK)
		lbl.add_theme_font_size_override("font_size", 12)
		hbox.add_child(lbl)

		card.add_child(hbox)
		presence_peers_list.add_child(card)

func update_ops_log_ui(_arg: Variant = null) -> void:
	if not is_instance_valid(ops_log_list):
		return

	for child in ops_log_list.get_children():
		ops_log_list.remove_child(child)
		child.queue_free()

	if _space_state_machine == null or not is_instance_valid(_space_state_machine):
		var lbl := Label.new()
		lbl.text = "Машина состояний не активна."
		lbl.add_theme_color_override("font_color", CyberTheme.get_text_muted_color())
		lbl.add_theme_font_size_override("font_size", 12)
		ops_log_list.add_child(lbl)
		return

	var ops: Array[Dictionary] = _space_state_machine.get_operation_log()
	if ops.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "История операций пуста."
		empty_lbl.add_theme_color_override("font_color", CyberTheme.get_text_muted_color())
		empty_lbl.add_theme_font_size_override("font_size", 12)
		ops_log_list.add_child(empty_lbl)
		return

	var is_white := CyberTheme.is_white_theme()
	var display_ops: Array = ops.slice(maxi(0, ops.size() - 20))
	display_ops.reverse()

	for op in display_ops:
		var op_type: String = str(op.get("op_type", ""))
		var author_id: int = int(op.get("author_id", 0))
		var op_id: String = str(op.get("op_id", ""))
		var data_dict: Dictionary = op.get("data", {})
		var target_info: String = str(data_dict.get("module_id", data_dict.get("space_id", "")))

		var lbl := Label.new()
		lbl.text = "▸ [%s] Автор: #%d | Тип: %s | Цель: %s" % [op_id.substr(0, 14), author_id, op_type, target_info]
		lbl.add_theme_color_override("font_color", CyberTheme.COLOR_AMBER_LED if not is_white else CyberTheme.COLOR_TEXT_DARK)
		lbl.add_theme_font_size_override("font_size", 11)
		ops_log_list.add_child(lbl)

# ----------------------------------------------------
# Input Mapper & Keybindings UI
# ----------------------------------------------------

func setup_input_mapper(mapper: Node) -> void:
	_input_mapper = mapper
	if _input_mapper:
		if _input_mapper.has_signal("actions_refreshed") and not _input_mapper.actions_refreshed.is_connected(_refresh_keybindings_ui):
			_input_mapper.actions_refreshed.connect(_refresh_keybindings_ui)
		if _input_mapper.has_signal("bindings_reset") and not _input_mapper.bindings_reset.is_connected(_refresh_keybindings_ui):
			_input_mapper.bindings_reset.connect(_refresh_keybindings_ui)
		if _input_mapper.has_signal("binding_changed") and not _input_mapper.binding_changed.is_connected(func(_a, _o, _n): _refresh_keybindings_ui()):
			_input_mapper.binding_changed.connect(func(_a, _o, _n): _refresh_keybindings_ui())
	_refresh_keybindings_ui()

func _setup_keybindings_ui() -> void:
	var settings_scroll_vbox = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox")
	if not settings_scroll_vbox:
		return

	_setup_key_capture_modal()

	var is_white := CyberTheme.is_white_theme()

	keybindings_section_panel = PanelContainer.new()
	keybindings_section_panel.name = "KeybindingsSection"
	var panel_style := CyberTheme.create_glass_panel_style(
		Color(0.0, 0.75, 1.0, 0.45) if not is_white else CyberTheme.COLOR_ELECTRIC_BLUE,
		Color(0.03, 0.08, 0.15, 0.75) if not is_white else Color(0.9, 0.94, 0.98, 0.9),
		1,
		4
	)
	keybindings_section_panel.add_theme_stylebox_override("panel", panel_style)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	keybindings_section_panel.add_child(main_vbox)

	# 1. Header & Reset All Button
	var header_hbox := HBoxContainer.new()
	main_vbox.add_child(header_hbox)

	var title_lbl := Label.new()
	title_lbl.text = "// НАЗНАЧЕНИЕ КЛАВИШ УПРАВЛЕНИЯ (INPUT MAPPER)"
	title_lbl.add_theme_color_override("font_color", CyberTheme.COLOR_CYAN_GLOW if not is_white else CyberTheme.COLOR_ELECTRIC_BLUE)
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_lbl)

	reset_all_bindings_btn = Button.new()
	reset_all_bindings_btn.text = "СБРОСИТЬ ВСЕ БИНДЫ"
	reset_all_bindings_btn.custom_minimum_size = Vector2(140, 24)
	reset_all_bindings_btn.add_theme_font_size_override("font_size", 11)
	var reset_btn_style := CyberTheme.create_cyber_button_style(
		Color(0.25, 0.1, 0.12, 0.85) if not is_white else Color(0.95, 0.85, 0.88, 0.9),
		CyberTheme.COLOR_RED_LED,
		1,
		3
	)
	reset_all_bindings_btn.add_theme_stylebox_override("normal", reset_btn_style)
	reset_all_bindings_btn.pressed.connect(_on_reset_all_bindings_pressed)
	header_hbox.add_child(reset_all_bindings_btn)

	var desc_lbl := Label.new()
	desc_lbl.text = "Кликните по кнопке с клавишей для переназначения. Конфликты клавиш определяются и разрешаются автоматически."
	desc_lbl.add_theme_color_override("font_color", CyberTheme.get_text_muted_color())
	desc_lbl.add_theme_font_size_override("font_size", 11)
	main_vbox.add_child(desc_lbl)

	# 2. Section: Active Modules
	var act_header := Label.new()
	act_header.text = "► АКТИВНЫЕ МОДУЛИ (ТЕКУЩЕЕ ПРОСТРАНСТВО)"
	act_header.add_theme_color_override("font_color", CyberTheme.COLOR_ELECTRIC_BLUE if is_white else CyberTheme.COLOR_CYAN_GLOW)
	act_header.add_theme_font_size_override("font_size", 12)
	main_vbox.add_child(act_header)

	active_bindings_container = VBoxContainer.new()
	active_bindings_container.add_theme_constant_override("separation", 6)
	main_vbox.add_child(active_bindings_container)

	# 3. Section: Library Modules
	var lib_header := Label.new()
	lib_header.text = "► МОДУЛИ ИЗ БИБЛИОТЕКИ"
	lib_header.add_theme_color_override("font_color", CyberTheme.COLOR_ELECTRIC_BLUE)
	lib_header.add_theme_font_size_override("font_size", 12)
	main_vbox.add_child(lib_header)

	library_bindings_container = VBoxContainer.new()
	library_bindings_container.add_theme_constant_override("separation", 6)
	main_vbox.add_child(library_bindings_container)

	# 4. Section: System Hotkeys
	var sys_header := Label.new()
	sys_header.text = "► СИСТЕМНЫЕ ГОРЯЧИЕ КЛАВИШИ UNICORE"
	sys_header.add_theme_color_override("font_color", CyberTheme.COLOR_TEXT_PRIMARY if not is_white else CyberTheme.COLOR_TEXT_DARK)
	sys_header.add_theme_font_size_override("font_size", 12)
	main_vbox.add_child(sys_header)

	system_bindings_container = VBoxContainer.new()
	system_bindings_container.add_theme_constant_override("separation", 6)
	main_vbox.add_child(system_bindings_container)

	settings_scroll_vbox.add_child(keybindings_section_panel)
	_refresh_keybindings_ui()

func _refresh_keybindings_ui() -> void:
	if not is_instance_valid(active_bindings_container) or not is_instance_valid(library_bindings_container) or not is_instance_valid(system_bindings_container):
		return

	for c in active_bindings_container.get_children():
		active_bindings_container.remove_child(c)
		c.queue_free()

	for c in library_bindings_container.get_children():
		library_bindings_container.remove_child(c)
		c.queue_free()

	for c in system_bindings_container.get_children():
		system_bindings_container.remove_child(c)
		c.queue_free()

	if _input_mapper == null or not is_instance_valid(_input_mapper):
		var lbl := Label.new()
		lbl.text = "InputMapper не инициализирован."
		lbl.add_theme_color_override("font_color", CyberTheme.get_text_muted_color())
		lbl.add_theme_font_size_override("font_size", 11)
		active_bindings_container.add_child(lbl)
		return

	# Заполняем активные модули
	var active_groups: Dictionary = _input_mapper.get_actions_grouped_by_module("active")
	if active_groups.is_empty():
		var empty_act := Label.new()
		empty_act.text = "Нет активных модулей с настраиваемым управлением."
		empty_act.add_theme_color_override("font_color", CyberTheme.get_text_muted_color())
		empty_act.add_theme_font_size_override("font_size", 11)
		active_bindings_container.add_child(empty_act)
	else:
		for mod_id in active_groups.keys():
			var grp: Dictionary = active_groups[mod_id]
			var card := _create_module_bindings_card(grp, true)
			active_bindings_container.add_child(card)

	# Заполняем модули из библиотеки
	var lib_groups: Dictionary = _input_mapper.get_actions_grouped_by_module("library")
	if lib_groups.is_empty():
		var empty_lib := Label.new()
		empty_lib.text = "В библиотеке нет незагруженных модулей с элементами управления."
		empty_lib.add_theme_color_override("font_color", CyberTheme.get_text_muted_color())
		empty_lib.add_theme_font_size_override("font_size", 11)
		library_bindings_container.add_child(empty_lib)
	else:
		for mod_id in lib_groups.keys():
			var grp: Dictionary = lib_groups[mod_id]
			var card := _create_module_bindings_card(grp, false)
			library_bindings_container.add_child(card)

	# Заполняем системные горячие клавиши
	var sys_actions: Array[Dictionary] = _input_mapper.get_actions_by_category("system")
	var is_white := CyberTheme.is_white_theme()
	var sys_card := _create_actions_table_card("Система UniCORE", sys_actions, CyberTheme.COLOR_ELECTRIC_BLUE if is_white else CyberTheme.COLOR_CYAN_GLOW)
	system_bindings_container.add_child(sys_card)

func _create_module_bindings_card(group_data: Dictionary, is_active: bool) -> PanelContainer:
	var mod_name: String = group_data.get("name", "Модуль")
	var actions: Array = group_data.get("actions", [])
	var badge_color := CyberTheme.COLOR_CYAN_GLOW if is_active else CyberTheme.COLOR_ELECTRIC_BLUE
	var title_prefix := "[АКТИВЕН] " if is_active else "[БИБЛИОТЕКА] "
	return _create_actions_table_card(title_prefix + mod_name, actions, badge_color)

func _create_actions_table_card(title_str: String, actions: Array, accent_color: Color) -> PanelContainer:
	var is_white := CyberTheme.is_white_theme()
	var eff_accent := accent_color
	if is_white and (eff_accent == CyberTheme.COLOR_TEXT_PRIMARY or eff_accent == Color.WHITE):
		eff_accent = CyberTheme.COLOR_ELECTRIC_BLUE
	var card := PanelContainer.new()
	var card_style := CyberTheme.create_glass_panel_style(
		eff_accent,
		Color(0.04, 0.08, 0.14, 0.6) if not is_white else Color(0.92, 0.95, 0.99, 0.85),
		1,
		2
	)
	card.add_theme_stylebox_override("panel", card_style)

	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 6)
	card.add_child(card_vbox)

	var title_lbl := Label.new()
	title_lbl.text = title_str
	title_lbl.add_theme_color_override("font_color", eff_accent)
	title_lbl.add_theme_font_size_override("font_size", 12)
	card_vbox.add_child(title_lbl)

	for act in actions:
		var act_dict: Dictionary = act
		var act_name: String = act_dict.get("action", "")
		var act_label: String = act_dict.get("label", act_name)
		var current_key: int = int(act_dict.get("current_key", KEY_NONE))
		var mod_name: String = act_dict.get("module_name", title_str)

		var row_hbox := HBoxContainer.new()
		row_hbox.add_theme_constant_override("separation", 8)
		card_vbox.add_child(row_hbox)

		var act_info_lbl := Label.new()
		act_info_lbl.text = "%s  (%s)" % [act_label, act_name]
		act_info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		act_info_lbl.add_theme_color_override("font_color", CyberTheme.COLOR_TEXT_PRIMARY if not is_white else CyberTheme.COLOR_TEXT_DARK)
		act_info_lbl.add_theme_font_size_override("font_size", 11)
		row_hbox.add_child(act_info_lbl)

		# Key Button
		var key_btn := Button.new()
		var key_display: String = InputMapperScript.get_key_display_name(current_key)
		key_btn.text = "[ %s ]" % key_display
		key_btn.custom_minimum_size = Vector2(90, 22)
		key_btn.add_theme_font_size_override("font_size", 11)
		var btn_style := CyberTheme.create_cyber_button_style(
			Color(0.08, 0.16, 0.28, 0.85) if not is_white else Color(0.85, 0.92, 0.98, 0.9),
			CyberTheme.COLOR_CYAN_GLOW if not is_white else CyberTheme.COLOR_ELECTRIC_BLUE,
			1,
			2
		)
		key_btn.add_theme_stylebox_override("normal", btn_style)
		key_btn.pressed.connect(func():
			_open_key_capture(act_name, act_label, mod_name)
		)
		row_hbox.add_child(key_btn)

		# Reset button
		var reset_btn := Button.new()
		reset_btn.text = "↺"
		reset_btn.tooltip_text = "Сбросить к клавише по умолчанию"
		reset_btn.custom_minimum_size = Vector2(24, 22)
		reset_btn.add_theme_font_size_override("font_size", 11)
		reset_btn.pressed.connect(func():
			if _input_mapper:
				_input_mapper.reset_action_to_default(act_name)
				_refresh_keybindings_ui()
		)
		row_hbox.add_child(reset_btn)

	return card

func _setup_key_capture_modal() -> void:
	if _key_capture_modal:
		return

	_key_capture_modal = Control.new()
	_key_capture_modal.name = "KeyCaptureModal"
	_key_capture_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_key_capture_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_key_capture_modal.focus_mode = Control.FOCUS_ALL
	_key_capture_modal.visible = false

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.01, 0.02, 0.04, 0.82)
	_key_capture_modal.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_key_capture_modal.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 220)
	var is_white := CyberTheme.is_white_theme()
	var panel_style := CyberTheme.create_glass_panel_style(
		CyberTheme.COLOR_CYAN_GLOW if not is_white else CyberTheme.COLOR_ELECTRIC_BLUE,
		Color(0.04, 0.07, 0.12, 0.95) if not is_white else Color(0.94, 0.96, 0.99, 0.98),
		2,
		6,
		16,
		Color(0.0, 0.8, 1.0, 0.35)
	)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "// НАЗНАЧЕНИЕ КЛАВИШИ УПРАВЛЕНИЯ"
	title.add_theme_color_override("font_color", CyberTheme.COLOR_CYAN_GLOW if not is_white else CyberTheme.COLOR_ELECTRIC_BLUE)
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	_key_capture_desc = Label.new()
	_key_capture_desc.text = "Действие: —"
	_key_capture_desc.add_theme_color_override("font_color", CyberTheme.COLOR_TEXT_PRIMARY if not is_white else CyberTheme.COLOR_TEXT_DARK)
	_key_capture_desc.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_key_capture_desc)

	_key_capture_prompt = Label.new()
	_key_capture_prompt.text = "[ НАЖМИТЕ ЛЮБУЮ КЛАВИШУ... ]"
	_key_capture_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_key_capture_prompt.add_theme_color_override("font_color", CyberTheme.COLOR_CYAN_GLOW)
	_key_capture_prompt.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_key_capture_prompt)

	_key_capture_conflict_lbl = Label.new()
	_key_capture_conflict_lbl.text = ""
	_key_capture_conflict_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_key_capture_conflict_lbl.add_theme_color_override("font_color", CyberTheme.COLOR_AMBER_LED)
	_key_capture_conflict_lbl.add_theme_font_size_override("font_size", 11)
	_key_capture_conflict_lbl.visible = false
	vbox.add_child(_key_capture_conflict_lbl)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(btn_hbox)

	var cancel_btn := Button.new()
	cancel_btn.text = "Отмена (Esc)"
	cancel_btn.custom_minimum_size = Vector2(100, 30)
	var cancel_btn_style := CyberTheme.create_cyber_button_style(
		Color(0.2, 0.25, 0.32, 0.8),
		CyberTheme.COLOR_TEXT_MUTED,
		1,
		3
	)
	cancel_btn.add_theme_stylebox_override("normal", cancel_btn_style)
	cancel_btn.pressed.connect(_close_key_capture)
	btn_hbox.add_child(cancel_btn)

	add_child(_key_capture_modal)

func _open_key_capture(action_name: String, action_label: String, module_name: String) -> void:
	_setup_key_capture_modal()
	_key_capture_action = action_name
	_key_capture_label = action_label
	_key_capture_module = module_name
	_key_capture_pending_key = KEY_NONE

	if _key_capture_desc:
		_key_capture_desc.text = "Модуль: %s\nДействие: %s (%s)" % [module_name, action_label, action_name]
	if _key_capture_prompt:
		_key_capture_prompt.text = "[ НАЖМИТЕ ЛЮБУЮ КЛАВИШУ... ]"
		_key_capture_prompt.add_theme_color_override("font_color", CyberTheme.COLOR_CYAN_GLOW)
	if _key_capture_conflict_lbl:
		_key_capture_conflict_lbl.text = ""
		_key_capture_conflict_lbl.hide()

	if _key_capture_modal:
		_key_capture_modal.show()
		_key_capture_modal.grab_focus()

func _close_key_capture() -> void:
	if _key_capture_modal:
		_key_capture_modal.hide()
	_key_capture_action = ""
	_key_capture_label = ""
	_key_capture_module = ""
	_key_capture_pending_key = KEY_NONE

func _handle_captured_key(kc: int) -> void:
	if kc == KEY_ESCAPE and _key_capture_pending_key == KEY_NONE:
		_close_key_capture()
		return

	if _input_mapper:
		var conflict: Dictionary = _input_mapper.check_conflict(_key_capture_action, kc)
		if conflict.get("has_conflict", false) == true and _key_capture_pending_key != kc:
			_key_capture_pending_key = kc
			var key_name := InputMapperScript.get_key_display_name(kc)
			var other_lbl: String = str(conflict.get("conflicting_label", ""))
			var other_mod: String = str(conflict.get("conflicting_module", ""))
			if _key_capture_conflict_lbl:
				_key_capture_conflict_lbl.text = "⚠️ Клавиша [%s] уже используется действием '%s' (%s)!\nНажмите клавишу [%s] еще раз для подтверждения или Esc для отмены." % [key_name, other_lbl, other_mod, key_name]
				_key_capture_conflict_lbl.show()
			if _key_capture_prompt:
				_key_capture_prompt.text = "[ НАЖМИТЕ ЕЩЕ РАЗ ДЛЯ ПЕРЕНАЗНАЧЕНИЯ ]"
				_key_capture_prompt.add_theme_color_override("font_color", CyberTheme.COLOR_AMBER_LED)
			return

		_input_mapper.rebind_action(_key_capture_action, kc, true)

	_close_key_capture()
	_refresh_keybindings_ui()

func _on_reset_all_bindings_pressed() -> void:
	_show_confirm("Сбросить все назначения клавиш управления к значениям по умолчанию?", func():
		if _input_mapper:
			_input_mapper.reset_all_to_defaults()
			_refresh_keybindings_ui()
	)

# ==============================================================================
# Секция ИИ-Агента: Встроенный Локальный ИИ (llama-server) & Облачный Стек (Phase 3c)
# ==============================================================================

func _setup_agent_settings_ui() -> void:
	var agent_section := get_node_or_null("MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox/AgentSection") as GridContainer
	var settings_vbox := get_node_or_null("MainPanel/MarginContainer/VBoxContainer/TabContainer/SettingsTab/Scroll/VBox") as VBoxContainer
	if not agent_section or not settings_vbox:
		return

	_key_label = agent_section.get_node_or_null("KeyLabel") as Label

	# 1. Заполнение выпадающего списка 9 провайдерами
	if is_instance_valid(agent_provider_opt):
		agent_provider_opt.clear()
		for i in range(AGENT_PROVIDER_DATA.size()):
			var p: Dictionary = AGENT_PROVIDER_DATA[i]
			agent_provider_opt.add_item(str(p.get("label", "")), i)
		if not agent_provider_opt.item_selected.is_connected(_on_agent_provider_selected):
			agent_provider_opt.item_selected.connect(_on_agent_provider_selected)

	# 2. Кнопка Show/Hide API-ключа внутри поля KeyEdit
	if is_instance_valid(agent_key_edit) and not _toggle_key_vis_btn:
		_toggle_key_vis_btn = Button.new()
		_toggle_key_vis_btn.name = "ToggleKeyVisBtn"
		_toggle_key_vis_btn.text = "👁"
		_toggle_key_vis_btn.flat = true
		_toggle_key_vis_btn.custom_minimum_size = Vector2(32, 28)
		_toggle_key_vis_btn.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
		_toggle_key_vis_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_toggle_key_vis_btn.focus_mode = Control.FOCUS_NONE
		_toggle_key_vis_btn.pressed.connect(_on_toggle_key_visibility_pressed)
		agent_key_edit.add_child(_toggle_key_vis_btn)

	# 3. Строка Custom Base URL в GridContainer
	if not _custom_url_label:
		_custom_url_label = Label.new()
		_custom_url_label.name = "CustomUrlLabel"
		_custom_url_label.text = "Custom Base URL:"
		agent_section.add_child(_custom_url_label)

	if not _agent_custom_url_edit:
		_agent_custom_url_edit = LineEdit.new()
		_agent_custom_url_edit.name = "CustomUrlEdit"
		_agent_custom_url_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_agent_custom_url_edit.placeholder_text = "https://api.together.xyz/v1/chat/completions или http://localhost:11434/v1/chat/completions"
		agent_section.add_child(_agent_custom_url_edit)

	var insert_idx: int = agent_section.get_index() + 1
	var is_white := CyberTheme.is_white_theme()

	# 4. Zero-Key Information Badge (для локального встроенного сервера)
	if not _agent_zero_key_panel:
		_agent_zero_key_panel = PanelContainer.new()
		_agent_zero_key_panel.name = "AgentZeroKeyBadge"
		var z_style := CyberTheme.create_glass_panel_style(
			CyberTheme.COLOR_ELECTRIC_BLUE if is_white else CyberTheme.COLOR_CYAN_GLOW,
			Color(0.92, 0.96, 1.0, 0.85) if is_white else Color(0.02, 0.08, 0.16, 0.65),
			1,
			4,
			6
		)
		_agent_zero_key_panel.add_theme_stylebox_override("panel", z_style)

		var z_margin := MarginContainer.new()
		z_margin.add_theme_constant_override("margin_left", 12)
		z_margin.add_theme_constant_override("margin_right", 12)
		z_margin.add_theme_constant_override("margin_top", 6)
		z_margin.add_theme_constant_override("margin_bottom", 6)
		_agent_zero_key_panel.add_child(z_margin)

		var z_lbl := Label.new()
		z_lbl.text = "● ВСТРОЕННЫЙ СЕРВЕР // API-КЛЮЧ НЕ ТРЕБУЕТСЯ (Zero-Key Mode)"
		z_lbl.add_theme_color_override("font_color", CyberTheme.COLOR_ELECTRIC_BLUE if is_white else CyberTheme.COLOR_CYAN_GLOW)
		z_lbl.add_theme_font_size_override("font_size", 12)
		z_margin.add_child(z_lbl)

		settings_vbox.add_child(_agent_zero_key_panel)
		settings_vbox.move_child(_agent_zero_key_panel, insert_idx)
		insert_idx += 1

	# 5. Панель телеметрии и управления встроенным локальным сервером
	if not _agent_local_card:
		_agent_local_card = PanelContainer.new()
		_agent_local_card.name = "AgentLocalCard"
		var c_style := CyberTheme.create_glass_panel_style(
			Color(0.2, 0.55, 0.88, 0.5) if is_white else Color(0.0, 0.75, 1.0, 0.4),
			Color(0.92, 0.95, 0.99, 0.9) if is_white else Color(0.03, 0.06, 0.12, 0.8),
			1,
			4,
			10
		)
		_agent_local_card.add_theme_stylebox_override("panel", c_style)

		var c_margin := MarginContainer.new()
		c_margin.add_theme_constant_override("margin_left", 14)
		c_margin.add_theme_constant_override("margin_right", 14)
		c_margin.add_theme_constant_override("margin_top", 10)
		c_margin.add_theme_constant_override("margin_bottom", 10)
		_agent_local_card.add_child(c_margin)

		var c_vbox := VBoxContainer.new()
		c_vbox.add_theme_constant_override("separation", 8)
		c_margin.add_child(c_vbox)

		# Row 1: Status header
		var status_hbox := HBoxContainer.new()
		c_vbox.add_child(status_hbox)

		var status_title := Label.new()
		status_title.text = "// СОСТОЯНИЕ ВСТРОЕННОГО LLAMA-SERVER:"
		status_title.add_theme_font_size_override("font_size", 12)
		status_title.add_theme_color_override("font_color", CyberTheme.get_text_muted_color())
		status_hbox.add_child(status_title)

		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		status_hbox.add_child(sp)

		_local_status_lbl = Label.new()
		_local_status_lbl.text = "[● ОСТАНОВЛЕН]"
		_local_status_lbl.add_theme_font_size_override("font_size", 12)
		_local_status_lbl.add_theme_color_override("font_color", CyberTheme.get_text_muted_color())
		status_hbox.add_child(_local_status_lbl)

		# Row 2: Download progress box
		_local_download_box = VBoxContainer.new()
		_local_download_box.visible = false
		_local_download_box.add_theme_constant_override("separation", 4)
		c_vbox.add_child(_local_download_box)

		_local_download_lbl = Label.new()
		_local_download_lbl.text = "Загрузка модели Qwen2.5-Coder-1.5B..."
		_local_download_lbl.add_theme_font_size_override("font_size", 11)
		_local_download_lbl.add_theme_color_override("font_color", CyberTheme.COLOR_AMBER_LED)
		_local_download_box.add_child(_local_download_lbl)

		_local_download_bar = ProgressBar.new()
		_local_download_bar.custom_minimum_size = Vector2(0, 8)
		_local_download_bar.show_percentage = false
		var pb_fill := StyleBoxFlat.new()
		pb_fill.bg_color = CyberTheme.COLOR_CYAN_GLOW
		pb_fill.corner_radius_top_left = 2
		pb_fill.corner_radius_top_right = 2
		pb_fill.corner_radius_bottom_right = 2
		pb_fill.corner_radius_bottom_left = 2
		_local_download_bar.add_theme_stylebox_override("fill", pb_fill)
		_local_download_box.add_child(_local_download_bar)

		# Row 3: Custom GGUF model path
		var gguf_hdr := Label.new()
		gguf_hdr.text = "Кастомная GGUF-модель (по умолчанию: Qwen2.5-Coder-1.5B):"
		gguf_hdr.add_theme_font_size_override("font_size", 11)
		gguf_hdr.add_theme_color_override("font_color", CyberTheme.get_text_secondary_color())
		c_vbox.add_child(gguf_hdr)

		var gguf_hbox := HBoxContainer.new()
		gguf_hbox.add_theme_constant_override("separation", 6)
		c_vbox.add_child(gguf_hbox)

		_local_gguf_edit = LineEdit.new()
		_local_gguf_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_local_gguf_edit.placeholder_text = "user://models/... или путь к .gguf файлу на диске"
		gguf_hbox.add_child(_local_gguf_edit)

		_local_gguf_browse_btn = Button.new()
		_local_gguf_browse_btn.text = " Обзор... "
		_local_gguf_browse_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_local_gguf_browse_btn.pressed.connect(_on_local_gguf_browse_pressed)
		gguf_hbox.add_child(_local_gguf_browse_btn)

		_local_gguf_clear_btn = Button.new()
		_local_gguf_clear_btn.text = " ✕ "
		_local_gguf_clear_btn.tooltip_text = "Сбросить на встроенную модель"
		_local_gguf_clear_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_local_gguf_clear_btn.pressed.connect(_on_local_gguf_clear_pressed)
		gguf_hbox.add_child(_local_gguf_clear_btn)

		settings_vbox.add_child(_agent_local_card)
		settings_vbox.move_child(_agent_local_card, insert_idx)
		insert_idx += 1

	# 6. Чекбокс автоматического Fallback
	if not _agent_fallback_check:
		_agent_fallback_check = CheckBox.new()
		_agent_fallback_check.name = "AgentFallbackCheck"
		_agent_fallback_check.text = "Автоматически переключаться на локальный ИИ при сбое облака (квота 429 / сбой сети)"
		_agent_fallback_check.add_theme_font_size_override("font_size", 12)
		_agent_fallback_check.add_theme_color_override("font_color", CyberTheme.get_text_primary_color())
		settings_vbox.add_child(_agent_fallback_check)
		settings_vbox.move_child(_agent_fallback_check, insert_idx)
		insert_idx += 1

	_connect_local_llm_signals()

func _find_local_llm_manager() -> Node:
	if is_instance_valid(_local_llm_manager):
		return _local_llm_manager
	if is_inside_tree():
		_local_llm_manager = get_tree().root.find_child("LocalLLMServerManager", true, false)
	return _local_llm_manager

func setup_local_llm(mgr: Node) -> void:
	_local_llm_manager = mgr
	_connect_local_llm_signals()
	_refresh_local_server_status()

func _connect_local_llm_signals() -> void:
	var mgr := _find_local_llm_manager()
	if not mgr:
		return

	if mgr.has_signal("status_changed") and not mgr.is_connected("status_changed", Callable(self, "_on_local_llm_status_changed")):
		mgr.connect("status_changed", Callable(self, "_on_local_llm_status_changed"))
	if mgr.has_signal("download_progress") and not mgr.is_connected("download_progress", Callable(self, "_on_local_llm_download_progress")):
		mgr.connect("download_progress", Callable(self, "_on_local_llm_download_progress"))
	if mgr.has_signal("download_completed") and not mgr.is_connected("download_completed", Callable(self, "_on_local_llm_download_completed")):
		mgr.connect("download_completed", Callable(self, "_on_local_llm_download_completed"))
	if mgr.has_signal("download_failed") and not mgr.is_connected("download_failed", Callable(self, "_on_local_llm_download_failed")):
		mgr.connect("download_failed", Callable(self, "_on_local_llm_download_failed"))
	if mgr.has_signal("server_started") and not mgr.is_connected("server_started", Callable(self, "_on_local_llm_server_started")):
		mgr.connect("server_started", Callable(self, "_on_local_llm_server_started"))
	if mgr.has_signal("server_stopped") and not mgr.is_connected("server_stopped", Callable(self, "_on_local_llm_server_stopped")):
		mgr.connect("server_stopped", Callable(self, "_on_local_llm_server_stopped"))
	if mgr.has_signal("server_error") and not mgr.is_connected("server_error", Callable(self, "_on_local_llm_server_error")):
		mgr.connect("server_error", Callable(self, "_on_local_llm_server_error"))
	if mgr.has_signal("health_checked") and not mgr.is_connected("health_checked", Callable(self, "_on_local_llm_health_checked")):
		mgr.connect("health_checked", Callable(self, "_on_local_llm_health_checked"))

func _refresh_local_server_status() -> void:
	var mgr := _find_local_llm_manager()
	if not is_instance_valid(_local_status_lbl):
		return

	if mgr == null:
		_local_status_lbl.text = "[● СЕРВЕР НЕ СМОНТИРОВАН]"
		_local_status_lbl.add_theme_color_override("font_color", CyberTheme.get_text_muted_color())
		if is_instance_valid(_local_download_box):
			_local_download_box.visible = false
		return

	var st: String = "stopped"
	if mgr.has_method("get_status"):
		st = str(mgr.call("get_status"))
	elif "status" in mgr:
		st = str(mgr.status)

	var is_dl: bool = false
	if mgr.has_method("is_downloading"):
		is_dl = bool(mgr.call("is_downloading"))
	elif "_is_downloading" in mgr:
		is_dl = bool(mgr._is_downloading)

	if is_instance_valid(_local_download_box):
		_local_download_box.visible = is_dl

	var port: int = 8080
	if mgr.has_method("get_server_port"):
		port = int(mgr.call("get_server_port"))

	match st:
		"running":
			_local_status_lbl.text = "[● ГОТОВ // ПОРТ %d]" % port
			_local_status_lbl.add_theme_color_override("font_color", CyberTheme.COLOR_SUCCESS_LED)
		"downloading":
			_local_status_lbl.text = "[● ЗАГРУЗКА МОДЕЛИ...]"
			_local_status_lbl.add_theme_color_override("font_color", CyberTheme.COLOR_AMBER_LED)
		"starting":
			_local_status_lbl.text = "[● ЗАПУСК СЕРВЕРА...]"
			_local_status_lbl.add_theme_color_override("font_color", CyberTheme.COLOR_CYAN_GLOW)
		"error":
			_local_status_lbl.text = "[● ОШИБКА СЕРВЕРА]"
			_local_status_lbl.add_theme_color_override("font_color", CyberTheme.COLOR_RED_LED)
		_:
			_local_status_lbl.text = "[● ОСТАНОВЛЕН]"
			_local_status_lbl.add_theme_color_override("font_color", CyberTheme.get_text_muted_color())

func _on_agent_provider_selected(idx: int) -> void:
	if idx < 0 or idx >= AGENT_PROVIDER_IDS.size():
		return

	# Сохраняем текущие введенные значения в буфер провайдера
	if _settings_manager and not _current_editing_provider.is_empty():
		if is_instance_valid(agent_key_edit) and _current_editing_provider != "local_embedded":
			_settings_manager.set_agent_api_key(_current_editing_provider, agent_key_edit.text.strip_edges())
		if is_instance_valid(agent_model_edit):
			_settings_manager.set_agent_model(_current_editing_provider, agent_model_edit.text.strip_edges())

	var new_prov: String = AGENT_PROVIDER_IDS[idx]
	_current_editing_provider = new_prov
	_update_agent_ui_for_provider(new_prov)

func _update_agent_ui_for_provider(prov_id: String) -> void:
	if not _settings_manager:
		return

	# Загрузка модели для выбранного провайдера
	var m: String = _settings_manager.get_agent_model(prov_id)
	if m.is_empty():
		m = AGENT_DEFAULT_MODELS.get(prov_id, "")
	if is_instance_valid(agent_model_edit):
		agent_model_edit.text = m

	# Загрузка ключа для выбранного провайдера
	var k: String = _settings_manager.get_agent_api_key(prov_id)
	if is_instance_valid(agent_key_edit):
		agent_key_edit.text = k

	var is_local := (prov_id == "local_embedded")
	var is_custom := (prov_id == "custom")

	# Управление видимостью строки API-ключа
	if is_instance_valid(_key_label):
		_key_label.visible = not is_local
	if is_instance_valid(agent_key_edit):
		agent_key_edit.visible = not is_local
	if is_instance_valid(_toggle_key_vis_btn):
		_toggle_key_vis_btn.visible = not is_local

	# Управление видимостью строки Custom Base URL
	if is_instance_valid(_custom_url_label):
		_custom_url_label.visible = is_custom
	if is_instance_valid(_agent_custom_url_edit):
		_agent_custom_url_edit.visible = is_custom
		if is_custom:
			_agent_custom_url_edit.text = str(_settings_manager.get_setting("agent", "custom_base_url", ""))

	# Управление видимостью бейджа Zero-Key
	if is_instance_valid(_agent_zero_key_panel):
		_agent_zero_key_panel.visible = is_local

	# Управление видимостью панели локального сервера
	if is_instance_valid(_agent_local_card):
		_agent_local_card.visible = is_local
		if is_local:
			_refresh_local_server_status()

func _on_toggle_key_visibility_pressed() -> void:
	if not is_instance_valid(agent_key_edit):
		return
	agent_key_edit.secret = not agent_key_edit.secret
	if is_instance_valid(_toggle_key_vis_btn):
		_toggle_key_vis_btn.text = "👁" if agent_key_edit.secret else "🙈"

func _on_local_gguf_browse_pressed() -> void:
	if not is_instance_valid(_local_gguf_dialog):
		_local_gguf_dialog = FileDialog.new()
		_local_gguf_dialog.title = "Выберите файл модели GGUF"
		_local_gguf_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_local_gguf_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_local_gguf_dialog.filters = PackedStringArray(["*.gguf ; GGUF Models"])
		_local_gguf_dialog.file_selected.connect(_on_gguf_file_selected)
		add_child(_local_gguf_dialog)
	_local_gguf_dialog.popup_centered(Vector2(700, 480))

func _on_gguf_file_selected(path: String) -> void:
	if is_instance_valid(_local_gguf_edit):
		_local_gguf_edit.text = path
	if _settings_manager:
		_settings_manager.set_setting("agent", "local_model_path", path, false)
	var mgr := _find_local_llm_manager()
	if mgr and mgr.has_method("set_custom_model_path"):
		mgr.call("set_custom_model_path", path)

func _on_local_gguf_clear_pressed() -> void:
	if is_instance_valid(_local_gguf_edit):
		_local_gguf_edit.text = ""
	if _settings_manager:
		_settings_manager.set_setting("agent", "local_model_path", "", false)
	var mgr := _find_local_llm_manager()
	if mgr and mgr.has_method("set_custom_model_path"):
		mgr.call("set_custom_model_path", "")

func _on_local_llm_status_changed(_new_status: String) -> void:
	_refresh_local_server_status()

func _on_local_llm_download_progress(item_name: String, bytes_rec: int, total_bytes: int, percent: float) -> void:
	if not is_instance_valid(_local_download_box):
		return
	_local_download_box.visible = true
	if is_instance_valid(_local_download_bar):
		_local_download_bar.value = percent
	if is_instance_valid(_local_download_lbl):
		var rec_mb: float = float(bytes_rec) / (1024.0 * 1024.0)
		var tot_mb: float = float(total_bytes) / (1024.0 * 1024.0)
		if tot_mb > 0.0:
			_local_download_lbl.text = "Загрузка %s: %.1f%% (%.1f MB / %.1f MB)" % [item_name, percent, rec_mb, tot_mb]
		else:
			_local_download_lbl.text = "Загрузка %s: %.1f MB" % [item_name, rec_mb]
	_refresh_local_server_status()

func _on_local_llm_download_completed(_item_name: String, _path: String) -> void:
	if is_instance_valid(_local_download_box):
		_local_download_box.visible = false
	_refresh_local_server_status()

func _on_local_llm_download_failed(item_name: String, error_msg: String) -> void:
	if is_instance_valid(_local_download_lbl):
		_local_download_lbl.text = "Ошибка загрузки %s: %s" % [item_name, error_msg]
	_refresh_local_server_status()

func _on_local_llm_server_started(_port: int, _pid: int) -> void:
	_refresh_local_server_status()

func _on_local_llm_server_stopped() -> void:
	_refresh_local_server_status()

func _on_local_llm_server_error(_error_msg: String) -> void:
	_refresh_local_server_status()

func _on_local_llm_health_checked(_is_healthy: bool) -> void:
	_refresh_local_server_status()
