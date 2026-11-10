extends SceneTree
const MD = preload("res://modules/physics/molecular_dynamics_module.gd")
const Backend = preload("res://core/physics/compute_backend.gd")
const Sentry = preload("res://core/physics/conservation_sentry.gd")
const Clock = preload("res://core/physics/simulation_time_controller.gd")
var checks: int = 0
var failures: int = 0
func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
func close_scalar(a: float, b: float, tolerance: float = 1e-6) -> bool:
	return absf(a-b) <= 1e-7 + tolerance*absf(b)
func close_vectors(a: PackedVector3Array, b: PackedVector3Array, label: String, tolerance: float = 1e-6) -> void:
	check(a.size() == b.size(), label + " count")
	for i in range(mini(a.size(),b.size())):
		check(a[i].distance_to(b[i]) <= 1e-6+tolerance*b[i].length(), label+" particle "+str(i))
func arrays(count: int) -> Dictionary:
	var p := PackedVector3Array()
	var v := PackedVector3Array()
	var m := PackedFloat32Array()
	for i in range(count):
		p.append(Vector3(float(i%4)*1.4-2.1,float((i/4)%4)*1.4-2.1,float(i/16)*1.4-0.7))
		v.append(Vector3(sin(float(i))*0.1,cos(float(i))*0.1,0.05))
		m.append(0.8 + float(i%3)*0.2)
	return {"p":p,"v":v,"m":m}
func configure_module(module, mode: String, state: Dictionary) -> void:
	module.compute_backend = mode
	module.thermostat_enabled = false
	module.box_half_extent = Vector3(20,20,20)
	module.set_particle_state(state.p,state.v,state.m)
