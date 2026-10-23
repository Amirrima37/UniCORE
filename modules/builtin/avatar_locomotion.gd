extends UniCoreModule

## Предустановленный модуль: Локомоция Аватара (Avatar Locomotion)
## Реализует камеру от 1-го лица, перемещение WASD и свободный полет (Space / Ctrl / Shift).
## Динамически подхватывает настройки чувствительности, инверсии и скорости.

@export var move_speed: float = 10.0
@export var sprint_speed: float = 25.0
@export var mouse_sensitivity: float = 0.002
@export var invert_y: bool = false

var camera: Camera3D
var yaw_node: Node3D
var pitch_node: Node3D
var is_flying: bool = true

var is_ui_blocking: bool = false
var is_rmb_held: bool = false

func get_module_id() -> String:
	return "builtin_avatar_locomotion"

func get_module_name() -> String:
	return "Avatar Locomotion (Built-in)"

func get_action_bindings() -> Array[Dictionary]:
	return [
		{"action": "move_forward", "label": "Движение вперед", "default_key": KEY_W, "description": "Перемещение камеры/аватара вперед"},
		{"action": "move_backward", "label": "Движение назад", "default_key": KEY_S, "description": "Перемещение камеры/аватара назад"},
		{"action": "move_left", "label": "Движение влево", "default_key": KEY_A, "description": "Перемещение камеры/аватара влево"},
		{"action": "move_right", "label": "Движение вправо", "default_key": KEY_D, "description": "Перемещение камеры/аватара вправо"},
		{"action": "move_up", "label": "Подъем / Полет вверх", "default_key": KEY_SPACE, "description": "Набор высоты в режиме полета"},
		{"action": "move_down", "label": "Спуск / Полет вниз", "default_key": KEY_CTRL, "description": "Снижение высоты в режиме полета"},
		{"action": "sprint", "label": "Ускорение полета (Спринт)", "default_key": KEY_SHIFT, "description": "Увеличение скорости перемещения"}
	]

func initialize(context: Dictionary) -> bool:
	super.initialize(context)

	yaw_node = Node3D.new()
	yaw_node.name = "AvatarYaw"
	add_child(yaw_node)

	pitch_node = Node3D.new()
	pitch_node.name = "AvatarPitch"
	yaw_node.add_child(pitch_node)

	camera = Camera3D.new()
	camera.name = "AvatarCamera"
	camera.current = true
	camera.position = Vector3(0, 1.8, 5.0)
	pitch_node.add_child(camera)

	# Подписка на обновление настроек и модальных окон через EventBus
	if core_context.has("event_bus") and core_context["event_bus"]:
		var eb = core_context["event_bus"]
		eb.subscribe("controls_settings_updated", _on_controls_updated)
		eb.subscribe("setting_changed", _on_setting_changed)
		eb.subscribe("modal_opened", _on_modal_opened)
		eb.subscribe("modal_closed", _on_modal_closed)

	# На старте оставляем курсор видимым для удобного взаимодействия с TopBar и Toolbar
	_set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	return true

func _set_mouse_mode(mode: Input.MouseMode) -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_MOUSE):
		Input.set_mouse_mode(mode)

func _on_modal_opened(_payload: Dictionary) -> void:
	is_ui_blocking = true
	is_rmb_held = false
	_set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_modal_closed(_payload: Dictionary) -> void:
	is_ui_blocking = false

func _on_controls_updated(payload: Dictionary) -> void:
	if payload.has("mouse_sensitivity"):
		mouse_sensitivity = float(payload["mouse_sensitivity"])
	if payload.has("invert_y"):
		invert_y = bool(payload["invert_y"])
	if payload.has("move_speed"):
		move_speed = float(payload["move_speed"])
	if payload.has("sprint_speed"):
		sprint_speed = float(payload["sprint_speed"])

func _on_setting_changed(payload: Dictionary) -> void:
	if payload.get("category") == "controls":
		var key = payload.get("key")
		var val = payload.get("value")
		if key == "mouse_sensitivity":
			mouse_sensitivity = float(val)
		elif key == "invert_y":
			invert_y = bool(val)
		elif key == "move_speed":
			move_speed = float(val)
		elif key == "sprint_speed":
			sprint_speed = float(val)

func _unhandled_input(event: InputEvent) -> void:
	if not is_initialized or is_ui_blocking:
		return

	# 1. Зажатие ПКМ (RMB) для быстрого обзора и полета в стиле 3D-редакторов (Unreal / Godot)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.is_pressed():
			is_rmb_held = true
			_set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			get_viewport().set_input_as_handled()
			return
		else:
			is_rmb_held = false
			_set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			get_viewport().set_input_as_handled()
			return

	# 2. Одиночный клик ЛКМ (LMB) по 3D-пространству для постоянного захвата мыши
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			_set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			get_viewport().set_input_as_handled()
			return

	# 3. Клавиша Alt или Esc для освобождения курсора мыши в UI
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_ALT or (event.keycode == KEY_ESCAPE and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED):
			is_rmb_held = false
			_set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			get_viewport().set_input_as_handled()
			return

	# 4. Вращение камеры при захваченной мыши
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		yaw_node.rotate_y(-event.relative.x * mouse_sensitivity)
		var y_delta: float = event.relative.y if invert_y else -event.relative.y
		pitch_node.rotate_x(y_delta * mouse_sensitivity)
		pitch_node.rotation.x = clamp(pitch_node.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func _process(delta: float) -> void:
	if not is_initialized or is_ui_blocking or Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return

	var input_dir := Vector3.ZERO
	if Input.is_action_pressed("move_forward") or (not InputMap.has_action("move_forward") and Input.is_key_pressed(KEY_W)):
		input_dir -= camera.global_transform.basis.z
	if Input.is_action_pressed("move_backward") or (not InputMap.has_action("move_backward") and Input.is_key_pressed(KEY_S)):
		input_dir += camera.global_transform.basis.z
	if Input.is_action_pressed("move_left") or (not InputMap.has_action("move_left") and Input.is_key_pressed(KEY_A)):
		input_dir -= camera.global_transform.basis.x
	if Input.is_action_pressed("move_right") or (not InputMap.has_action("move_right") and Input.is_key_pressed(KEY_D)):
		input_dir += camera.global_transform.basis.x
	if Input.is_action_pressed("move_up") or (not InputMap.has_action("move_up") and Input.is_key_pressed(KEY_SPACE)):
		input_dir += Vector3.UP
	if Input.is_action_pressed("move_down") or (not InputMap.has_action("move_down") and Input.is_key_pressed(KEY_CTRL)):
		input_dir -= Vector3.UP

	var is_sprinting: bool = Input.is_action_pressed("sprint") or (not InputMap.has_action("sprint") and Input.is_key_pressed(KEY_SHIFT))
	var current_speed := sprint_speed if is_sprinting else move_speed
	if input_dir.length_squared() > 0.001:
		input_dir = input_dir.normalized()
		yaw_node.global_position += input_dir * current_speed * delta

		# Ограничение по высоте, если включен режим ходьбы (Y >= 0)
		if not is_flying and yaw_node.global_position.y < 0.0:
			yaw_node.global_position.y = 0.0

func cleanup() -> void:
	if core_context.has("event_bus") and core_context["event_bus"]:
		var eb = core_context["event_bus"]
		eb.unsubscribe("controls_settings_updated", _on_controls_updated)
		eb.unsubscribe("setting_changed", _on_setting_changed)
		eb.unsubscribe("modal_opened", _on_modal_opened)
		eb.unsubscribe("modal_closed", _on_modal_closed)
	_set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	super.cleanup()
