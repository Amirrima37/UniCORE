extends SceneTree
const Wave = preload("res://modules/physics/quantum_wavepacket_module.gd")
const Backend = preload("res://core/physics/compute_backend.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func compare(a: PackedFloat32Array,b: PackedFloat32Array,label: String) -> void:
	check(a.size()==b.size(),label+" size")
	for i in range(mini(a.size(),b.size())):
		check(absf(a[i]-b[i])<=1e-7+1e-6*absf(b[i]),label+str(i))
func _init() -> void:
	var extension: String = "res://bin/unicore_native.gdextension"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--extension="):
			extension = arg.trim_prefix("--extension=")
	if FileAccess.file_exists(extension):
		GDExtensionManager.load_extension(extension)
	var solver = Backend.create_quantum_solver("native")
	check(not "--require-native" in OS.get_cmdline_user_args() or solver != null,"Native quantum required")
	for dimension in [1,2]:
		for potential in [0,1,2,3,4]:
			var reference = Wave.new()
			var candidate = Wave.new()
			reference.compute_backend = "gdscript"
			candidate.compute_backend = "native"
			for module in [reference,candidate]:
				module.grid_size_1d = 65
				module.grid_size_2d_x = 17
				module.grid_size_2d_z = 13
				module.active_dimension = dimension
				module.potential_type = potential
				module.reset_simulation()
			var retained: PackedFloat32Array = candidate.psi_real_1d if dimension==1 else candidate.psi_real_2d
			for tick in range(100):
				reference.step_manual(0.0005)
				candidate.step_manual(0.0005)
				if tick == 0 or tick == 99:
					compare(candidate.psi_real_1d if dimension==1 else candidate.psi_real_2d,reference.psi_real_1d if dimension==1 else reference.psi_real_2d,"Real ")
					compare(candidate.psi_imag_1d if dimension==1 else candidate.psi_imag_2d,reference.psi_imag_1d if dimension==1 else reference.psi_imag_2d,"Imaginary ")
					compare(candidate.prob_density_1d if dimension==1 else candidate.prob_density_2d,reference.prob_density_1d if dimension==1 else reference.prob_density_2d,"Density ")
					for field in ["current_norm","mean_position_x","expectation_energy","transmission_coeff","reflection_coeff"]:
						var expected: float = reference.get(field)
						check(absf(candidate.get(field)-expected)<=1e-7+1e-6*absf(expected),"Observable "+field)
			check(retained==(candidate.psi_real_1d if dimension==1 else candidate.psi_real_2d),"Retained wave buffer stays current")
			check(candidate.get_last_step_backend()==("native" if solver!=null else "gdscript"),"Actual quantum backend")
			if solver != null:
				check(solver.set_state(candidate._native_state()),"Owned wave state")
				var before: Dictionary = solver.export_state()
				check(not solver.advance(NAN,1),"Nonfinite dt rejected")
				check(not solver.advance(0.001,4294967297),"Oversized substeps rejected")
				check(solver.export_state()==before,"Rejected advancement atomic")
				var invalid: Dictionary = candidate._native_state().duplicate(true)
				invalid.real = PackedFloat32Array()
				check(not solver.set_state(invalid),"Wave array mismatch rejected")
				check(solver.export_state()==before,"Wave upload rejection atomic")
				invalid = candidate._native_state().duplicate(true)
				invalid.nx = 2
				check(not solver.set_state(invalid),"Grid edge rejected")
				invalid = candidate._native_state().duplicate(true)
				invalid.potential[0] = NAN
				check(not solver.set_state(invalid),"Nonfinite potential rejected")

				check(solver.advance(0.0005,3),"Advance for replay")
				var future: Dictionary = solver.get_snapshot()
				check(solver.import_state(before),"Wave checkpoint import")
				check(solver.advance(0.0005,3),"Wave replay")
				check(solver.get_snapshot().real==future.real and solver.get_snapshot().imag==future.imag,"Exact checkpoint replay")
			reference.free()
			candidate.free()
	print("QUANTUM checks=%d failures=%d native=%s" % [checks,failures,solver!=null])
	quit(1 if failures else 0)
