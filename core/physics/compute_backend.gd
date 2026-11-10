class_name ComputeBackend
extends RefCounted

## Discovery never references native types at parse time; absent/incompatible capabilities retain script execution.
static func create_particle_metrics(mode: String) -> RefCounted:
	if mode == "gdscript":
		return null
	if mode != "native" and mode != "auto":
		push_error("Unknown compute backend: " + mode)
		return null
	if not ClassDB.class_exists("UniCoreNativeInfo") or not ClassDB.class_exists("UniCoreParticleMetrics"):
		return null
	var info = ClassDB.instantiate("UniCoreNativeInfo")
	if not info is RefCounted or not info.has_method("get_capabilities"):
		return null
	var capabilities: Dictionary = info.call("get_capabilities")
	if capabilities.get("api_version", 0) != 1 or not capabilities.get("particle_metrics", false):
		return null
	var reducer = ClassDB.instantiate("UniCoreParticleMetrics")
	if reducer is RefCounted and reducer.has_method("reduce"):
		return reducer
	return null

## Per-module owned solver; no native class appears in a type annotation.
static func create_molecular_solver(mode: String) -> RefCounted:
	if mode == "gdscript":
		return null
	if mode != "native" and mode != "auto":
		push_error("Unknown compute backend: " + mode)
		return null
	if not ClassDB.class_exists("UniCoreNativeInfo") or not ClassDB.class_exists("UniCoreMolecularSolver"):
		return null
	var info = ClassDB.instantiate("UniCoreNativeInfo")
	if not info is RefCounted or not info.has_method("get_capabilities"):
		return null
	var capabilities: Dictionary = info.call("get_capabilities")
	if capabilities.get("api_version", 0) != 1 or not capabilities.get("molecular_solver", false):
		return null
	var solver = ClassDB.instantiate("UniCoreMolecularSolver")
	if solver is RefCounted and solver.has_method("advance"):
		return solver
	return null

static func create_gravity_solver(mode: String) -> RefCounted:
	if mode == "gdscript":
		return null
	if mode != "native" and mode != "auto":
		push_error("Unknown compute backend: " + mode)
		return null
	if not ClassDB.class_exists("UniCoreNativeInfo") or not ClassDB.class_exists("UniCoreGravitySolver"):
		return null
	var info = ClassDB.instantiate("UniCoreNativeInfo")
	if not info is RefCounted or not info.has_method("get_capabilities"):
		return null
	var capabilities: Dictionary = info.call("get_capabilities")
	if capabilities.get("api_version", 0) != 1 or not capabilities.get("gravity_solver", false):
		return null
	var solver = ClassDB.instantiate("UniCoreGravitySolver")
	if solver is RefCounted and solver.has_method("advance"):
		return solver
	return null

static func create_quantum_solver(mode: String) -> RefCounted:
	if mode == "gdscript":
		return null
	if mode != "native" and mode != "auto":
		push_error("Unknown compute backend: " + mode)
		return null
	if not ClassDB.class_exists("UniCoreNativeInfo") or not ClassDB.class_exists("UniCoreQuantumSolver"):
		return null
	var info = ClassDB.instantiate("UniCoreNativeInfo")
	if not info is RefCounted or not info.has_method("get_capabilities"):
		return null
	var capabilities: Dictionary = info.call("get_capabilities")
	if capabilities.get("api_version", 0) != 1 or not capabilities.get("quantum_solver", false):
		return null
	var solver = ClassDB.instantiate("UniCoreQuantumSolver")
	if solver is RefCounted and solver.has_method("advance"):
		return solver
	return null

static func create_nuclear_solver(mode: String) -> RefCounted:
	if mode == "gdscript":
		return null
	if mode != "native" and mode != "auto":
		push_error("Unknown compute backend: " + mode)
		return null
	if not ClassDB.class_exists("UniCoreNativeInfo") or not ClassDB.class_exists("UniCoreNuclearSolver"):
		return null
	var info = ClassDB.instantiate("UniCoreNativeInfo")
	if not info is RefCounted or not info.has_method("get_capabilities"):
		return null
	var capabilities: Dictionary = info.call("get_capabilities")
	if capabilities.get("api_version", 0) != 1 or not capabilities.get("nuclear_solver", false):
		return null
	var solver = ClassDB.instantiate("UniCoreNuclearSolver")
	if solver is RefCounted and solver.has_method("advance"):
		return solver
	return null

## Commit through the existing packed container so legacy callers retaining an
## array reference continue observing changes after a native step.
static func copy_packed_array(target, source) -> void:
	target.clear()
	target.append_array(source)
