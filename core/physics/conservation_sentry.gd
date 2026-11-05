class_name ConservationSentry
extends Node

## Continuous auditor of Noether invariants (energy, linear momentum, angular momentum)
## and kinetic temperature in UniCORE physical simulations.
##
## Monitors conservative Hamiltonian systems, detects unphysical dissipation or
## explosion, and broadcasts real-time telemetry snapshots and warning signals.

signal invariants_updated(snapshot: Dictionary)
signal conservation_warning(violation_type: String, relative_drift: float)

## Relative energy drift tolerance before triggering a warning (0.005 = 0.5% default)
@export var energy_tolerance: float = 0.005

## Relative linear momentum drift tolerance (0.01 = 1.0% default)
@export var momentum_tolerance: float = 0.01

## Relative angular momentum drift tolerance (0.01 = 1.0% default)
@export var angular_momentum_tolerance: float = 0.01

## Boltzmann constant for thermodynamic temperature calculation (1.0 in reduced units)
@export var boltzmann_constant: float = 1.0

## Controls whether conservation_warning signals are emitted
@export var enable_warnings: bool = true

## Controls whether invariants_updated is emitted on every audit call
@export var emit_update_signal: bool = true

## Baseline invariants recorded at system registration
var initial_energy: float = 0.0
var initial_linear_momentum: Vector3 = Vector3.ZERO
var initial_angular_momentum: Vector3 = Vector3.ZERO
var is_registered: bool = false

## Cached state
var _last_snapshot: Dictionary = {}
var _audit_count: int = 0
var _event_bus: Node = null

## Initializes the sentry with an EventBus reference for global invariant telemetry.
func setup(event_bus: Node) -> void:
	_event_bus = event_bus

## Explicitly registers initial baseline invariants for the system.
func register_system(
	initial_e: float,
	initial_p: Vector3 = Vector3.ZERO,
	initial_l: Vector3 = Vector3.ZERO
) -> void:
	initial_energy = initial_e
	initial_linear_momentum = initial_p
	initial_angular_momentum = initial_l
	is_registered = true

