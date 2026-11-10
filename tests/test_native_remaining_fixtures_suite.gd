extends SceneTree
const Backend = preload("res://core/physics/compute_backend.gd")
const Nuclear = preload("res://modules/physics/nuclear_decay_module.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func compare(actual,expected,label: String) -> void:
	if expected is Dictionary:
		for key in expected:
			check(actual.has(key),label+" field "+str(key))
			if actual.has(key):
				compare(actual[key],expected[key],label+"."+str(key))
	elif expected is Vector3:
		check(actual.distance_to(expected)<=1e-6+1e-6*expected.length(),label)
	elif expected is float:
		check(actual==expected or absf(actual-expected)<=1e-7+1e-6*absf(expected),label)
	elif typeof(expected) in [TYPE_ARRAY,TYPE_PACKED_VECTOR3_ARRAY,TYPE_PACKED_FLOAT32_ARRAY,TYPE_PACKED_INT32_ARRAY,TYPE_PACKED_BYTE_ARRAY,TYPE_PACKED_STRING_ARRAY]:
		check(actual.size()==expected.size(),label+" count")
		for i in range(mini(actual.size(),expected.size())):
			compare(actual[i],expected[i],label+"["+str(i)+"]")
	else:
		check(actual==expected,label)
func _init() -> void:
	var extension: String = "res://bin/unicore_native.gdextension"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--extension="):
			extension = arg.trim_prefix("--extension=")
	if FileAccess.file_exists(extension):
		GDExtensionManager.load_extension(extension)
	var available: bool = Backend.create_gravity_solver("native")!=null and Backend.create_quantum_solver("native")!=null and Backend.create_nuclear_solver("native")!=null
	check(not "--require-native" in OS.get_cmdline_user_args() or available,"All native solvers required")
	if available:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/remaining_solvers_v1.json"))
		for fixture in data.fixtures:
			var state: Dictionary = bytes_to_var(Marshalls.base64_to_raw(fixture.input_variant_base64))
			var expected: Dictionary = bytes_to_var(Marshalls.base64_to_raw(fixture.expected_variant_base64))
			var solver
			var actual: Dictionary = {}
			if fixture.kind == "gravity":
				solver = Backend.create_gravity_solver("native")
				check(solver.configure(state.configuration),"Golden gravity configuration")
				check(solver.set_state(state.positions,state.velocities,state.masses),"Golden gravity state")
				check(solver.advance(fixture.dt,1),"Golden gravity step")
				actual = solver.get_snapshot()
				actual.potential_energy = solver.evaluate(actual.positions).potential_energy
			elif fixture.kind.begins_with("quantum"):
				solver = Backend.create_quantum_solver("native")
				check(solver.set_state(state),"Golden quantum state")
				check(solver.advance(fixture.dt,1),"Golden quantum step")
				actual = solver.get_snapshot()
			else:
				solver = Backend.create_nuclear_solver("native")
				var module = Nuclear.new()
				check(solver.set_state(state,module.isotope_db),"Golden nuclear state")
				seed(int(fixture.rng_seed))
				check(solver.advance(fixture.dt),"Golden nuclear step")
				var next_draw: float = randf()
				actual = solver.get_snapshot()
				actual.rng_next = next_draw
				actual.events = []
				for i in range(actual.event_types.size()):
					actual.events.append([actual.event_symbols[i],actual.event_channels[i],actual.event_positions[i],actual.event_energies[i]])
				check(next_draw==expected.rng_next,"Golden RNG next draw exact")
				module.free()
			compare(actual,expected,fixture.kind)
	print("REMAINING_FIXTURES checks=%d failures=%d native=%s" % [checks,failures,available])
	quit(1 if failures else 0)