func _init() -> void:
	var extension_path: String = "res://bin/unicore_native.gdextension"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--extension="):
			extension_path = argument.trim_prefix("--extension=")
	if FileAccess.file_exists(extension_path):
		GDExtensionManager.load_extension(extension_path)
	var solver = Backend.create_molecular_solver("native")
	check(not "--require-native" in OS.get_cmdline_user_args() or solver != null,"Native molecular solver required")
	_golden_fixture_check(solver != null)
	var reference = MD.new()
	var candidate = MD.new()
	var state := arrays(27)
	configure_module(reference,"gdscript",state)
	configure_module(candidate,"native",state)
	var retained_positions: PackedVector3Array = candidate.get_positions()
	var retained_velocities: PackedVector3Array = candidate.get_velocities()
	var brute: PackedVector3Array = reference.compute_forces_brute_force(state.p)
	close_vectors(candidate.compute_forces(state.p),brute,"Native grid vs independent brute force")
	check(close_scalar(candidate.compute_potential_energy(state.p),reference.compute_potential_energy(state.p)),"Potential parity")
	var cached_forces: PackedVector3Array = candidate.get_forces().duplicate()
	candidate.compute_forces(PackedVector3Array())
	check(candidate.get_forces() == cached_forces,"Empty force query preserves the existing cache")
	for i in range(100):
		reference.step(0.001)
		candidate.step(0.001)
		if i == 0 or i == 99:
			check(retained_positions==candidate.get_positions() and retained_velocities==candidate.get_velocities(),"Retained particle array references stay current")
			close_vectors(candidate.get_positions(),reference.get_positions(),"Fixed horizon positions")
			close_vectors(candidate.get_velocities(),reference.get_velocities(),"Fixed horizon velocities")
			close_vectors(candidate.get_forces(),reference.get_forces(),"Force cache",1e-5)
	check(candidate.get_last_step_backend() == ("native" if solver != null else "gdscript"),"Actual backend selected")
	# Thermostat, reflective boundaries, small dt skip, and zero/nonpositive mass semantics.
	var edge := {"p":PackedVector3Array([Vector3(0.79,0,0),Vector3(-0.79,0,0)]),"v":PackedVector3Array([Vector3(3,1,0),Vector3(-3,-1,0)]),"m":PackedFloat32Array([1,2])}
	for module in [reference,candidate]:
		module.box_half_extent = Vector3.ONE
		module.restitution = 0.6
		module.thermostat_enabled = true
		module.target_temperature = 0.7
		module.thermostat_tau = 0.05
		module.set_particle_state(edge.p,edge.v,edge.m)
	for dt in [0.01,0.000001,0.003]:
		reference.step(dt)
		candidate.step(dt)
		close_vectors(candidate.get_positions(),reference.get_positions(),"Boundary positions")
		close_vectors(candidate.get_velocities(),reference.get_velocities(),"Thermostat velocities")
		close_vectors(candidate.get_forces(),reference.get_forces(),"Small dt force cache",1e-5)
	# External edits and count changes are reconciled at the next native tick.
	for count in [1,17,3]:
		state = arrays(count)
		for module in [reference,candidate]:
			module.box_half_extent = Vector3(20,20,20)
			module.set_particle_state(state.p,state.v,state.m)
			module.target_temperature = 0.2
			module._velocities[0] = Vector3(0.2,0.1,0)
		reference.step(0.001)
		candidate.step(0.001)
		close_vectors(candidate.get_positions(),reference.get_positions(),"Edited state positions")
		close_vectors(candidate.get_velocities(),reference.get_velocities(),"Edited state velocities")
	var before: PackedVector3Array = candidate.get_positions().duplicate()
	candidate.set_simulation_active(false)
	candidate._on_sim_tick(0.001,0.0)
	check(candidate.get_positions() == before,"Pause prevents stepping")
	candidate.set_simulation_active(true)
	candidate._on_sim_tick(0.001,0.0)
	check(candidate.get_positions() != before,"Resume commits a tick")
	# Shared telemetry and sentry behavior stay in GDScript.
	var telemetry: Array = []
	var sentry = Sentry.new()
	candidate.add_child(sentry)
	candidate._sentry = sentry
	candidate.md_telemetry_updated.connect(func(snapshot): telemetry.append(snapshot))
	candidate.audit_frequency = 2
	candidate._step_counter = 0
	candidate.step(0.001)
	candidate.step(0.001)
	check(telemetry.size() == 1 and sentry.get_audit_count() == 1,"Audit frequency and signal count preserved")
	# Custom force callbacks retain script execution even with an explicit native preference.
	candidate._force_callable = func(pos):
		var forces := PackedVector3Array()
		forces.resize(pos.size())
		forces.fill(Vector3(0.1,0,0))
		return forces
	candidate.step(0.001)
	check(candidate.get_last_step_backend() == "gdscript","Custom force compatibility path")
	# Long horizon and switching only between completed ticks.
	candidate._force_callable = Callable(candidate,"compute_forces")
	candidate._sentry = null
	state = arrays(8)
	configure_module(reference,"gdscript",state)
	configure_module(candidate,"native",state)
	for i in range(1000):
		if i == 300:
			candidate.compute_backend = "gdscript"
		if i == 600:
			candidate.compute_backend = "auto"
		reference.step(0.001)
		candidate.step(0.001)
	close_vectors(candidate.get_positions(),reference.get_positions(),"1000-step/switch positions",1e-4)
	close_vectors(candidate.get_velocities(),reference.get_velocities(),"1000-step/switch velocities",1e-4)
	if solver != null:
		_direct_solver_checks(solver,reference)
	else:
		print("Native-only solver validation skipped; script fallback verified")
	# Presets, stochastic initialization and spawning remain scripted with controlled draws.
	for module in [reference,candidate]:
		module.particle_count = 27
		module.sigma = 1.1
		module.epsilon = 0.8
		module.cutoff_radius = 3.0
		seed(98765)
		module.reset_simulation()
		seed(12345)
		module.inject_particles(Vector3(7,0,0),1,0.1,Vector3(0.1,0,0))
	close_vectors(candidate.get_positions(),reference.get_positions(),"Reset/spawn initial positions")
	close_vectors(candidate.get_velocities(),reference.get_velocities(),"Reset/spawn initial velocities")
	reference.step(0.001)
	candidate.step(0.001)
	close_vectors(candidate.get_positions(),reference.get_positions(),"Reset/spawn next positions")
	close_vectors(candidate.get_velocities(),reference.get_velocities(),"Reset/spawn next velocities")
	var clock = Clock.new()
	clock.set_fixed_delta(0.001)
	clock.set_paused(true)
	clock.sim_tick.connect(candidate._on_sim_tick)
	var committed: Array = []
	var tick_before: int = candidate._step_counter
	clock.step_executed.connect(func(_time): committed.append(candidate._step_counter))
	clock._physics_process(0.1)
	check(candidate._step_counter == tick_before,"Paused clock does not schedule")
	clock.step_once()
	check(committed.size() == 1 and committed[0] == tick_before+1,"Step-once reports after synchronous commit")
	clock.free()
	_generated_script_check(state)
	for iteration in range(8):
		var module = MD.new()
		root.add_child(module)
		configure_module(module,"native",arrays(2))
		module.step(0.001)
		var owned = module._native_solver
		module.cleanup()
		check(module._native_solver == null and module.get_positions().is_empty(),"Cleanup detaches native state")
		if owned != null:
			check(owned.get_snapshot().positions.is_empty(),"Cleanup clears retained solver")
	reference.free()
	candidate.free()
	print("MOLECULAR checks=%d failures=%d native=%s" % [checks,failures,solver != null])
	quit(1 if failures else 0)