## Audits current physical state against Noether invariants.
## Positions, velocities, and masses must have matching sizes.
## Returns a telemetry Dictionary snapshot.
func audit(
	positions: PackedVector3Array,
	velocities: PackedVector3Array,
	masses: PackedFloat32Array,
	potential_calculator: Callable
) -> Dictionary:
	var n: int = positions.size()
	
	# Guard against dimensional parity mismatch
	if velocities.size() != n or masses.size() != n:
		push_error("ConservationSentry.audit: Array size mismatch (pos: %d, vel: %d, mass: %d)" % [
			n, velocities.size(), masses.size()
		])
		return {}
	
	# Handle empty particle state gracefully
	if n == 0:
		var empty_snapshot: Dictionary = {
			"kinetic_energy": 0.0,
			"potential_energy": 0.0,
			"total_energy": 0.0,
			"energy_drift_ratio": 0.0,
			"linear_momentum": Vector3.ZERO,
			"angular_momentum": Vector3.ZERO,
			"particle_count": 0,
			"temperature": 0.0,
			"is_conserved": true,
			"linear_momentum_drift": 0.0,
			"angular_momentum_drift": 0.0,
			"audit_count": _audit_count
		}
		_last_snapshot = empty_snapshot
		return empty_snapshot
	
	# Fused single-pass O(N) evaluation of Kinetic Energy, Linear Momentum, and Angular Momentum
	var total_ek: float = 0.0
	var total_p: Vector3 = Vector3.ZERO
	var total_l: Vector3 = Vector3.ZERO
	
	for i in range(n):
		var m: float = masses[i]
		var v: Vector3 = velocities[i]
		var r: Vector3 = positions[i]
		var p_i: Vector3 = v * m
		
		total_ek += 0.5 * m * v.length_squared()
		total_p += p_i
		total_l += r.cross(p_i)
	
	# Evaluate Potential Energy safely via potential_calculator
	var total_ep: float = 0.0
	if potential_calculator.is_valid():
		var calc_res: Variant = potential_calculator.call(positions)
		if calc_res is float or calc_res is int:
			total_ep = float(calc_res)
		else:
			push_error("ConservationSentry.audit: potential_calculator returned non-numeric type")
	
	var total_e: float = total_ek + total_ep
	
	# Self-registration on first audit if not explicitly pre-registered
	if not is_registered:
		register_system(total_e, total_p, total_l)
	
	# Compute relative energy drift with zero-division safeguard: |E(t) - E(0)| / max(|E(0)|, 1e-12)
	var e0_abs: float = absf(initial_energy)
	var e_denom: float = e0_abs if e0_abs > 1e-12 else 1e-12
	var energy_drift: float = absf(total_e - initial_energy) / e_denom
	
	# Compute linear momentum drift (relative or absolute norm difference)
	var p0_mag: float = initial_linear_momentum.length()
	var p_diff: float = (total_p - initial_linear_momentum).length()
	var p_drift: float = p_diff / p0_mag if p0_mag > 1e-12 else p_diff
	
	# Compute angular momentum drift (relative or absolute norm difference)
	var l0_mag: float = initial_angular_momentum.length()
	var l_diff: float = (total_l - initial_angular_momentum).length()
	var l_drift: float = l_diff / l0_mag if l0_mag > 1e-12 else l_diff
	
	# Evaluate thermodynamic kinetic temperature: T = 2 * E_k / (3 * N * k_B)
	var kb: float = boltzmann_constant if boltzmann_constant > 0.0 else 1.0
	var temperature: float = (2.0 * total_ek) / (3.0 * float(n) * kb)
	
	var is_conserved: bool = (energy_drift <= energy_tolerance)
	
	# Check thresholds and emit warnings if enabled
	if enable_warnings:
		if not is_conserved:
			conservation_warning.emit("energy", energy_drift)
		if p_drift > momentum_tolerance:
			conservation_warning.emit("linear_momentum", p_drift)
		if l_drift > angular_momentum_tolerance:
			conservation_warning.emit("angular_momentum", l_drift)
	
	_audit_count += 1
	
	var snapshot: Dictionary = {
		"kinetic_energy": total_ek,
		"potential_energy": total_ep,
		"total_energy": total_e,
		"energy_drift_ratio": energy_drift,
		"linear_momentum": total_p,
		"angular_momentum": total_l,
		"particle_count": n,
		"temperature": temperature,
		"is_conserved": is_conserved,
		"linear_momentum_drift": p_drift,
		"angular_momentum_drift": l_drift,
		"audit_count": _audit_count
	}
	
	_last_snapshot = snapshot
	
	if emit_update_signal:
		invariants_updated.emit(snapshot)
		if _event_bus:
			var payload := {
				"e_tot": total_e,
				"energy_drift_ratio": energy_drift,
				"p_mag": total_p.length(),
				"l_mag": total_l.length(),
				"temp": temperature
			}
			if _event_bus.has_method("publish"):
				_event_bus.publish("physics_invariants_updated", payload)
			elif _event_bus.has_method("emit"):
				_event_bus.emit("physics_invariants_updated", payload)
	
	return snapshot

## Resets registration, internal baselines, and statistics.
func reset() -> void:
	initial_energy = 0.0
	initial_linear_momentum = Vector3.ZERO
	initial_angular_momentum = Vector3.ZERO
	is_registered = false
	_last_snapshot = {}
	_audit_count = 0

## Returns the cached snapshot from the most recent audit cycle.
func get_last_snapshot() -> Dictionary:
	return _last_snapshot.duplicate()

## Returns true if the last audit was within conservation tolerance.
func is_system_conserved() -> bool:
	if _last_snapshot.is_empty():
		return true
	return bool(_last_snapshot.get("is_conserved", false))

## Returns total count of audit invocations.
func get_audit_count() -> int:
	return _audit_count

## Helper to validate state dimensions without auditing.
func validate_state(
	positions: PackedVector3Array,
	velocities: PackedVector3Array,
	masses: PackedFloat32Array
) -> bool:
	var n: int = positions.size()
	if n == 0 or velocities.is_empty() or masses.is_empty():
		return false
	return velocities.size() == n and masses.size() == n
