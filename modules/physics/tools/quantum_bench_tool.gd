class_name QuantumBenchTool
extends UniCoreModule

## Инструмент Квантовой Механики: Оптико-Волновой Стенд (Quantum Bench Tool)
## Позволяет исследователю интерактивно возбуждать волновые пакеты,
## размещать потенциальные барьеры, двухщелевые маски и измерять квантовое туннелирование.

signal wavepacket_injected(center: Vector3, k0: float)
signal potential_reconfigured(type_id: int, v0: float, width: float)
signal tunneling_telemetry(analytic_t: float, empirical_t: float, rel_err: float)
signal observables_telemetry(norm: float, x_mean: float, energy: float, trans: float, refl: float)

@export var default_k0: float = 3.0
@export var default_sigma: float = 0.8
@export var barrier_v0_step: float = 1.0

var _quantum_module: Node = null
var _event_bus: Node = null

func get_module_id() -> String:
	return "quantum_bench_tool"

func get_module_name() -> String:
	return "Квантовая Механика: Оптико-Волновой Стенд"

func get_action_bindings() -> Array[Dictionary]:
	return [
		{"action": "reset_wavepacket", "label": "Сброс волнового пакета", "default_key": KEY_R, "description": "Реинициализация гауссова пакета с начальными условиями"},
		{"action": "cycle_barrier", "label": "Смена потенциала", "default_key": KEY_B, "description": "Переключение между свободным пространством, барьером, ямой и щелями"},
		{"action": "raise_barrier", "label": "Высота барьера (+V0)", "default_key": KEY_UP, "description": "Увеличение потенциального порога барьера"},
		{"action": "lower_barrier", "label": "Высота барьера (-V0)", "default_key": KEY_DOWN, "description": "Снижение потенциального порога барьера"},
		{"action": "toggle_dim", "label": "Переключить 1D/2D", "default_key": KEY_M, "description": "Смена размерности симуляции уравнения Шрёдингера"}
	]

func initialize(context: Dictionary) -> bool:
	super.initialize(context)
	
	if core_context.has("event_bus") and core_context["event_bus"]:
		_event_bus = core_context["event_bus"]
		_event_bus.subscribe("physics_entity_spawned", _on_entity_spawned)
		_event_bus.subscribe("physics_parameter_changed", _on_parameter_changed)
	
	_resolve_quantum_module()
	return true

func _resolve_quantum_module() -> void:
	if _quantum_module and is_instance_valid(_quantum_module):
		return
	
	if core_context.has("module_manager") and core_context["module_manager"]:
		var mm = core_context["module_manager"]
		if mm.has_method("get_module"):
			_quantum_module = mm.get_module("quantum_wavepacket_module")
			if not _quantum_module:
				_quantum_module = mm.get_module("quantum_wavepacket")
	
	if not _quantum_module:
		var root: Node = get_tree().root if get_tree() else null
		if root:
			_quantum_module = root.find_child("quantum_wavepacket_module", true, false)
			if not _quantum_module:
				_quantum_module = root.find_child("QuantumWavePacketModule", true, false)
			if not _quantum_module:
				var wr: Node = core_context.get("world_root") as Node
				if wr:
					_quantum_module = wr.find_child("quantum_wavepacket_module", true, false)
					if not _quantum_module:
						_quantum_module = wr.find_child("quantum_wavepacket", true, false)
					if not _quantum_module:
						_quantum_module = wr.find_child("QuantumWavePacketModule", true, false)
	
	if _quantum_module:
		if _quantum_module.has_signal("barrier_tunneling_analyzed"):
			var cb_t := Callable(self, "_on_tunneling_analyzed")
			if not _quantum_module.is_connected("barrier_tunneling_analyzed", cb_t):
				_quantum_module.connect("barrier_tunneling_analyzed", cb_t)
		if _quantum_module.has_signal("observables_updated"):
			var cb_o := Callable(self, "_on_observables_updated")
			if not _quantum_module.is_connected("observables_updated", cb_o):
				_quantum_module.connect("observables_updated", cb_o)

func inject_wavepacket(center: Vector3, k0: float = 3.0) -> void:
	_resolve_quantum_module()
	
	if _quantum_module:
		var dim: int = int(_quantum_module.get("active_dimension"))
		if dim == 2: # DIMENSION_2D
			if _quantum_module.has_method("initialize_2d_gaussian"):
				_quantum_module.initialize_2d_gaussian(center.x, center.z, default_sigma, k0, 0.0)
		else: # DIMENSION_1D
			if _quantum_module.has_method("initialize_gaussian_wavepacket"):
				_quantum_module.initialize_gaussian_wavepacket(center.x, default_sigma, k0)
	
	wavepacket_injected.emit(center, k0)
	if _event_bus:
		_event_bus.publish("quantum_wavepacket_fired", {
			"center": center,
			"k0": k0
		})

