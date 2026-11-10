extends SceneTree
const MD = preload("res://modules/physics/molecular_dynamics_module.gd")
const Sentry = preload("res://core/physics/conservation_sentry.gd")
const Backend = preload("res://core/physics/compute_backend.gd")
func fixture(count: int) -> Dictionary:
	var side: int = int(ceil(pow(float(count),1.0/3.0)))
	var positions := PackedVector3Array()
	var velocities := PackedVector3Array()
	var masses := PackedFloat32Array()
	for i in range(count):
		positions.append(Vector3(float(i%side)*1.4,float((i/side)%side)*1.4,float(i/(side*side))*1.4)-Vector3.ONE*float(side)*0.7)
		velocities.append(Vector3(0.05*sin(float(i)),0.05*cos(float(i)),0.02))
		masses.append(1.0)
	return {"positions":positions,"velocities":velocities,"masses":masses}
func json_vectors(values: PackedVector3Array) -> Array:
	var result: Array = []
	for value in values:
		result.append([value.x,value.y,value.z])
	return result
func capture_fixture() -> void:
	var module = MD.new()
	module.compute_backend = "gdscript"
	module.thermostat_enabled = false
	var state := fixture(8)
	module.set_particle_state(state.positions,state.velocities,state.masses)
	module.step(0.001)
	var result := {"schema_version":1,"units":"simulation","precision":"float32 vectors/masses; float64 scalars","dt":0.001,
		"positions":json_vectors(state.positions),"velocities":json_vectors(state.velocities),"masses":Array(state.masses),
		"expected_positions":json_vectors(module.get_positions()),"expected_velocities":json_vectors(module.get_velocities()),
		"expected_forces":json_vectors(module.get_forces()),"expected_potential_energy":module.compute_potential_energy(module.get_positions())}
	print("MOLECULAR_FIXTURE_JSON="+JSON.stringify(result))
	module.free()
func _init() -> void:
	if "--capture-fixture" in OS.get_cmdline_user_args():
		capture_fixture()
		quit()
		return
	var extension_path: String = "res://bin/unicore_native.gdextension"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--extension="):
			extension_path = argument.trim_prefix("--extension=")
	if FileAccess.file_exists(extension_path):
		GDExtensionManager.load_extension(extension_path)
	var native_available: bool = Backend.create_molecular_solver("native") != null
	if not native_available:
		push_error("Molecular benchmark requires native solver")
		quit(1)
		return
	var report := {"engine":Engine.get_version_info(),"os":OS.get_name(),"headless":true,"results":[]}
	for count in [2,64,512,1000]:
		var state := fixture(count)
		var repeats: int = 30 if count<=64 else 3
		for audited in [false,true]:
			for mode in ["gdscript","native"]:
				var module = MD.new()
				module.compute_backend = mode
				module.thermostat_enabled = false
				module.box_half_extent = Vector3(30,30,30)
				if audited:
					var sentry = Sentry.new()
					sentry.compute_backend = "gdscript"
					sentry.enable_warnings = false
					sentry.emit_update_signal = false
					module.add_child(sentry)
					module._sentry = sentry
				module.set_particle_state(state.positions,state.velocities,state.masses)
				for warmup in range(3):
					module.step(0.0005)
				var samples: Array = []
				for batch in range(7):
					module.set_particle_state(state.positions,state.velocities,state.masses)
					var start: int = Time.get_ticks_usec()
					for iteration in range(repeats):
						module.step(0.0005)
					samples.append(float(Time.get_ticks_usec()-start)/float(repeats))
				samples.sort()
				report.results.append({"particles":count,"audited":audited,"requested_backend":mode,
					"effective_backend":module.get_last_step_backend(),"median_step_usec":samples[3],"p95_batch_mean_usec":samples[6]})
				module.free()
	print("MOLECULAR_BENCHMARK_JSON="+JSON.stringify(report))
	quit()
