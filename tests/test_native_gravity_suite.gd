extends SceneTree
const Gravity = preload("res://modules/physics/n_body_gravity_module.gd")
const OctreeScript = preload("res://core/physics/barnes_hut_octree.gd")
const Backend = preload("res://core/physics/compute_backend.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func compare(a: PackedVector3Array,b: PackedVector3Array,label: String,tolerance: float=1e-6) -> void:
	check(a.size()==b.size(),label+" size")
	for i in range(mini(a.size(),b.size())):
		check(a[i].distance_to(b[i])<=1e-6+tolerance*b[i].length(),label+str(i))
func fixture(module,count: int) -> void:
	module.enable_trails = false
	module._positions.resize(count)
	module._velocities.resize(count)
	module._masses.resize(count)
	for i in range(count):
		module._positions[i] = Vector3(sin(float(i)*1.9)*5,cos(float(i)*0.7)*3,float(i)*0.12)
		module._velocities[i] = Vector3(0.1,0.02,0.03)
		module._masses[i] = 1.0+float(i%3)
	module._octree = OctreeScript.new(module.theta_crit,module.softening,module.gravitational_constant)
func _init() -> void:
	var extension: String = "res://bin/unicore_native.gdextension"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--extension="):
			extension = arg.trim_prefix("--extension=")
	if FileAccess.file_exists(extension):
		GDExtensionManager.load_extension(extension)
	var solver = Backend.create_gravity_solver("native")
	check(not "--require-native" in OS.get_cmdline_user_args() or solver != null,"Native gravity required")
	for count in [1,2,17,65]:
		for pn in [0,1,2]:
			for theta in [0.0,0.5]:
				var reference = Gravity.new()
				var candidate = Gravity.new()
				reference.compute_backend = "gdscript"
				candidate.compute_backend = "native"
				for module in [reference,candidate]:
					module.theta_crit = theta
					module.post_newtonian_mode = pn
					fixture(module,count)
				compare(candidate._evaluate_forces_barnes_hut(candidate._positions,candidate._velocities),reference._evaluate_forces_barnes_hut(reference._positions,reference._velocities),"Force ")
				var expected: float = reference._calculate_total_potential_energy(reference._positions)
				var actual: float = candidate._calculate_total_potential_energy(candidate._positions)
				check(absf(actual-expected)<=1e-7+1e-6*absf(expected),"Potential parity")
				var retained: PackedVector3Array = candidate.get_positions()
				for tick in range(12):
					reference.step(0.001)
					candidate.step(0.001)
				check(retained==candidate.get_positions(),"Retained gravity array stays current")
				compare(candidate.get_positions(),reference.get_positions(),"Position ")
				compare(candidate.get_velocities(),reference.get_velocities(),"Velocity ")
				check(candidate.get_last_step_backend()==("native" if solver != null else "gdscript"),"Actual backend")
				check(candidate.get_octree().get_particle_count()==count,"Public tree refreshed")
				reference.free()
				candidate.free()
	# Newtonian overlap and mass edge cases compare with the retained source tree.
	for masses in [PackedFloat32Array([1,2,3]),PackedFloat32Array([0,1,0]),PackedFloat32Array([-1,2,3])]:
		var reference = Gravity.new()
		var candidate = Gravity.new()
		reference.compute_backend = "gdscript"
		candidate.compute_backend = "native"
		for module in [reference,candidate]:
			fixture(module,3)
			module.enable_relativity = false
			module._positions = PackedVector3Array([Vector3.ZERO,Vector3.ZERO,Vector3(1,0,0)])
			module._masses = masses.duplicate()
		compare(candidate._evaluate_forces_barnes_hut(candidate._positions,candidate._velocities),reference._evaluate_forces_barnes_hut(reference._positions,reference._velocities),"Overlap/mass force ")
		reference.free()
		candidate.free()
	if solver != null:
		check(not solver.advance(0.001,4294967297),"Oversized substeps rejected")
		check(not solver.configure({"speed_of_light":0}),"Invalid configuration rejected")
		check(solver.configure({"enable_relativity":false}),"Checkpoint gravity configuration")
		check(solver.set_state(PackedVector3Array([Vector3(-1,0,0),Vector3(1,0,0)]),PackedVector3Array([Vector3(0,0.1,0),Vector3(0,-0.1,0)]),PackedFloat32Array([1,2])),"Checkpoint gravity state")
		var checkpoint: Dictionary = solver.export_state()
		check(solver.advance(0.001,10),"Gravity native batch")
		var future: Dictionary = solver.get_snapshot()
		check(solver.import_state(checkpoint),"Gravity checkpoint import")
		check(solver.advance(0.001,10),"Gravity replay advance")
		check(solver.get_snapshot().positions==future.positions and solver.get_snapshot().velocities==future.velocities,"Exact gravity checkpoint replay")
		var invalid: Dictionary = checkpoint.duplicate(true)
		invalid.configuration.gravitational_constant = 2.0
		invalid.forces = PackedVector3Array()
		var before: Dictionary = solver.export_state()
		check(not solver.import_state(invalid),"Malformed gravity checkpoint rejected")
		check(solver.export_state()==before,"Gravity checkpoint rejection atomic")
		var external: Dictionary = solver.get_snapshot()
		external.positions[0] = Vector3(99,99,99)
		check(solver.get_snapshot().positions!=external.positions,"Gravity snapshots own buffers")

	print("GRAVITY checks=%d failures=%d native=%s" % [checks,failures,solver != null])
	quit(1 if failures else 0)
