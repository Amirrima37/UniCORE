class_name SimulationTimeController
extends Node

## Central physical time clock manager for UniCORE.
## Manages deterministic fixed-delta ticks, time scaling, pause/resume, and step-once execution.

signal sim_tick(dt: float, sim_time: float)
signal time_scale_changed(scale: float)
signal simulation_paused(is_paused: bool)
signal step_executed(sim_time: float)

const MIN_TIME_SCALE: float = 0.001
const MAX_TIME_SCALE: float = 1000.0
const DEFAULT_FIXED_DELTA: float = 0.01
const DEFAULT_MAX_SUBSTEPS: int = 10

@export var time_scale: float = 1.0:
	set(value):
		var target: float = clampf(value, MIN_TIME_SCALE, MAX_TIME_SCALE)
		if not is_equal_approx(time_scale, target):
			time_scale = target
			time_scale_changed.emit(time_scale)
			if _event_bus and _event_bus.has_method("publish"):
				_event_bus.publish("physics_time_scale_changed", {"scale": time_scale, "time_scale": time_scale})

@export var fixed_delta: float = DEFAULT_FIXED_DELTA:
	set(value):
		if value <= 0.0:
			push_error("SimulationTimeController: fixed_delta must be strictly positive.")
			return
		fixed_delta = value

@export var is_paused: bool = false:
	set(value):
		if is_paused != value:
			is_paused = value
			simulation_paused.emit(is_paused)
			if _event_bus and _event_bus.has_method("publish"):
				_event_bus.publish("physics_simulation_paused", {"is_paused": is_paused, "paused": is_paused})

@export var max_substeps: int = DEFAULT_MAX_SUBSTEPS

var sim_time: float = 0.0
var _accumulator: float = 0.0
var _event_bus: Node = null

## Initializes the time controller with an EventBus reference for global time telemetry.
func setup(event_bus: Node) -> void:
	_event_bus = event_bus
	if _event_bus and _event_bus.has_method("subscribe"):
		_event_bus.subscribe("physics_time_command", _on_physics_time_command)

func _on_physics_time_command(payload: Dictionary) -> void:
	var cmd: String = str(payload.get("command", ""))
	match cmd:
		"set_paused":
			var paused: bool = bool(payload.get("value", false))
			set_paused(paused)
		"toggle_pause":
			toggle_pause()
		"step_once":
			step_once()
		"set_time_scale":
			var scale_val: float = float(payload.get("value", 1.0))
			set_time_scale(scale_val)

func _physics_process(delta: float) -> void:
	if is_paused or delta <= 0.0 or fixed_delta <= 0.0:
		return
	
	_accumulator += delta * time_scale
	
	var steps: int = 0
	while _accumulator >= fixed_delta and steps < max_substeps:
		_accumulator -= fixed_delta
		sim_time += fixed_delta
		sim_tick.emit(fixed_delta, sim_time)
		steps += 1
	
	if steps > 0 and _event_bus and _event_bus.has_method("publish"):
		_event_bus.publish("physics_time_tick", {"delta": fixed_delta * float(steps), "sim_time": sim_time})
	
	# Death-spiral protection: if frame lag exceeds maximum substepping capacity,
	# drop remaining backlog to prevent cascading engine stall.
	var max_backlog: float = fixed_delta * float(max_substeps)
	if _accumulator > max_backlog:
		_accumulator = 0.0

func set_time_scale(scale: float) -> void:
	time_scale = scale

func get_time_scale() -> float:
	return time_scale

func set_paused(paused: bool) -> void:
	is_paused = paused

func toggle_pause() -> void:
	set_paused(not is_paused)

func is_simulation_paused() -> bool:
	return is_paused

func set_fixed_delta(p_fixed_delta: float) -> void:
	fixed_delta = p_fixed_delta

func get_fixed_delta() -> float:
	return fixed_delta

func get_sim_time() -> float:
	return sim_time

func step_once() -> void:
	if fixed_delta <= 0.0:
		push_error("SimulationTimeController: cannot step_once with fixed_delta <= 0.")
		return
	sim_time += fixed_delta
	sim_tick.emit(fixed_delta, sim_time)
	step_executed.emit(sim_time)
	if _event_bus and _event_bus.has_method("publish"):
		_event_bus.publish("physics_time_tick", {"delta": fixed_delta, "sim_time": sim_time})

func reset() -> void:
	sim_time = 0.0
	_accumulator = 0.0
