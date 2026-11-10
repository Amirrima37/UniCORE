extends UniCoreModule

var _sun: DirectionalLight3D
var _orbit_speed: float = 0.05

func get_module_id() -> String:
	return "day_night_cycle"

func get_module_name() -> String:
	return "Окружение: Смена Дня и Ночи"

func initialize(context: Dictionary) -> bool:
	super.initialize(context)
	_sun = DirectionalLight3D.new()
	_sun.name = "DynamicSun"
	_sun.shadow_enabled = true
	_sun.light_energy = 1.0
	_sun.light_color = Color(1.0, 0.95, 0.88)
	add_child(_sun)
	return true

func _process(delta: float) -> void:
	if not is_initialized or not _sun:
		return
	_sun.rotate_x(delta * _orbit_speed)

func cleanup() -> void:
	if _sun and is_instance_valid(_sun):
		_sun.queue_free()
	super.cleanup()
