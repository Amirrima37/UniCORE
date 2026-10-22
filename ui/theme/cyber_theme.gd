class_name CyberTheme
extends RefCounted

## Библиотека стилей "Detroit: Become Human" для UniCORE
## Реализует эстетику "Liquid Glass":
## - Белая тема CyberLife (арктическое/молочное полупрозрачное стекло)
## - Темная тема Cyber Void (глубокое темное стекло)
## - Сверхяркие неоновые LED-акценты (Cyan, Electric Blue, Emerald, Amber, Red)
## - Динамическая прозрачность и интенсивность свечения контуров и теней.

# --- LED Неоновые Цвета ---
const COLOR_CYAN_GLOW := Color(0.0, 0.9, 1.0, 1.0)
const COLOR_ELECTRIC_BLUE := Color(0.1, 0.6, 1.0, 1.0)
const COLOR_BLUE_LED := Color(0.1, 0.6, 1.0, 1.0)
const COLOR_SUCCESS_LED := Color(0.0, 0.9, 0.45, 1.0)
const COLOR_AMBER_LED := Color(1.0, 0.7, 0.0, 1.0)
const COLOR_AMBER_GLOW := Color(1.0, 0.8, 0.1, 0.95)
const COLOR_AMBER_BG := Color(0.12, 0.08, 0.02, 0.88)
const COLOR_RED_LED := Color(1.0, 0.2, 0.25, 1.0)

# --- Базовые цвета Liquid Glass ---
const COLOR_GLASS_CYBERLIFE_BASE := Color(0.92, 0.95, 0.99)
const COLOR_GLASS_VOID_BASE := Color(0.04, 0.08, 0.14)
const COLOR_GLASS_BG := Color(0.04, 0.07, 0.13, 0.88)
const COLOR_GLASS_HEADER := Color(0.05, 0.09, 0.16, 0.92)
const COLOR_GLASS_BORDER := Color(0.0, 0.8, 1.0, 0.35)
const COLOR_GLASS_BORDER_HOVER := Color(0.0, 0.95, 1.0, 0.9)

# --- Цвета текста ---
const COLOR_TEXT_PRIMARY := Color(0.95, 0.97, 1.0, 1.0)
const COLOR_TEXT_CYAN := Color(0.4, 0.85, 1.0, 1.0)
const COLOR_TEXT_MUTED := Color(0.65, 0.72, 0.8, 0.7)
const COLOR_TEXT_DARK := Color(0.08, 0.12, 0.18, 1.0)
const COLOR_TEXT_DARK_MUTED := Color(0.35, 0.42, 0.52, 0.85)

# --- Динамические параметры темы (свойства экземпляра) ---
var theme_name: String:
	get: return get_theme_name()
	set(v): set_theme_name(v)

var glass_opacity: float:
	get: return get_glass_opacity()
	set(v): set_glass_opacity(v)

var led_intensity: float:
	get: return get_led_intensity()
	set(v): set_led_intensity(v)

# --- Динамические параметры темы (через Engine metadata для совместимости с Godot 4.0) ---
static func _get_state() -> Dictionary:
	if not Engine.has_meta("_cyber_theme_state"):
		Engine.set_meta("_cyber_theme_state", {
			"theme_name": "cyberlife_white",
			"glass_opacity": 0.75,
			"led_intensity": 1.0
		})
	return Engine.get_meta("_cyber_theme_state")

# --- Статические геттеры и сеттеры параметров темы ---
static func get_theme_name() -> String:
	return _get_state()["theme_name"]

static func set_theme_name(val: String) -> void:
	var t: String = val.strip_edges().to_lower()
	if t == "cyberlife_white" or t == "cyber_void":
		_get_state()["theme_name"] = t

static func get_glass_opacity() -> float:
	return _get_state()["glass_opacity"]

static func set_glass_opacity(val: float) -> void:
	_get_state()["glass_opacity"] = clampf(val, 0.2, 0.95)

static func get_led_intensity() -> float:
	return _get_state()["led_intensity"]

static func set_led_intensity(val: float) -> void:
	_get_state()["led_intensity"] = clampf(val, 0.5, 2.0)

static func is_white_theme() -> bool:
	return get_theme_name() == "cyberlife_white"

