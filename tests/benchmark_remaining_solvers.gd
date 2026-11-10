extends SceneTree
const Gravity = preload("res://modules/physics/n_body_gravity_module.gd")
const Wave = preload("res://modules/physics/quantum_wavepacket_module.gd")
const Nuclear = preload("res://modules/physics/nuclear_decay_module.gd")
func reset_fixture(module,kind: String,count: int) -> void:
	if kind == "gravity":
		module.enable_trails = false
		module._positions.resize(count)
		module._velocities.resize(count)
		module._masses.resize(count)
		for i in range(count):
			module._positions[i] = Vector3(sin(float(i)*1.9)*5,cos(float(i)*0.7)*3,float(i)*0.12)
			module._velocities[i] = Vector3(0.1,0.02,0.03)
			module._masses[i] = 1.0+float(i%3)
	elif kind.begins_with("quantum"):
		module.grid_size_1d = count
		module.grid_size_2d_x = count
		module.grid_size_2d_z = count
		module.active_dimension = 1 if kind == "quantum_1d" else 2
		module.reset_simulation()
	elif kind == "nuclear":
		module.half_life_multiplier = 0.01
		module.setup_isotope_sample("U-235",count,5.0)
	else:
		module.setup_reactor_core(count,5.0)
		for i in range(mini(count,32)):
			module.inject_trigger_neutron(module.nuclei_positions[i],Vector3(0.1,0,0))
func advance(module,kind: String) -> void:
	if kind == "gravity":
		module.step(0.0005)
	else:
		module.step_manual(0.0005)
func packed_state(module,kind: String) -> Dictionary:
	if kind == "gravity":
		return {"positions":module.get_positions(),"velocities":module.get_velocities(),"masses":module.get_masses(),"configuration":module._native_parameters()}
	return module._native_state()
func capture() -> void:
	var fixtures: Array = []
	for kind in ["gravity","quantum_1d","quantum_2d","nuclear"]:
		var module = Gravity.new() if kind == "gravity" else (Wave.new() if kind.begins_with("quantum") else Nuclear.new())
		module.compute_backend = "gdscript"
		reset_fixture(module,kind,3 if kind == "gravity" else (9 if kind.begins_with("quantum") else 1))
		if kind == "nuclear":
			module.half_life_multiplier = 0.000001
			module.setup_isotope_sample("Ra-226",1,0.0)
		var input: Dictionary = packed_state(module,kind)
		# Variant encoding retains packed types, float32 bits, integer widths and infinite half-lives.
		var encoded_input: String = Marshalls.raw_to_base64(var_to_bytes(input))
		var events: Array = []
		if kind == "nuclear":
			module.decay_occurred.connect(func(symbol,ch,pos,q): events.append([symbol,ch,pos,q]))
		seed(54321)
		advance(module,kind)
		var next_draw: float = randf()
		var expected: Dictionary = {}
		if kind == "gravity":
			expected = {"positions":module.get_positions(),"velocities":module.get_velocities(),"forces":module._forces_scratch,"potential_energy":module._calculate_total_potential_energy(module.get_positions())}
		elif kind.begins_with("quantum"):
			var one: bool = module.active_dimension == 1
			expected = {"real":module.psi_real_1d if one else module.psi_real_2d,"imag":module.psi_imag_1d if one else module.psi_imag_2d,
				"density":module.prob_density_1d if one else module.prob_density_2d,"norm":module.current_norm,"mean_position":module.mean_position_x,
				"energy":module.expectation_energy,"transmission":module.transmission_coeff,"reflection":module.reflection_coeff}
		else:
			for field in ["nuclei_positions","nuclei_velocities","nuclei_masses","nuclei_half_lives","nuclei_channels","nuclei_active","rad_positions","rad_velocities","rad_masses","rad_lifetimes","rad_types","rad_active","active_nuclei_count","active_rad_count","total_decay_events","total_fission_events"]:
				expected[field] = module.get(field)
			expected.nuclei_isotope_keys = PackedStringArray(module.nuclei_isotope_keys)
			expected.total_energy = module.compute_total_energy()
			expected.total_momentum = module.compute_total_momentum()
			expected.events = events
			expected.rng_next = next_draw
		fixtures.append({"kind":kind,"schema_version":1,"units":"simulation","rng_seed":54321,"dt":0.0005,
			"input_variant_base64":encoded_input,"expected_variant_base64":Marshalls.raw_to_base64(var_to_bytes(expected))})
		module.free()
	print("REMAINING_FIXTURES_JSON="+JSON.stringify({"engine":Engine.get_version_info(),"precision":"single","fixtures":fixtures}))
func _init() -> void:
	if "--capture-fixtures" in OS.get_cmdline_user_args():
		capture()
		quit()
		return
	var extension: String = "res://bin/unicore_native.gdextension"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--extension="):
			extension = arg.trim_prefix("--extension=")
	if FileAccess.file_exists(extension):
		GDExtensionManager.load_extension(extension)
	var report := {"engine":Engine.get_version_info(),"headless":true,"results":[]}
	for kind in ["gravity","quantum_1d","quantum_2d","nuclear","nuclear_fission"]:
		var sizes: Array = [2,64,256,512] if kind == "gravity" else ([9,128,512] if kind == "quantum_1d" else ([3,16,32] if kind == "quantum_2d" else [64,512,1024]))
		for count in sizes:
			for mode in ["gdscript","native","auto"]:
				var module = Gravity.new() if kind == "gravity" else (Wave.new() if kind.begins_with("quantum") else Nuclear.new())
				module.compute_backend = mode
				reset_fixture(module,kind,count)
				seed(12345)
				for warmup in range(3):
					advance(module,kind)
				var samples: Array = []
				for batch in range(5):
					reset_fixture(module,kind,count)
					seed(12345+batch)
					var start: int = Time.get_ticks_usec()
					for tick in range(3):
						advance(module,kind)
					samples.append(float(Time.get_ticks_usec()-start)/3.0)
				samples.sort()
				var actual: String = module.get_last_step_backend()
				if mode != "auto" and actual != mode:
					push_error("Benchmark backend unavailable: "+kind+" "+mode)
					quit(1)
					return
				report.results.append({"kind":kind,"size":count,"requested_backend":mode,"effective_backend":actual,"median_step_usec":samples[2],"p95_batch_mean_usec":samples[4]})
				module.free()
	print("REMAINING_BENCHMARK_JSON="+JSON.stringify(report))
	quit()
