extends SceneTree
const Nuclear = preload("res://modules/physics/nuclear_decay_module.gd")
const Backend = preload("res://core/physics/compute_backend.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func compare(reference,candidate) -> void:
	for field in ["nuclei_active","nuclei_channels","nuclei_isotope_keys","rad_active","rad_types","active_nuclei_count","active_rad_count","total_decay_events","total_fission_events"]:
		check(reference.get(field)==candidate.get(field),"Exact state "+field)
	for field in ["nuclei_positions","nuclei_velocities","rad_positions","rad_velocities"]:
		var a: PackedVector3Array = candidate.get(field)
		var b: PackedVector3Array = reference.get(field)
		check(a.size()==b.size(),"Size "+field)
		for i in range(mini(a.size(),b.size())):
			check(a[i].distance_to(b[i])<=1e-6+1e-6*b[i].length(),field+str(i))
	for field in ["nuclei_masses","nuclei_half_lives","rad_masses","rad_lifetimes"]:
		var a: PackedFloat32Array = candidate.get(field)
		var b: PackedFloat32Array = reference.get(field)
		check(a.size()==b.size(),"Size "+field)
		for i in range(mini(a.size(),b.size())):
			check(a[i]==b[i] or absf(a[i]-b[i])<=1e-7+1e-6*absf(b[i]),field+str(i))
	var energy: float = reference.compute_total_energy()
	check(absf(candidate.compute_total_energy()-energy)<=1e-7+1e-6*absf(energy),"Nuclear energy")
	var momentum: Vector3 = reference.compute_total_momentum()
	check(candidate.compute_total_momentum().distance_to(momentum)<=1e-5+1e-6*momentum.length(),"Nuclear momentum")
func _init() -> void:
	var extension: String = "res://bin/unicore_native.gdextension"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--extension="):
			extension = arg.trim_prefix("--extension=")
	if FileAccess.file_exists(extension):
		GDExtensionManager.load_extension(extension)
	var solver = Backend.create_nuclear_solver("native")
	check(not "--require-native" in OS.get_cmdline_user_args() or solver!=null,"Native nuclear required")
	for sample in ["Ra-226","C-14","Gamma","gamma_emitter","reactor","boundary"]:
		for rods in [0.0,0.6,1.0]:
			var reference = Nuclear.new()
			var candidate = Nuclear.new()
			reference.compute_backend = "gdscript"
			candidate.compute_backend = "native"
			var reference_events: Array = []
			var candidate_events: Array = []
			reference.decay_occurred.connect(func(symbol,channel,pos,q): reference_events.append([symbol,channel,pos,q]))
			reference.fission_triggered.connect(func(pos,fragments,prompt,q): reference_events.append([pos,fragments,prompt,q]))
			for module in [reference,candidate]:
				module.half_life_multiplier = 0.001
				module.control_rod_depth = rods
				if sample == "reactor":
					module.setup_reactor_core(3,0.0)
					module.inject_trigger_neutron(Vector3.ZERO,Vector3(0,0,1))
				elif sample == "gamma_emitter":
					module.setup_isotope_sample("Ra-226",8,2.0)
					module.nuclei_channels.fill(3)
					module.nuclei_half_lives.fill(0.001)
				elif sample == "boundary":
					module.setup_isotope_sample("H-2",1,0.0)
					module.nuclei_positions[0] = Vector3(40.1,0,0)
					module.nuclei_velocities[0] = Vector3(2,0,0)
					module.spawn_radiation(Vector3(80,0,0),Vector3(50,0,0),0,3,0.005)
				else:
					module.setup_isotope_sample(sample,8,2.0)
			var retained_nuclei: PackedVector3Array = candidate.nuclei_positions
			var retained_radiation: PackedVector3Array = candidate.rad_positions
			for tick in range(10):
				seed(10000+tick)
				reference.step_manual(0.01)
				var next_reference: float = randf()
				seed(10000+tick)
				candidate.step_manual(0.01)
				var next_candidate: float = randf()
				if solver != null:
					var batch: Dictionary = candidate._native_solver.get_snapshot()
					for i in range(batch.event_types.size()):
						if batch.event_types[i] == 0:
							candidate_events.append([batch.event_symbols[i],batch.event_channels[i],batch.event_positions[i],batch.event_energies[i]])
						else:
							candidate_events.append([batch.event_positions[i],2,batch.event_prompt_counts[i],batch.event_energies[i]])
				check(next_reference==next_candidate,"Exact RNG consumption")
				compare(reference,candidate)
				check(candidate.get_last_step_backend()==("native" if solver!=null else "gdscript"),"Actual nuclear backend")
			check(retained_nuclei==candidate.nuclei_positions and retained_radiation==candidate.rad_positions,"Retained nuclear arrays stay current")
			if solver != null:
				check(reference_events==candidate_events,"Exact nuclear event payload/order")
			candidate.decay_occurred.connect(func(_symbol,_channel,_pos,_q): pass)
			candidate.compute_backend = "auto"
			candidate.step_manual(0.01)
			check(candidate.get_last_step_backend()=="gdscript","Auto preserves per-event callback timing")
			if solver!=null:
				check(solver.set_state(reference._native_state(),reference.isotope_db),"Valid nuclear state")
				var before: Dictionary = solver.get_snapshot()
				check(not solver.advance(NAN),"Invalid dt rejected")
				check(solver.get_snapshot()==before,"Invalid nuclear advance atomic")
			reference.free()
			candidate.free()
	if solver != null:
		var maximum: Dictionary = solver.get_snapshot()
		maximum.total_decay_events = 9223372036854775807
		maximum.nuclei_isotope_keys[0] = "Ra-226"
		maximum.nuclei_channels[0] = 1
		maximum.nuclei_masses[0] = 226.0254
		maximum.nuclei_half_lives[0] = 0.0001
		var donor = Nuclear.new()
		check(solver.set_state(maximum,donor.isotope_db),"Counter-limit state upload")
		var before: Dictionary = solver.get_snapshot()
		seed(777)
		var next_draw: float = randf()
		seed(777)
		check(not solver.advance(0.01),"Counter overflow risk rejected")
		check(solver.get_snapshot()==before,"Counter rejection atomic")
		check(randf()==next_draw,"Counter rejection consumes no RNG")
		donor.free()
	print("NUCLEAR checks=%d failures=%d native=%s" % [checks,failures,solver!=null])
	quit(1 if failures else 0)
