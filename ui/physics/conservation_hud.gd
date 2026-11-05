class_name ConservationHUD
extends "res://ui/theme/glass_panel.gd"

## Монитор Физических Инвариантов & Радиационной Безопасности (ConservationHUD)
## Стиль: Detroit Liquid Glass
## Отображает:
## - LED Pill дрейфа энергии (dE) со спектральным переключением (Изумруд / Янтарь / Рубин)
## - Индикаторы фундаментальных законов сохранения (Энергия E, Импульс P, Момент L, Температура T)
## - Радиационный монитор / Счетчик Гейгера (CPS) со световой вспышкой и звуковым щелчком

@onready var pill_energy_drift: PanelContainer = $MarginContainer/VBoxContainer/PillEnergyDrift
@onready var label_energy_drift: Label = $MarginContainer/VBoxContainer/PillEnergyDrift/LabelEnergyDrift
@onready var label_etot: Label = $MarginContainer/VBoxContainer/GridContainer/LabelEtotVal
@onready var label_impulse: Label = $MarginContainer/VBoxContainer/GridContainer/LabelImpulseVal
@onready var label_angular: Label = $MarginContainer/VBoxContainer/GridContainer/LabelAngularVal
@onready var label_temp: Label = $MarginContainer/VBoxContainer/GridContainer/LabelTempVal
@onready var geiger_icon: Label = $MarginContainer/VBoxContainer/HBoxGeiger/GeigerIcon
@onready var geiger_led: ColorRect = $MarginContainer/VBoxContainer/HBoxGeiger/GeigerLED
@onready var geiger_cps: Label = $MarginContainer/VBoxContainer/HBoxGeiger/GeigerCPS

var _event_bus: Node = null
var _audio_player: AudioStreamPlayer = null
var _geiger_click_sound: AudioStreamWAV = null
var _drift_pulse_tween: Tween = null
var _geiger_flash_tween: Tween = null
var _recent_decay_count: int = 0
var _cps_timer: float = 0.0

func _ready() -> void:
	super._ready()
	custom_accent_color = DesignTokens.COLOR_ACCENT_EMERALD_FLUX
	panel_corner_radius = 8.0
	blur_strength = 2.5
	bevel_width = 14.0

	_setup_audio_click()
	_apply_fonts_and_layout()
	_update_drift_pill(0.0001)

func _process(delta: float) -> void:
	_cps_timer += delta
	if _cps_timer >= 1.0:
		geiger_cps.text = "%d CPS" % _recent_decay_count
		_recent_decay_count = 0
		_cps_timer = 0.0

func setup(event_bus: Node) -> void:
	_event_bus = event_bus
	if not _event_bus:
		return

	if _event_bus.has_method("subscribe"):
		_event_bus.subscribe("physics_invariants_updated", _on_invariants_updated)
		_event_bus.subscribe("nuclear_radiation_pulse", _on_radiation_pulse)
		_event_bus.subscribe("nuclear_decay_event", _on_radiation_pulse)

func _on_invariants_updated(payload: Dictionary) -> void:
	# payload: {"e_tot": float, "energy_drift_ratio": float, "p_mag": float, "l_mag": float, "temp": float}
	var drift_ratio: float = float(payload.get("energy_drift_ratio", 0.0))
	var drift_pct: float = drift_ratio * 100.0
	_update_drift_pill(drift_pct)

	if payload.has("e_tot"):
		label_etot.text = "%+.3f J" % float(payload["e_tot"])
	if payload.has("p_mag"):
		label_impulse.text = "%.4f kg·m/s" % float(payload["p_mag"])
	if payload.has("l_mag"):
		label_angular.text = "%.3f kg·m²/s" % float(payload["l_mag"])
	if payload.has("temp"):
		label_temp.text = "%.2f K" % float(payload["temp"])

func _update_drift_pill(drift_pct: float) -> void:
	var abs_drift: float = absf(drift_pct)
	var sign_str: String = "+" if drift_pct >= 0.0 else "-"
	
	if is_instance_valid(_drift_pulse_tween):
		_drift_pulse_tween.kill()

	if abs_drift < 0.05:
		# Стабильно: Изумрудный поток
		label_energy_drift.text = "dE = %s%.4f%% [СТАБИЛЬНО]" % [sign_str, abs_drift]
		label_energy_drift.modulate = DesignTokens.COLOR_ACCENT_EMERALD_FLUX
		pill_energy_drift.self_modulate = Color(0.0, 0.92, 0.52, 0.18)
	elif abs_drift <= 0.5:
		# Предупреждение: Янтарный спектр
		label_energy_drift.text = "dE = %s%.3f%% [ДРЕЙФ]" % [sign_str, abs_drift]
		label_energy_drift.modulate = DesignTokens.COLOR_ACCENT_SPECTRAL_AMBER
		pill_energy_drift.self_modulate = Color(1.0, 0.73, 0.05, 0.22)
	else:
		# Критично: Рубиновая пульсация
		label_energy_drift.text = "dE = %s%.2f%% [КРИТИЧНО]" % [sign_str, abs_drift]
		label_energy_drift.modulate = DesignTokens.COLOR_ACCENT_CRIMSON_VALVE
		pill_energy_drift.self_modulate = Color(1.0, 0.22, 0.28, 0.35)

		_drift_pulse_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		_drift_pulse_tween.tween_property(pill_energy_drift, "self_modulate:a", 0.15, 0.3)
		_drift_pulse_tween.tween_property(pill_energy_drift, "self_modulate:a", 0.5, 0.3)

func _on_radiation_pulse(payload: Dictionary) -> void:
	_recent_decay_count += int(payload.get("decay_count", 1))

	# Световая вспышка светодиода
	if is_instance_valid(_geiger_flash_tween):
		_geiger_flash_tween.kill()

	geiger_led.modulate = Color(1.5, 1.2, 0.2, 1.0) # яркая желто-янтарная вспышка
	_geiger_flash_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_geiger_flash_tween.tween_property(geiger_led, "modulate", Color(0.2, 0.25, 0.3, 0.4), 0.12)

	# Воспроизведение щелчка
	if is_instance_valid(_audio_player) and _geiger_click_sound:
		_audio_player.play()

func _setup_audio_click() -> void:
	# Процедурная генерация 40-сэмплового импульса (клик Гейгера)
	_audio_player = AudioStreamPlayer.new()
	_audio_player.volume_db = -18.0
	add_child(_audio_player)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = 22050
	wav.stereo = false

	var samples := PackedByteArray()
	for i in range(48):
		var decay: float = 1.0 - float(i) / 48.0
		var noise: float = ((randf() * 2.0) - 1.0) * decay
		var byte_val: int = int(clamp((noise * 0.5 + 0.5) * 255.0, 0.0, 255.0))
		samples.append(byte_val)

	wav.data = samples
	_geiger_click_sound = wav
	_audio_player.stream = _geiger_click_sound

func _apply_fonts_and_layout() -> void:
	var mono_font: Font = DesignTokens.get_font_mono()
	if mono_font:
		label_energy_drift.add_theme_font_override("font", mono_font)
		label_etot.add_theme_font_override("font", mono_font)
		label_impulse.add_theme_font_override("font", mono_font)
		label_angular.add_theme_font_override("font", mono_font)
		label_temp.add_theme_font_override("font", mono_font)
		geiger_cps.add_theme_font_override("font", mono_font)

	geiger_icon.modulate = DesignTokens.COLOR_ACCENT_SPECTRAL_AMBER
	geiger_led.modulate = Color(0.2, 0.25, 0.3, 0.4)
