extends RefCounted
## Discovery is deliberately separate from numerical verification.
func discover() -> Array:
	var native_path := "res://bin/unicore_solver.exe"
	var installed := FileAccess.file_exists(native_path)
	return [{"id":"extreme_cpu","label":"Extreme CPU","executable":native_path,
		"status":"installed_unverified" if installed else "missing_dependency",
		"diagnostic":"Existing native numerical checkpoints retained; installation has not been revalidated by discovery.",
		"analyses":["static_structural","steady_thermal","transient_thermal"]}]
