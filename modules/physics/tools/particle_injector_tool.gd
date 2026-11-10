class_name ParticleInjectorTool
extends UniCoreModule

## Инструмент Термодинамики: Инжектор Молекул и Управление Термостатом (Particle Injector Tool)
## Позволяет исследователю впрыскивать молекулярные кластеры в камеру газа,
## динамически изменять целевую температуру T_target и размер ячейки.

signal gas_injected(pos: Vector3, count: int, temperature: float)
signal temperature_adjusted(new_temp: float)

@export var default_inject_count: int = 50
@export var default_temperature: float = 1.2
@export var temp_step: float = 0.2

var _md_module: Node = null
var _event_bus: Node = null

func get_module_id() -> String:
	return "particle_injector_tool"

func get_module_name() -> String:
	return "Термодинамика: Инжектор Молекул"

func get_action_bindings() -> Array[Dictionary]:
	return [
		{"action": "heat_gas", "label": "Нагрев газа (+T)", "default_key": KEY_UP, "description": "Повышение целевой температуры термостата"},
		{"action": "cool_gas", "label": "Охлаждение газа (-T)", "default_key": KEY_DOWN, "description": "Понижение целевой температуры термостата"},
		{"action": "reset_maxwell", "label": "Сброс Максвелла", "default_key": KEY_R, "description": "Сброс скоростей к распределению Максвелла-Больцмана"}
	]

func initialize(context: Dictionary) -> bool:
	super.initialize(context)
	
	if core_context.has("event_bus") and core_context["event_bus"]:
		_event_bus = core_context["event_bus"]
		_event_bus.subscribe("physics_entity_spawned", _on_entity_spawned)
		_event_bus.subscribe("physics_parameter_changed", _on_param_changed)
	
	_resolve_md_module()
	return true

func _resolve_md_module() -> void:
	if not _md_module or not is_instance_valid(_md_module):
		if core_context.has("module_manager") and core_context["module_manager"]:
			var mm = core_context["module_manager"]
			if mm.has_method("get_module"):
				_md_module = mm.get_module("molecular_dynamics_module")
				if not _md_module:
					_md_module = mm.get_module("molecular_dynamics")
		if not _md_module:
			var root: Node = get_tree().root if get_tree() else null
			if root:
				_md_module = root.find_child("molecular_dynamics_module", true, false)
				if not _md_module:
					_md_module = root.find_child("MolecularDynamicsModule", true, false)

func inject_molecules(pos: Vector3, count: int = 50, temp: float = 1.0) -> void:
	_resolve_md_module()
	
	if _md_module and _md_module.has_method("inject_particles"):
		_md_module.inject_particles(pos, count, temp)
	
	gas_injected.emit(pos, count, temp)
	if _event_bus:
		_event_bus.publish("gas_molecules_injected", {
			"position": pos,
			"count": count,
			"temperature": temp
		})

func adjust_temperature(delta_t: float) -> void:
	_resolve_md_module()
	if not _md_module:
		return
	
	var current_t: float = float(_md_module.get("target_temperature"))
	var new_t: float = maxf(current_t + delta_t, 0.05)
	_md_module.set("target_temperature", new_t)
	temperature_adjusted.emit(new_t)
	
	if _event_bus:
		_event_bus.publish("thermo_target_temperature_changed", {"target_temperature": new_t})

func _unhandled_input(event: InputEvent) -> void:
	if not is_initialized:
		return
	if event.is_action_pressed("heat_gas"):
		adjust_temperature(temp_step)
	elif event.is_action_pressed("cool_gas"):
		adjust_temperature(-temp_step)
	elif event.is_action_pressed("reset_maxwell"):
		_resolve_md_module()
		if _md_module and _md_module.has_method("reset_to_maxwell_boltzmann"):
			_md_module.reset_to_maxwell_boltzmann()

func _on_entity_spawned(payload: Dictionary) -> void:
	var mod_id: String = str(payload.get("module_id", ""))
	if mod_id != "molecular_dynamics_module":
		return
	var entity: Dictionary = payload.get("entity", {})
	var pos: Vector3 = entity.get("position", Vector3.ZERO)
	var count: int = int(entity.get("count", default_inject_count))
	var temp: float = float(entity.get("temperature", default_temperature))
	inject_molecules(pos, count, temp)

func _on_param_changed(payload: Dictionary) -> void:
	var param: String = str(payload.get("param", ""))
	if param == "thermo_temp":
		var val: float = float(payload.get("value", 1.0))
		_resolve_md_module()
		if _md_module:
			_md_module.set("target_temperature", val)

func cleanup() -> void:
	_md_module = null
	_event_bus = null
	super.cleanup()
