class_name NuclearLabTool
extends UniCoreModule

## Инструмент Ядерной Физики: Лабораторный Реактор и Инжектор Нейтронов (Nuclear Lab Tool)
## Позволяет исследователю интерактивно размещать топливные сборки различных изотопов,
## производить выстрелы триггерными нейтронами и регулировать глубину погружения стержней СУЗ.

signal fuel_assembly_spawned(pos: Vector3, count: int, isotope: String)
signal neutron_fired(pos: Vector3, vel: Vector3)
signal control_rods_adjusted(new_depth: float)
signal criticality_telemetry(k_eff: float, active_neutrons: int, active_nuclei: int)

@export var selected_isotope: String = "U-235"
@export var fuel_assembly_count: int = 150
@export var fuel_assembly_radius: float = 3.0
@export var default_neutron_speed: float = 25.0
@export var rod_adjustment_step: float = 0.05
@export var control_rod_depth: float = 0.0

var _nuclear_module: Node = null
var _event_bus: Node = null

func get_module_id() -> String:
	return "nuclear_lab_tool"

func get_module_name() -> String:
	return "Ядерная Физика: Лабораторный Реактор"

func get_action_bindings() -> Array[Dictionary]:
	return [
		{"action": "fire_neutron", "label": "Выстрел нейтроном", "default_key": KEY_SPACE, "description": "Инжекция теплового нейтрона в ядро"},
		{"action": "insert_rods", "label": "Ввод стержней (+СУЗ)", "default_key": KEY_DOWN, "description": "Погружение поглощающих стержней для гашения реакции"},
		{"action": "withdraw_rods", "label": "Извлечение стержней (-СУЗ)", "default_key": KEY_UP, "description": "Подъем поглотителей для разгона реакции"},
		{"action": "select_u235", "label": "Выбрать U-235", "default_key": KEY_1, "description": "Выбор делящегося изотопа Уран-235"},
		{"action": "select_ra226", "label": "Выбрать Ra-226", "default_key": KEY_2, "description": "Выбор альфа-радиоактивного Радия-226"},
		{"action": "reset_assembly", "label": "Сброс сборки", "default_key": KEY_R, "description": "Перезапуск реакторного ядра в исходное состояние"}
	]

func initialize(context: Dictionary) -> bool:
	super.initialize(context)
	
	if core_context.has("event_bus") and core_context["event_bus"]:
		_event_bus = core_context["event_bus"]
		_event_bus.subscribe("physics_entity_spawned", _on_entity_spawned)
		_event_bus.subscribe("physics_parameter_changed", _on_parameter_changed)
	
	_resolve_nuclear_module()
	return true

func _resolve_nuclear_module() -> void:
	if _nuclear_module and is_instance_valid(_nuclear_module):
		return
	
	if core_context.has("module_manager") and core_context["module_manager"]:
		var mm = core_context["module_manager"]
		if mm.has_method("get_module"):
			_nuclear_module = mm.get_module("nuclear_decay_module")
			if not _nuclear_module:
				_nuclear_module = mm.get_module("nuclear_decay")
	
	if not _nuclear_module:
		var root: Node = get_tree().root if get_tree() else null
		if root:
			_nuclear_module = root.find_child("nuclear_decay_module", true, false)
			if not _nuclear_module:
				_nuclear_module = root.find_child("NuclearDecayModule", true, false)
			if not _nuclear_module:
				var wr: Node = core_context.get("world_root") as Node
				if wr:
					_nuclear_module = wr.find_child("nuclear_decay_module", true, false)
					if not _nuclear_module:
						_nuclear_module = wr.find_child("nuclear_decay", true, false)
					if not _nuclear_module:
						_nuclear_module = wr.find_child("NuclearDecayModule", true, false)
	
	if _nuclear_module and _nuclear_module.has_signal("chain_reaction_status"):
		var cb := Callable(self, "_on_chain_reaction_status")
		if not _nuclear_module.is_connected("chain_reaction_status", cb):
			_nuclear_module.connect("chain_reaction_status", cb)

