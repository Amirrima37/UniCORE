extends SceneTree
const Sentry = preload("res://core/physics/conservation_sentry.gd")
const Backend = preload("res://core/physics/compute_backend.gd")
var failures: int = 0
var checks: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _init() -> void:
	var extension_path: String = "res://bin/unicore_native.gdextension"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--extension="):
			extension_path = argument.trim_prefix("--extension=")
	if FileAccess.file_exists(extension_path):
		GDExtensionManager.load_extension(extension_path)
	var native = Backend.create_particle_metrics("native")
	var require_native: bool = "--require-native" in OS.get_cmdline_user_args()
	check(not require_native or native != null, "Native extension required but unavailable")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/particle_metrics_v1.json"))
	var p := PackedVector3Array()
	var v := PackedVector3Array()
	for xyz in fixture.positions:
		p.append(Vector3(xyz[0],xyz[1],xyz[2]))
	for xyz in fixture.velocities:
		v.append(Vector3(xyz[0],xyz[1],xyz[2]))
	var m := PackedFloat32Array(fixture.masses)
	var reference = Sentry.new()
	reference.compute_backend = "gdscript"
	var candidate = Sentry.new()
	candidate.compute_backend = "native"
	var updates: Array = []
	candidate.invariants_updated.connect(func(s): updates.append(s))
	var warnings: Array = []
	candidate.conservation_warning.connect(func(kind, drift): warnings.append([kind, drift]))
	var calls: Array = []
	var potential := func(_positions):
		calls.append(1)
		return -2.0
	var expected: Dictionary = reference.audit(p,v,m,potential)
	var actual: Dictionary = candidate.audit(p,v,m,potential)
	check(actual == expected, "Analytical snapshot parity")
	check(actual.kinetic_energy == 22.0 and actual.total_energy == 20.0, "Analytical energy")
	check(actual.linear_momentum == Vector3(12,4,0), "Analytical momentum")
	check(actual.angular_momentum == Vector3(0,0,-20), "Analytical angular momentum")
	check(updates.size() == 1 and calls.size() == 2, "Signal and potential callback count")
	var empty: Dictionary = candidate.audit(PackedVector3Array(),PackedVector3Array(),PackedFloat32Array(),potential)
	check(empty.audit_count == 1 and updates.size() == 1 and calls.size() == 2, "Empty audit preserves counter and skips callback/signals")
	check(candidate.audit(p,v,PackedFloat32Array(),potential).is_empty(), "Mismatch rejected")
	check(candidate.get_audit_count() == 1, "Rejected audit does not increment")
	candidate.register_system(0.0, Vector3.ZERO, Vector3.ZERO)
	actual = candidate.audit(p,v,m,potential)
	check(not actual.is_conserved and warnings.size() == 3, "Zero baseline warnings")
	candidate.register_system(20.0, Vector3.ZERO, Vector3.ZERO)
	actual = candidate.audit(p,v,m,potential)
	check(actual.is_conserved, "Momentum warnings do not change energy-only is_conserved")
	candidate.register_system(20.0 / (1.0 + candidate.energy_tolerance * 0.99))
	check(candidate.audit(p,v,m,potential).is_conserved, "Below energy threshold")
	candidate.register_system(20.0 / (1.0 + candidate.energy_tolerance * 1.01))
	check(not candidate.audit(p,v,m,potential).is_conserved, "Above energy threshold")
	# Characterize the existing shared baseline: the second caller does not get an isolated registration.
	candidate.reset()
	candidate.audit(p,v,m,potential)
	var other_v := PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
	check(not candidate.audit(p,other_v,m,potential).is_conserved, "Shared sentry baseline remains shared")
	check(candidate.get_audit_count() == 2, "Shared callers increment one counter")
	candidate.compute_backend = "auto"
	var rng := RandomNumberGenerator.new()
	rng.seed = 30102026
	for trial in range(8):
		p.resize(257)
		v.resize(257)
		m.resize(257)
		for i in range(257):
			p[i] = Vector3(rng.randf_range(-50,50), rng.randf_range(-50,50), rng.randf_range(-50,50))
			v[i] = Vector3(rng.randf_range(-4,4), rng.randf_range(-4,4), rng.randf_range(-4,4))
			m[i] = rng.randf_range(0.001,100)
		reference.reset()
		candidate.reset()
		expected = reference.audit(p,v,m,Callable())
		actual = candidate.audit(p,v,m,Callable())
		check(actual.keys() == expected.keys(), "Snapshot schema")
		for key in expected:
			if expected[key] is float:
				check(absf(actual[key]-expected[key]) <= 1e-8 + 1e-6*absf(expected[key]), "Scalar parity: " + key)
			elif expected[key] is Vector3:
				check(actual[key].distance_to(expected[key]) <= 1e-6 + 1e-6*expected[key].length(), "Vector parity: " + key)
			else:
				check(actual[key] == expected[key], "Exact parity: " + key)
	if native != null:
		check(native.reduce(p,v,PackedFloat32Array()).is_empty(), "Native mismatch validation")
		p[0] = Vector3(INF,0,0)
		check(native.reduce(p,v,m).is_empty(), "Native nonfinite validation")
		check(native.reduce(PackedVector3Array(),PackedVector3Array(),PackedFloat32Array()).kinetic_energy == 0.0, "Native empty reduction")
	else:
		print("Native-specific checks skipped; missing-extension fallback tested")
	reference.free()
	candidate.free()
	print("METRICS checks=%d failures=%d native=%s" % [checks, failures, native != null])
	quit(1 if failures else 0)
