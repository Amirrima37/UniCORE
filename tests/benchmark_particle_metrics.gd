extends SceneTree
const Sentry = preload("res://core/physics/conservation_sentry.gd")
const Backend = preload("res://core/physics/compute_backend.gd")
func _init() -> void:
	var extension_path: String = "res://bin/unicore_native.gdextension"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--extension="):
			extension_path = argument.trim_prefix("--extension=")
	if FileAccess.file_exists(extension_path):
		GDExtensionManager.load_extension(extension_path)
	var info := {"engine": Engine.get_version_info(), "os": OS.get_name(), "native": Backend.create_particle_metrics("native") != null, "results": []}
	for n in [2, 100, 1000, 10000]:
		var p := PackedVector3Array()
		var v := PackedVector3Array()
		var m := PackedFloat32Array()
		p.resize(n)
		v.resize(n)
		m.resize(n)
		for i in range(n):
			p[i] = Vector3(i*0.01,1,2)
			v[i] = Vector3(1,2,3)
			m[i] = 1.0
		for mode in ["gdscript", "native"]:
			var sentry = Sentry.new()
			sentry.compute_backend = mode
			sentry.emit_update_signal = false
			for warmup in range(20):
				sentry.audit(p,v,m,Callable())
			var samples: Array = []
			for batch in range(11):
				var start: int = Time.get_ticks_usec()
				for iteration in range(100):
					sentry.audit(p,v,m,Callable())
				samples.append(float(Time.get_ticks_usec()-start)/100.0)
			samples.sort()
			info.results.append({"particles": n, "requested_backend": mode, "effective_backend": "native" if mode == "native" and info.native else "gdscript", "median_audit_usec": samples[5], "p95_batch_mean_usec": samples[10]})
			sentry.free()
	print("BENCHMARK_JSON=" + JSON.stringify(info))
	quit()