func _direct_solver_checks(solver, reference) -> void:
	var state := arrays(8)
	var config: Dictionary = reference._native_parameters()
	config.thermostat_enabled = false
	check(solver.configure(config),"Valid configuration")
	check(solver.set_state(state.p,state.v,state.m),"Valid state")
	var input_copy: PackedVector3Array = state.p.duplicate()
	state.p[0] += Vector3(10,0,0)
	check(solver.get_snapshot().positions == input_copy,"Native owns uploaded state")
	var snapshot: Dictionary = solver.get_snapshot()
	snapshot.positions[0] += Vector3(10,0,0)
	check(solver.get_snapshot().positions == input_copy,"Snapshot does not expose native buffers")
	var original: Dictionary = solver.export_state()
	for dt in [0.0,-0.01,INF,NAN]:
		check(not solver.advance(dt,1),"Invalid dt rejected")
		check(solver.export_state() == original,"Invalid advance atomic")
	check(not solver.advance(0.001,0),"Invalid substep count")
	check(not solver.advance(0.001,4294967297),"Oversized count rejected before integer conversion")
	check(solver.export_state() == original,"Rejected substep count atomic")
	check(not solver.configure({"schema_version":"1"}),"String schema version rejected")
	check(not solver.configure({"schema_version":2}),"Unknown schema version rejected")
	check(not solver.configure({"cutoff_radius":0.0}),"Invalid cutoff rejected")
	check(not solver.configure({"sigma":NAN}),"Nonfinite configuration rejected")
	check(solver.export_state() == original,"Invalid configuration atomic")
	check(not solver.set_state(input_copy,PackedVector3Array(),state.m),"Mismatched arrays rejected")
	var nonfinite := input_copy.duplicate()
	nonfinite[0] = Vector3(INF,0,0)
	check(not solver.set_state(nonfinite,state.v,state.m),"Nonfinite state rejected")
	check(solver.export_state() == original,"Invalid state atomic")
	check(solver.advance(0.001,10),"Batch native advancement")
	var checkpoint: Dictionary = solver.export_state()
	check(solver.advance(0.001,10),"Checkpoint future")
	var future: Dictionary = solver.get_snapshot()
	check(solver.import_state(checkpoint),"Checkpoint import")
	check(solver.advance(0.001,10),"Checkpoint replay")
	var replay: Dictionary = solver.get_snapshot()
	check(replay.positions == future.positions and replay.velocities == future.velocities and replay.simulation_tick == future.simulation_tick,"Checkpoint deterministic replay")
	var corrupt: Dictionary = checkpoint.duplicate(true)
	corrupt.configuration.sigma = 2.0
	corrupt.forces = PackedVector3Array()
	original = solver.export_state()
	check(not solver.import_state(corrupt),"Incomplete checkpoint rejected")
	check(solver.export_state() == original,"Rejected checkpoint atomic")
	# Coincident particles, exact cutoff and negative coordinates agree with brute force.
	for positions in [PackedVector3Array([Vector3.ZERO,Vector3.ZERO]),PackedVector3Array([Vector3(-2.5,0,0),Vector3.ZERO]),PackedVector3Array([Vector3(-1.4,-1.4,-1.4),Vector3.ZERO])]:
		reference.thermostat_enabled = false
		reference.sigma = 1.0
		reference.cutoff_radius = 2.5
		check(solver.configure(reference._native_parameters()),"Pair configuration")
		var reduced: Dictionary = solver.evaluate(positions)
		close_vectors(reduced.forces,reference.compute_forces_brute_force(positions),"Degenerate/cutoff forces")
		check(close_scalar(reduced.potential_energy,reference.compute_potential_energy(positions)),"Degenerate/cutoff potential")
	solver.clear()
	check(solver.get_snapshot().positions.is_empty(),"Clear releases state")
	check(solver.set_state(PackedVector3Array(),PackedVector3Array(),PackedFloat32Array()),"Empty state accepted")
	check(solver.evaluate(PackedVector3Array()).potential_energy == 0.0,"Empty evaluation")

