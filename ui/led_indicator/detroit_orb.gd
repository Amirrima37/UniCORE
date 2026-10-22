class_name DetroitOrb
extends Control

## Процедурный круговой LED-индикатор в стиле "Detroit: Become Human"
## Отображает состояние Агента и Ядра:
## IDLE = Спокойное неоновое синее дыхание
## PROCESSING = Вращающееся янтарное/желтое сканирование (Агент думает / компиляция / сохранение)
## SUCCESS = Яркая изумрудно-бирюзовая вспышка готовности
## ERROR = Тревожная красная пульсация сбоя

enum State {
	IDLE,
	PROCESSING,
	SUCCESS,
	ERROR
}

@export var current_state: State = State.IDLE:
	set(val):
		current_state = val
		queue_redraw()

@export var ring_radius: float = 10.0
@export var ring_width: float = 2.5
@export var glow_enabled: bool = true

var _anim_time: float = 0.0
var _spin_angle: float = 0.0
var _revert_timer: float = 0.0
var _revert_to_state: State = State.IDLE

const COLOR_BLUE := Color(0.0, 0.65, 1.0, 1.0)
const COLOR_CYAN := Color(0.0, 0.9, 1.0, 1.0)
const COLOR_AMBER := Color(1.0, 0.72, 0.0, 1.0)
const COLOR_RED := Color(1.0, 0.2, 0.2, 1.0)
const COLOR_EMERALD := Color(0.0, 1.0, 0.65, 1.0)

func _ready() -> void:
	custom_minimum_size = Vector2((ring_radius + ring_width + 4.0) * 2.0, (ring_radius + ring_width + 4.0) * 2.0)
	tooltip_text = "UniCORE Agent Status: ONLINE"

func _process(delta: float) -> void:
	_anim_time += delta

	match current_state:
		State.IDLE:
			_spin_angle += delta * 0.5
		State.PROCESSING:
			_spin_angle += delta * 5.0 # Быстрое вращение в стиле Detroit при сканировании
		State.ERROR:
			_spin_angle += delta * 1.5
		State.SUCCESS:
			_spin_angle += delta * 1.0

	if _revert_timer > 0.0:
		_revert_timer -= delta
		if _revert_timer <= 0.0:
			current_state = _revert_to_state

	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var base_color: Color
	var pulse: float = 1.0

	match current_state:
		State.IDLE:
			pulse = 0.72 + 0.28 * sin(_anim_time * 2.2)
			base_color = COLOR_CYAN.lerp(COLOR_BLUE, 0.45)
		State.PROCESSING:
			pulse = 0.85 + 0.15 * sin(_anim_time * 10.0)
			base_color = COLOR_AMBER
		State.SUCCESS:
			pulse = 1.0
			base_color = COLOR_EMERALD
		State.ERROR:
			# Двойная пульсация стресса в стиле Detroit
			pulse = 0.35 + 0.65 * abs(sin(_anim_time * 10.0))
			base_color = COLOR_RED

	# 1. Внешний мягкий ореол свечения (Multi-layered Bloom Halo)
	if glow_enabled:
		var halo_outer := base_color
		halo_outer.a = 0.12 * pulse
		draw_circle(center, ring_radius + ring_width + 4.0, halo_outer)

		var halo_inner := base_color
		halo_inner.a = 0.24 * pulse
		draw_circle(center, ring_radius + ring_width + 1.0, halo_inner)

	# 2. Фоновое кольцо (затененная подложка LED-канала)
	var bg_groove_color := Color(0.01, 0.03, 0.06, 0.65)
	draw_arc(center, ring_radius, 0.0, TAU, 48, bg_groove_color, ring_width + 1.5, true)

	var bg_ring_color := base_color
	bg_ring_color.a = 0.18
	draw_arc(center, ring_radius, 0.0, TAU, 48, bg_ring_color, ring_width, true)

	# 3. Активная светодиодная дуга (Detroit LED Sector)
	if current_state == State.PROCESSING:
		# Вращающийся янтарный сектор сканирования Коннора
		var sweep_len := PI * 1.25
		var active_color := base_color
		active_color.a = 0.95 * pulse
		draw_arc(center, ring_radius, _spin_angle, _spin_angle + sweep_len, 28, active_color, ring_width + 0.6, true)

		# Яркий маяк на конце дуги сканирования
		var head_pos := center + Vector2(cos(_spin_angle + sweep_len), sin(_spin_angle + sweep_len)) * ring_radius
		draw_circle(head_pos, ring_width * 0.95, Color(1.0, 0.95, 0.8, pulse))
		draw_circle(head_pos, ring_width * 0.5, Color.WHITE)
	elif current_state == State.ERROR:
		# Мигающее разорванное кольцо тревоги
		var err_color := base_color
		err_color.a = pulse
		draw_arc(center, ring_radius, _spin_angle, _spin_angle + TAU * 0.75, 24, err_color, ring_width + 0.4, true)
	elif current_state == State.SUCCESS:
		# Яркое изумрудное кольцо готовности / успеха
		var main_color := base_color
		main_color.a = 0.96 * pulse
		draw_arc(center, ring_radius, 0.0, TAU, 36, main_color, ring_width + 0.6, true)

		# Тонкий белый/изумрудный импульсный контур
		draw_arc(center, ring_radius - 0.5, 0.0, TAU, 36, Color(1.0, 1.0, 1.0, 0.65 * pulse), ring_width * 0.45, true)

		# Вспыхивающая светящаяся точка
		var head_pos := center + Vector2(cos(_spin_angle), sin(_spin_angle)) * ring_radius
		draw_circle(head_pos, ring_width * 0.85, Color(0.85, 1.0, 0.9, pulse))
	else:
		# Полное неоновое кольцо IDLE
		var main_color := base_color
		main_color.a = 0.88 * pulse
		draw_arc(center, ring_radius, 0.0, TAU, 32, main_color, ring_width, true)

		# Тонкий внутренний контур
		draw_arc(center, ring_radius, 0.0, TAU, 32, Color(0.6, 0.95, 1.0, 0.35 * pulse), ring_width * 0.4, true)

		# Акцентная светящаяся орбитальная точка
		var head_pos := center + Vector2(cos(_spin_angle), sin(_spin_angle)) * ring_radius
		var dot_color := Color.WHITE.lerp(base_color, 0.25)
		dot_color.a = 0.95 * pulse
		draw_circle(head_pos, ring_width * 0.75, dot_color)

	# 4. Центральная микро-точка ядра
	var core_color := base_color
	core_color.a = 0.55 * pulse
	draw_circle(center, ring_radius * 0.22, core_color)

func set_idle() -> void:
	current_state = State.IDLE
	tooltip_text = "UniCORE Агент: ГОТОВ [IDLE] // СИСТЕМА ОПТИМАЛЬНА"

func set_processing(reason: String = "Обработка...") -> void:
	current_state = State.PROCESSING
	tooltip_text = "UniCORE: %s // ВЫЧИСЛЕНИЕ" % reason

func flash_success(message: String = "Готово!", duration: float = 2.5) -> void:
	current_state = State.SUCCESS
	tooltip_text = "UniCORE: %s // УСПЕШНО" % message
	_revert_timer = duration
	_revert_to_state = State.IDLE

func flash_error(message: String = "Ошибка!", duration: float = 3.5) -> void:
	current_state = State.ERROR
	tooltip_text = "UniCORE Ошибка: %s // АНОМАЛИЯ" % message
	_revert_timer = duration
	_revert_to_state = State.IDLE