func set_potential(type_id: int, v0: float, width: float = 0.8) -> void:
	_resolve_quantum_module()
	if not _quantum_module:
		return
	
	if _quantum_module.has_method("set_potential_type"):
		_quantum_module.set_potential_type(type_id)
	if _quantum_module.has_method("set_barrier_height"):
		_quantum_module.set_barrier_height(v0)
	if _quantum_module.has_method("set_barrier_width"):
		_quantum_module.set_barrier_width(width)
	
	potential_reconfigured.emit(type_id, v0, width)
	if _event_bus:
		_event_bus.publish("quantum_potential_changed", {
			"type_id": type_id,
			"v0": v0,
			"width": width
		})

func cycle_potential() -> void:
	_resolve_quantum_module()
	if _quantum_module and _quantum_module.has_method("cycle_potential_type"):
		_quantum_module.cycle_potential_type()
		var p_type: int = int(_quantum_module.get("potential_type"))
		var v0: float = float(_quantum_module.get("barrier_height_v0"))
		var w: float = float(_quantum_module.get("barrier_width_d"))
		potential_reconfigured.emit(p_type, v0, w)

func adjust_barrier_height(delta_v: float) -> void:
	_resolve_quantum_module()
	if not _quantum_module:
		return
	
	var current_v0: float = float(_quantum_module.get("barrier_height_v0"))
	var new_v0: float = maxf(0.0, current_v0 + delta_v)
	if _quantum_module.has_method("set_barrier_height"):
		_quantum_module.set_barrier_height(new_v0)
	
	var p_type: int = int(_quantum_module.get("potential_type"))
	var w: float = float(_quantum_module.get("barrier_width_d"))
	potential_reconfigured.emit(p_type, new_v0, w)

func toggle_dimension() -> void:
	_resolve_quantum_module()
	if _quantum_module and _quantum_module.has_method("toggle_dimension"):
		_quantum_module.toggle_dimension()

func reset_simulation() -> void:
	_resolve_quantum_module()
	if _quantum_module and _quantum_module.has_method("reset_simulation"):
		_quantum_module.reset_simulation()

func _unhandled_input(event: InputEvent) -> void:
	if not is_initialized:
		return
	
	if event.is_action_pressed("reset_wavepacket"):
		reset_simulation()
	elif event.is_action_pressed("cycle_barrier"):
		cycle_potential()
	elif event.is_action_pressed("raise_barrier"):
		adjust_barrier_height(barrier_v0_step)
	elif event.is_action_pressed("lower_barrier"):
		adjust_barrier_height(-barrier_v0_step)
	elif event.is_action_pressed("toggle_dim"):
		toggle_dimension()

func _on_entity_spawned(payload: Dictionary) -> void:
	var mod_id: String = str(payload.get("module_id", ""))
	if mod_id != "quantum_wavepacket_module" and mod_id != "quantum_wavepacket":
		return
	
	var entity: Dictionary = payload.get("entity", {})
	var center: Vector3 = entity.get("center", Vector3(-6.0, 0.0, 0.0))
	var k0: float = float(entity.get("k0", default_k0))
	var b_type: int = int(entity.get("barrier_type", 1))
	var b_v0: float = float(entity.get("barrier_v0", 6.0))
	
	set_potential(b_type, b_v0)
	inject_wavepacket(center, k0)

func _on_parameter_changed(payload: Dictionary) -> void:
	var param: String = str(payload.get("param", ""))
	var val: Variant = payload.get("value")
	
	if param == "quantum_v0":
		adjust_barrier_height(float(val) - float(_quantum_module.get("barrier_height_v0") if _quantum_module else 0.0))
	elif param == "quantum_barrier_type":
		_resolve_quantum_module()
		if _quantum_module and _quantum_module.has_method("set_potential_type"):
			_quantum_module.set_potential_type(int(val))

func _on_tunneling_analyzed(analytic_t: float, empirical_t: float, rel_err: float) -> void:
	tunneling_telemetry.emit(analytic_t, empirical_t, rel_err)

func _on_observables_updated(norm: float, x_mean: float, energy: float, trans: float, refl: float) -> void:
	observables_telemetry.emit(norm, x_mean, energy, trans, refl)

func cleanup() -> void:
	if _quantum_module and is_instance_valid(_quantum_module):
		if _quantum_module.has_signal("barrier_tunneling_analyzed"):
			var cb_t := Callable(self, "_on_tunneling_analyzed")
			if _quantum_module.is_connected("barrier_tunneling_analyzed", cb_t):
				_quantum_module.disconnect("barrier_tunneling_analyzed", cb_t)
		if _quantum_module.has_signal("observables_updated"):
			var cb_o := Callable(self, "_on_observables_updated")
			if _quantum_module.is_connected("observables_updated", cb_o):
				_quantum_module.disconnect("observables_updated", cb_o)
	
	_quantum_module = null
	_event_bus = null
	super.cleanup()