static func get_text_primary_color() -> Color:
	return COLOR_TEXT_DARK if is_white_theme() else COLOR_TEXT_PRIMARY

static func get_text_muted_color() -> Color:
	return COLOR_TEXT_DARK_MUTED if is_white_theme() else COLOR_TEXT_MUTED

static func get_default_glass_bg() -> Color:
	var opacity := get_glass_opacity()
	if is_white_theme():
		return Color(COLOR_GLASS_CYBERLIFE_BASE.r, COLOR_GLASS_CYBERLIFE_BASE.g, COLOR_GLASS_CYBERLIFE_BASE.b, opacity)
	else:
		return Color(COLOR_GLASS_VOID_BASE.r, COLOR_GLASS_VOID_BASE.g, COLOR_GLASS_VOID_BASE.b, opacity)

static func apply_interface_settings(settings: Dictionary) -> void:
	if settings.has("theme"):
		set_theme_name(str(settings["theme"]))
	if settings.has("glass_opacity"):
		set_glass_opacity(float(settings["glass_opacity"]))
	if settings.has("led_intensity"):
		set_led_intensity(float(settings["led_intensity"]))

static func create_glass_panel_style(
	accent_color: Color = Color(-1, -1, -1, -1),
	bg_color: Color = Color(-1, -1, -1, -1),
	border_width: int = 1,
	corner_radius: int = 4,
	shadow_size: int = 4,
	shadow_color: Color = Color(-1, -1, -1, -1)
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()

	var final_bg: Color
	if bg_color.a < 0:
		final_bg = get_default_glass_bg()
	else:
		final_bg = bg_color
	sb.bg_color = final_bg

	var final_border: Color
	if accent_color.a < 0:
		if is_white_theme():
			final_border = Color(COLOR_ELECTRIC_BLUE.r, COLOR_ELECTRIC_BLUE.g, COLOR_ELECTRIC_BLUE.b, 0.65)
		else:
			final_border = COLOR_GLASS_BORDER
	else:
		final_border = accent_color

	sb.border_width_left = border_width
	sb.border_width_top = border_width
	sb.border_width_right = border_width
	sb.border_width_bottom = border_width
	sb.border_color = final_border

	sb.corner_radius_top_left = corner_radius
	sb.corner_radius_top_right = corner_radius
	sb.corner_radius_bottom_right = corner_radius
	sb.corner_radius_bottom_left = corner_radius

	if shadow_size > 0:
		var intensity := get_led_intensity()
		var final_shadow: Color
		if shadow_color.a < 0:
			var glow_alpha := clampf(0.25 * intensity, 0.05, 0.85)
			final_shadow = Color(final_border.r, final_border.g, final_border.b, glow_alpha)
		else:
			final_shadow = shadow_color
		sb.shadow_color = final_shadow
		sb.shadow_size = int(round(shadow_size * clampf(intensity, 0.5, 2.0)))

	sb.set_content_margin_all(12)
	return sb

static func create_cyber_button_style(
	bg_color: Color = Color(-1, -1, -1, -1),
	border_color: Color = Color(-1, -1, -1, -1),
	border_width: int = 1,
	corner_radius: int = 4,
	glow_size: int = 0,
	glow_color: Color = Color(-1, -1, -1, -1)
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()

	var final_bg: Color
	if bg_color.a < 0:
		if is_white_theme():
			final_bg = Color(0.86, 0.91, 0.97, clampf(get_glass_opacity(), 0.35, 0.95))
		else:
			final_bg = Color(0.06, 0.11, 0.2, clampf(get_glass_opacity(), 0.35, 0.95))
	else:
		final_bg = bg_color
	sb.bg_color = final_bg

	var final_border: Color
	if border_color.a < 0:
		if is_white_theme():
			final_border = Color(0.1, 0.6, 1.0, 0.6)
		else:
			final_border = Color(0.0, 0.75, 1.0, 0.4)
	else:
		final_border = border_color

	sb.border_width_left = border_width
	sb.border_width_top = border_width
	sb.border_width_right = border_width
	sb.border_width_bottom = border_width
	sb.border_color = final_border

	sb.corner_radius_top_left = corner_radius
	sb.corner_radius_top_right = corner_radius
	sb.corner_radius_bottom_right = corner_radius
	sb.corner_radius_bottom_left = corner_radius

	if glow_size > 0:
		var intensity := get_led_intensity()
		var final_glow: Color
		if glow_color.a < 0:
			final_glow = Color(final_border.r, final_border.g, final_border.b, clampf(0.25 * intensity, 0.05, 0.9))
		else:
			final_glow = glow_color
		sb.shadow_color = final_glow
		sb.shadow_size = int(round(glow_size * clampf(intensity, 0.5, 2.0)))

	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

static func create_amber_panel_style(
	border_width: int = 1,
	corner_radius: int = 4
) -> StyleBoxFlat:
	return create_glass_panel_style(
		COLOR_AMBER_GLOW,
		COLOR_AMBER_BG,
		border_width,
		corner_radius,
		4,
		Color(1.0, 0.75, 0.0, clampf(0.25 * get_led_intensity(), 0.05, 0.9))
	)

static func create_amber_button_style(
	corner_radius: int = 4
) -> StyleBoxFlat:
	return create_cyber_button_style(
		Color(0.18, 0.12, 0.02, 0.8),
		COLOR_AMBER_GLOW,
		1,
		corner_radius,
		2,
		Color(1.0, 0.75, 0.0, clampf(0.25 * get_led_intensity(), 0.05, 0.9))
	)

static func create_input_style(is_focused: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var opacity := get_glass_opacity()
	var intensity := get_led_intensity()

	var b_color: Color
	if is_white_theme():
		sb.bg_color = Color(0.95, 0.97, 1.0, clampf(opacity, 0.45, 0.98))
		b_color = COLOR_ELECTRIC_BLUE if is_focused else Color(0.25, 0.55, 0.85, 0.5)
		if is_focused:
			sb.shadow_color = Color(COLOR_CYAN_GLOW.r, COLOR_CYAN_GLOW.g, COLOR_CYAN_GLOW.b, clampf(0.3 * intensity, 0.05, 0.9))
			sb.shadow_size = int(round(4 * clampf(intensity, 0.5, 2.0)))
	else:
		sb.bg_color = Color(0.02, 0.04, 0.08, clampf(opacity, 0.45, 0.98))
		b_color = COLOR_CYAN_GLOW if is_focused else Color(0.0, 0.7, 0.9, 0.45)
		if is_focused:
			sb.shadow_color = Color(0.0, 0.85, 1.0, clampf(0.25 * intensity, 0.05, 0.9))
			sb.shadow_size = int(round(4 * clampf(intensity, 0.5, 2.0)))

	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = b_color
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_right = 4
	sb.corner_radius_bottom_left = 4

	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb

static func build_theme() -> Theme:
	var theme := Theme.new()
	var is_white := is_white_theme()
	var opacity := get_glass_opacity()
	var intensity := get_led_intensity()

	# 1. PanelContainer
	theme.set_stylebox("panel", "PanelContainer", create_glass_panel_style())

	# 2. Button
	var btn_normal: StyleBoxFlat
	var btn_hover: StyleBoxFlat
	var btn_pressed: StyleBoxFlat
	var btn_disabled: StyleBoxFlat

	if is_white:
		btn_normal = create_cyber_button_style(Color(0.88, 0.93, 0.98, opacity), Color(0.2, 0.6, 0.95, 0.5))
		btn_hover = create_cyber_button_style(Color(0.82, 0.9, 0.98, min(opacity + 0.1, 1.0)), COLOR_ELECTRIC_BLUE, 1, 4, 3, Color(0.0, 0.75, 1.0, 0.3 * intensity))
		btn_pressed = create_cyber_button_style(Color(0.25, 0.65, 0.95, 0.95), COLOR_CYAN_GLOW, 2, 4, 5, Color(0.0, 0.9, 1.0, 0.45 * intensity))
		btn_disabled = create_cyber_button_style(Color(0.9, 0.92, 0.95, 0.4), Color(0.7, 0.75, 0.8, 0.25))
	else:
		btn_normal = create_cyber_button_style(Color(0.06, 0.11, 0.2, opacity), Color(0.0, 0.75, 1.0, 0.4))
		btn_hover = create_cyber_button_style(Color(0.1, 0.2, 0.35, min(opacity + 0.1, 1.0)), COLOR_GLASS_BORDER_HOVER, 1, 4, 3, Color(0.0, 0.85, 1.0, 0.3 * intensity))
		btn_pressed = create_cyber_button_style(Color(0.0, 0.45, 0.7, 0.95), COLOR_CYAN_GLOW, 2, 4, 5, Color(0.0, 0.9, 1.0, 0.45 * intensity))
		btn_disabled = create_cyber_button_style(Color(0.04, 0.06, 0.1, 0.4), Color(0.2, 0.3, 0.4, 0.2))

	var btn_focus := StyleBoxEmpty.new()
	theme.set_stylebox("normal", "Button", btn_normal)
	theme.set_stylebox("hover", "Button", btn_hover)
	theme.set_stylebox("pressed", "Button", btn_pressed)
	theme.set_stylebox("disabled", "Button", btn_disabled)
	theme.set_stylebox("focus", "Button", btn_focus)

	if is_white:
		theme.set_color("font_color", "Button", COLOR_TEXT_DARK)
		theme.set_color("font_hover_color", "Button", COLOR_ELECTRIC_BLUE)
		theme.set_color("font_pressed_color", "Button", Color.WHITE)
		theme.set_color("font_disabled_color", "Button", Color(0.55, 0.6, 0.65, 0.5))
	else:
		theme.set_color("font_color", "Button", COLOR_TEXT_PRIMARY)
		theme.set_color("font_hover_color", "Button", COLOR_CYAN_GLOW)
		theme.set_color("font_pressed_color", "Button", Color.WHITE)
		theme.set_color("font_disabled_color", "Button", Color(0.5, 0.5, 0.6, 0.5))

	# 3. LineEdit
	theme.set_stylebox("normal", "LineEdit", create_input_style(false))
	theme.set_stylebox("focus", "LineEdit", create_input_style(true))
	theme.set_stylebox("read_only", "LineEdit", create_input_style(false))
	if is_white:
		theme.set_color("font_color", "LineEdit", COLOR_TEXT_DARK)
		theme.set_color("placeholder_color", "LineEdit", Color(0.4, 0.5, 0.6, 0.6))
		theme.set_color("caret_color", "LineEdit", COLOR_ELECTRIC_BLUE)
	else:
		theme.set_color("font_color", "LineEdit", COLOR_TEXT_PRIMARY)
		theme.set_color("placeholder_color", "LineEdit", Color(0.4, 0.55, 0.7, 0.6))
		theme.set_color("caret_color", "LineEdit", COLOR_CYAN_GLOW)

	# 4. Label
	theme.set_color("font_color", "Label", COLOR_TEXT_DARK if is_white else COLOR_TEXT_PRIMARY)

	# 5. TabContainer
	var tab_selected: StyleBoxFlat
	var tab_unselected: StyleBoxFlat
	var tab_hovered: StyleBoxFlat

	if is_white:
		tab_selected = create_cyber_button_style(Color(0.82, 0.9, 0.98, 0.95), COLOR_ELECTRIC_BLUE, 2)
		tab_unselected = create_cyber_button_style(Color(0.9, 0.93, 0.97, opacity * 0.8), Color(0.3, 0.6, 0.9, 0.3), 1)
		tab_hovered = create_cyber_button_style(Color(0.86, 0.92, 0.98, 0.9), COLOR_CYAN_GLOW, 1)
		theme.set_color("font_selected_color", "TabContainer", COLOR_ELECTRIC_BLUE)
		theme.set_color("font_unselected_color", "TabContainer", Color(0.35, 0.42, 0.5, 0.8))
		theme.set_color("font_hovered_color", "TabContainer", COLOR_CYAN_GLOW)
	else:
		tab_selected = create_cyber_button_style(Color(0.08, 0.16, 0.28, 0.9), COLOR_CYAN_GLOW, 2)
		tab_unselected = create_cyber_button_style(Color(0.04, 0.07, 0.12, opacity * 0.8), Color(0.0, 0.6, 0.8, 0.25), 1)
		tab_hovered = create_cyber_button_style(Color(0.06, 0.13, 0.24, 0.85), COLOR_GLASS_BORDER_HOVER, 1)
		theme.set_color("font_selected_color", "TabContainer", COLOR_CYAN_GLOW)
		theme.set_color("font_unselected_color", "TabContainer", COLOR_TEXT_MUTED)
		theme.set_color("font_hovered_color", "TabContainer", Color.WHITE)

	theme.set_stylebox("panel", "TabContainer", create_glass_panel_style(COLOR_GLASS_BORDER, Color(-1, -1, -1, -1), 1, 6))
	theme.set_stylebox("tab_selected", "TabContainer", tab_selected)
	theme.set_stylebox("tab_unselected", "TabContainer", tab_unselected)
	theme.set_stylebox("tab_hovered", "TabContainer", tab_hovered)

	# 6. PopupMenu / OptionButton
	var popup_panel: StyleBoxFlat
	var popup_hover: StyleBoxFlat
	if is_white:
		popup_panel = create_glass_panel_style(COLOR_ELECTRIC_BLUE, Color(0.94, 0.96, 0.99, 0.95), 1, 4)
		popup_hover = create_cyber_button_style(Color(0.78, 0.88, 0.98, 0.85), COLOR_CYAN_GLOW)
		theme.set_color("font_color", "PopupMenu", COLOR_TEXT_DARK)
		theme.set_color("font_hover_color", "PopupMenu", COLOR_ELECTRIC_BLUE)
	else:
		popup_panel = create_glass_panel_style(COLOR_CYAN_GLOW, Color(0.03, 0.06, 0.1, 0.95), 1, 4)
		popup_hover = create_cyber_button_style(Color(0.0, 0.35, 0.6, 0.8), COLOR_CYAN_GLOW)
		theme.set_color("font_color", "PopupMenu", COLOR_TEXT_PRIMARY)
		theme.set_color("font_hover_color", "PopupMenu", Color.WHITE)

	theme.set_stylebox("panel", "PopupMenu", popup_panel)
	theme.set_stylebox("hover", "PopupMenu", popup_hover)

	# 7. CheckBox
	if is_white:
		theme.set_color("font_color", "CheckBox", COLOR_TEXT_DARK)
		theme.set_color("font_hover_color", "CheckBox", COLOR_ELECTRIC_BLUE)
		theme.set_color("font_pressed_color", "CheckBox", COLOR_ELECTRIC_BLUE)
	else:
		theme.set_color("font_color", "CheckBox", COLOR_TEXT_PRIMARY)
		theme.set_color("font_hover_color", "CheckBox", COLOR_CYAN_GLOW)
		theme.set_color("font_pressed_color", "CheckBox", COLOR_CYAN_GLOW)

	# 8. HSlider
	var slider_bg := StyleBoxFlat.new()
	if is_white:
		slider_bg.bg_color = Color(0.82, 0.88, 0.94, 0.7)
		slider_bg.border_color = Color(0.2, 0.55, 0.85, 0.4)
	else:
		slider_bg.bg_color = Color(0.1, 0.18, 0.28, 0.7)
		slider_bg.border_color = Color(0.0, 0.7, 0.9, 0.3)
	slider_bg.border_width_left = 1
	slider_bg.border_width_top = 1
	slider_bg.border_width_right = 1
	slider_bg.border_width_bottom = 1
	slider_bg.corner_radius_top_left = 3
	slider_bg.corner_radius_top_right = 3
	slider_bg.corner_radius_bottom_right = 3
	slider_bg.corner_radius_bottom_left = 3
	slider_bg.content_margin_top = 4
	slider_bg.content_margin_bottom = 4
	theme.set_stylebox("slider", "HSlider", slider_bg)

	# 9. VScrollBar & HScrollBar
	var scroll_track := StyleBoxFlat.new()
	scroll_track.bg_color = Color(0.85, 0.9, 0.95, 0.5) if is_white else Color(0.02, 0.04, 0.08, 0.5)
	scroll_track.corner_radius_top_left = 3
	scroll_track.corner_radius_top_right = 3
	scroll_track.corner_radius_bottom_right = 3
	scroll_track.corner_radius_bottom_left = 3

	var grabber_normal := StyleBoxFlat.new()
	grabber_normal.bg_color = Color(0.2, 0.6, 0.9, 0.6) if is_white else Color(0.0, 0.6, 0.85, 0.5)
	grabber_normal.border_width_left = 1
	grabber_normal.border_width_top = 1
	grabber_normal.border_width_right = 1
	grabber_normal.border_width_bottom = 1
	grabber_normal.border_color = COLOR_ELECTRIC_BLUE if is_white else Color(0.0, 0.85, 1.0, 0.4)
	grabber_normal.corner_radius_top_left = 3
	grabber_normal.corner_radius_top_right = 3
	grabber_normal.corner_radius_bottom_right = 3
	grabber_normal.corner_radius_bottom_left = 3

	var grabber_hover := StyleBoxFlat.new()
	grabber_hover.bg_color = COLOR_ELECTRIC_BLUE if is_white else Color(0.0, 0.8, 1.0, 0.8)
	grabber_hover.border_width_left = 1
	grabber_hover.border_width_top = 1
	grabber_hover.border_width_right = 1
	grabber_hover.border_width_bottom = 1
	grabber_hover.border_color = COLOR_CYAN_GLOW
	grabber_hover.corner_radius_top_left = 3
	grabber_hover.corner_radius_top_right = 3
	grabber_hover.corner_radius_bottom_right = 3
	grabber_hover.corner_radius_bottom_left = 3

	var grabber_pressed := StyleBoxFlat.new()
	grabber_pressed.bg_color = COLOR_CYAN_GLOW
	grabber_pressed.corner_radius_top_left = 3
	grabber_pressed.corner_radius_top_right = 3
	grabber_pressed.corner_radius_bottom_right = 3
	grabber_pressed.corner_radius_bottom_left = 3

	for sb_type in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", sb_type, scroll_track)
		theme.set_stylebox("scroll_focus", sb_type, scroll_track)
		theme.set_stylebox("grabber", sb_type, grabber_normal)
		theme.set_stylebox("grabber_highlight", sb_type, grabber_hover)
		theme.set_stylebox("grabber_pressed", sb_type, grabber_pressed)

	# 10. Separators
	var sep_style := StyleBoxLine.new()
	sep_style.color = Color(0.2, 0.55, 0.85, 0.35) if is_white else Color(0.0, 0.8, 1.0, 0.25)
	sep_style.thickness = 1
	theme.set_stylebox("separator", "HSeparator", sep_style)

	var vsep_style := StyleBoxLine.new()
	vsep_style.color = Color(0.2, 0.55, 0.85, 0.35) if is_white else Color(0.0, 0.8, 1.0, 0.25)
	vsep_style.thickness = 1
	vsep_style.vertical = true
	theme.set_stylebox("separator", "VSeparator", vsep_style)

	# 11. TooltipPanel
	var tooltip_box := create_glass_panel_style(
		COLOR_ELECTRIC_BLUE if is_white else COLOR_CYAN_GLOW,
		Color(0.95, 0.97, 1.0, 0.96) if is_white else Color(0.02, 0.05, 0.1, 0.95),
		1,
		4
	)
	tooltip_box.set_content_margin_all(8)
	theme.set_stylebox("panel", "TooltipPanel", tooltip_box)
	theme.set_color("font_color", "TooltipLabel", COLOR_TEXT_DARK if is_white else COLOR_TEXT_PRIMARY)

	# 12. ProgressBar
	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.85, 0.9, 0.95, 0.85) if is_white else Color(0.03, 0.06, 0.1, 0.85)
	pb_bg.border_width_left = 1
	pb_bg.border_width_top = 1
	pb_bg.border_width_right = 1
	pb_bg.border_width_bottom = 1
	pb_bg.border_color = Color(0.2, 0.55, 0.85, 0.35) if is_white else Color(0.0, 0.7, 0.9, 0.3)
	pb_bg.corner_radius_top_left = 3
	pb_bg.corner_radius_top_right = 3
	pb_bg.corner_radius_bottom_right = 3
	pb_bg.corner_radius_bottom_left = 3

	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = COLOR_ELECTRIC_BLUE if is_white else COLOR_CYAN_GLOW
	pb_fill.corner_radius_top_left = 3
	pb_fill.corner_radius_top_right = 3
	pb_fill.corner_radius_bottom_right = 3
	pb_fill.corner_radius_bottom_left = 3

	theme.set_stylebox("background", "ProgressBar", pb_bg)
	theme.set_stylebox("fill", "ProgressBar", pb_fill)
	theme.set_color("font_color", "ProgressBar", Color.WHITE)

	return theme