func spawn_fuel_assembly(pos: Vector3, count: int = 150, isotope: String = "U-235") -> void:
	_resolve_nuclear_module()
	selected_isotope = isotope
	
	if _nuclear_module:
		if isotope == "U-235" and _nuclear_module.has_method("setup_reactor_core"):
			_nuclear_module.setup_reactor_core(count, fuel_assembly_radius)
		elif _nuclear_module.has_method("setup_isotope_sample"):
			_nuclear_module.setup_isotope_sample(isotope, count, fuel_assembly_radius)
	
	fuel_assembly_spawned.emit(pos, count, isotope)
	if _event_bus:
		_event_bus.publish("nuclear_assembly_spawned", {
			"position": pos,
			"count": count,
			"isotope": isotope
		})

func fire_neutron(pos: Vector3, vel: Vector3) -> void:
	_resolve_nuclear_module()
	
	if _nuclear_module and _nuclear_module.has_method("inject_trigger_neutron"):
		_nuclear_module.inject_trigger_neutron(pos, vel)
	
	neutron_fired.emit(pos, vel)
	if _event_bus:
		_event_bus.publish("neutron_injected", {
			"position": pos,
			"velocity": vel
		})

func adjust_control_rods(delta: float) -> void:
	set_control_rods(control_rod_depth + delta)

func set_control_rods(depth: float) -> void:
	_resolve_nuclear_module()
	control_rod_depth = clampf(depth, 0.0, 1.0)
	
	if _nuclear_module and is_instance_valid(_nuclear_module):
		_nuclear_module.set("control_rod_depth", control_rod_depth)
	
	control_rods_adjusted.emit(control_rod_depth)
	if _event_bus:
		_event_bus.publish("nuclear_control_rods_changed", {"control_rod_depth": control_rod_depth})

func reset_assembly() -> void:
	spawn_fuel_assembly(Vector3.ZERO, fuel_assembly_count, selected_isotope)

func _unhandled_input(event: InputEvent) -> void:
	if not is_initialized:
		return
	
	if event.is_action_pressed("fire_neutron"):
		fire_neutron(Vector3(0.0, 0.0, -5.0), Vector3(0.0, 0.0, default_neutron_speed))
	elif event.is_action_pressed("insert_rods"):
		adjust_control_rods(rod_adjustment_step)
	elif event.is_action_pressed("withdraw_rods"):
		adjust_control_rods(-rod_adjustment_step)
	elif event.is_action_pressed("select_u235"):
		selected_isotope = "U-235"
	elif event.is_action_pressed("select_ra226"):
		selected_isotope = "Ra-226"
	elif event.is_action_pressed("reset_assembly"):
		reset_assembly()

func _on_entity_spawned(payload: Dictionary) -> void:
	var mod_id: String = str(payload.get("module_id", ""))
	if mod_id != "nuclear_decay_module" and mod_id != "nuclear_decay":
		return
	
	var entity: Dictionary = payload.get("entity", {})
	var pos: Vector3 = entity.get("position", Vector3.ZERO)
	var vel: Vector3 = entity.get("velocity", Vector3.ZERO)
	var iso: String = str(entity.get("isotope", selected_isotope))
	
	if vel.length_squared() > 1.0:
		# Dragging with velocity: shoot a trigger neutron
		fire_neutron(pos, vel)
	else:
		# Placement click: spawn isotope cluster
		spawn_fuel_assembly(pos, fuel_assembly_count, iso)

func _on_parameter_changed(payload: Dictionary) -> void:
	var param: String = str(payload.get("param", ""))
	var val: Variant = payload.get("value")
	
	if param == "nuclear_isotope":
		selected_isotope = str(val)
	elif param == "nuclear_rods":
		set_control_rods(float(val))

func _on_chain_reaction_status(k_eff: float, active_n: int, active_nuclei: int) -> void:
	criticality_telemetry.emit(k_eff, active_n, active_nuclei)

func cleanup() -> void:
	if _nuclear_module and is_instance_valid(_nuclear_module) and _nuclear_module.has_signal("chain_reaction_status"):
		var cb := Callable(self, "_on_chain_reaction_status")
		if _nuclear_module.is_connected("chain_reaction_status", cb):
			_nuclear_module.disconnect("chain_reaction_status", cb)
	
	_nuclear_module = null
	_event_bus = null
	super.cleanup()