func vectors_from_json(values: Array) -> PackedVector3Array:
	var result := PackedVector3Array()
	for xyz in values:
		result.append(Vector3(xyz[0],xyz[1],xyz[2]))
	return result
func _golden_fixture_check(native_available: bool) -> void:
	var golden: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/molecular_v1.json"))
	var module = MD.new()
	module.compute_backend = "native"
	module.thermostat_enabled = false
	module.set_particle_state(vectors_from_json(golden.positions),vectors_from_json(golden.velocities),PackedFloat32Array(golden.masses))
	module.step(golden.dt)
	close_vectors(module.get_positions(),vectors_from_json(golden.expected_positions),"Golden positions")
	close_vectors(module.get_velocities(),vectors_from_json(golden.expected_velocities),"Golden velocities")
	close_vectors(module.get_forces(),vectors_from_json(golden.expected_forces),"Golden forces")
	check(close_scalar(module.compute_potential_energy(module.get_positions()),golden.expected_potential_energy),"Golden potential")
	if native_available:
		var before_p: PackedVector3Array = module.get_positions().duplicate()
		var before_v: PackedVector3Array = module.get_velocities().duplicate()
		var ticks: int = module._step_counter
		module.step(1e100)
		check(module.get_positions() == before_p and module.get_velocities() == before_v and module._step_counter == ticks,"Rejected overflowing step never falls into script integration")
	module.free()
func _generated_script_check(state: Dictionary) -> void:
	var source := GDScript.new()
	source.source_code = """extends "res://modules/physics/molecular_dynamics_module.gd"
var force_calls: int = 0
func compute_forces(pos: PackedVector3Array) -> PackedVector3Array:
	force_calls += 1
	var result := PackedVector3Array()
	result.resize(pos.size())
	result.fill(Vector3.ZERO)
	return result
"""
	var status: int = source.reload()
	check(status == OK,"Generated subclass compiles")
	if status != OK:
		return
	var generated = source.new()
	configure_module(generated,"native",state)
	generated.step(0.001)
	check(generated.force_calls >= 2 and generated.get_last_step_backend() == "gdscript","Generated force override is honored")
	generated.free()
