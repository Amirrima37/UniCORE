class_name CelestialSpawnerTool
extends UniCoreModule

## Инструмент Астрофизики: Спавнер Небесных Тел и Черных Дыр (Celestial Spawner Tool)
## Позволяет исследователю интерактивно размещать гравитирующие тела в вакууме,
## задавать касательный импульс и наблюдать кеплеровские и релятивистские орбиты.

signal body_spawned_into_gravity(pos: Vector3, vel: Vector3, mass: float, type_name: String)

@export var star_mass: float = 1000.0
@export var planet_mass: float = 10.0
@export var black_hole_mass: float = 10000.0
@export var default_speed_scale: float = 5.0

var _gravity_module: Node = null
var _event_bus: Node = null

func get_module_id() -> String:
	return "celestial_spawner_tool"

func get_module_name() -> String:
	return "Астрофизика: Спавнер Небесных Тел"

func get_action_bindings() -> Array[Dictionary]:
	return [
		{"action": "spawn_planet", "label": "Спавн планеты", "default_key": KEY_1, "description": "Выбор режима спавна планеты"},
		{"action": "spawn_star", "label": "Спавн звезды", "default_key": KEY_2, "description": "Выбор режима спавна звезды"},
		{"action": "spawn_black_hole", "label": "Спавн черной дыры", "default_key": KEY_3, "description": "Выбор режима спавна черной дыры"}
	]

func initialize(context: Dictionary) -> bool:
	super.initialize(context)
	
	if core_context.has("event_bus") and core_context["event_bus"]:
		_event_bus = core_context["event_bus"]
		_event_bus.subscribe("physics_entity_spawned", _on_entity_spawned)
	
	_resolve_gravity_module()
	return true

func _resolve_gravity_module() -> void:
	if not _gravity_module or not is_instance_valid(_gravity_module):
		if core_context.has("module_manager") and core_context["module_manager"]:
			var mm = core_context["module_manager"]
			if mm.has_method("get_module"):
				_gravity_module = mm.get_module("n_body_gravity_module")
				if not _gravity_module:
					_gravity_module = mm.get_module("n_body_gravity")
		if not _gravity_module:
			var root: Node = get_tree().root if get_tree() else null
			if root:
				_gravity_module = root.find_child("n_body_gravity_module", true, false)
				if not _gravity_module:
					_gravity_module = root.find_child("NBodyGravityModule", true, false)

func spawn_body(position: Vector3, velocity: Vector3, mass: float, body_type: String = "planet") -> void:
	_resolve_gravity_module()
	
	if _gravity_module and _gravity_module.has_method("spawn_body"):
		_gravity_module.spawn_body(position, velocity, mass, body_type)
	elif _gravity_module and _gravity_module.has_method("add_body"):
		_gravity_module.add_body(body_type, position, velocity, mass)
	
	body_spawned_into_gravity.emit(position, velocity, mass, body_type)
	if _event_bus:
		_event_bus.publish("celestial_body_created", {
			"position": position,
			"velocity": velocity,
			"mass": mass,
			"body_type": body_type
		})

func _on_entity_spawned(payload: Dictionary) -> void:
	var mod_id: String = str(payload.get("module_id", ""))
	if mod_id != "n_body_gravity_module":
		return
	
	var entity: Dictionary = payload.get("entity", {})
	var pos: Vector3 = entity.get("position", Vector3.ZERO)
	var vel: Vector3 = entity.get("velocity", Vector3.ZERO)
	var mass: float = float(entity.get("mass", planet_mass))
	var btype: String = str(entity.get("body_type", "planet"))
	
	spawn_body(pos, vel, mass, btype)

func cleanup() -> void:
	_gravity_module = null
	_event_bus = null
	super.cleanup()
