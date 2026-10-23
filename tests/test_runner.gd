extends SceneTree

# UniCORE Master Test Runner (Aggregator)
# Runs all test suites in res://tests/ sequentially and provides unified exit code and statistics.

func _init() -> void:
	print("\n========================================================")
	print("       UniCORE Master Test Suite Aggregator")
	print("========================================================")
	
	var exe_path := OS.get_executable_path()
	var test_dir := "res://tests"
	var dir := DirAccess.open(test_dir)
	
	if dir == null:
		print("ERROR: Cannot open tests directory: ", test_dir)
		quit(1)
		return
		
	var suites: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with("_suite.gd") and file_name != "test_runner.gd":
			suites.append("res://tests/" + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	
	suites.sort()
	print("Discovered %d test suites in %s\n" % [suites.size(), test_dir])
	
	var total_suites: int = suites.size()
	var passed_suites: int = 0
	var failed_suites: int = 0
	var failed_names: Array[String] = []
	
	for suite_path in suites:
		var suite_file := suite_path.get_file()
		print("--------------------------------------------------------")
		print(">>> Running: %s" % suite_file)
		print("--------------------------------------------------------")
		
		var output: Array = []
		var args := ["--headless", "--path", ".", "-s", suite_path]
		var exit_code := OS.execute(exe_path, args, output, true)
		
		if output.size() > 0:
			print(output[0])
			
		if exit_code == 0:
			passed_suites += 1
			print(">>> [SUITE PASS] %s\n" % suite_file)
		else:
			failed_suites += 1
			failed_names.append(suite_file)
			print(">>> [SUITE FAIL] %s (Exit Code: %d)\n" % [suite_file, exit_code])
			
	print("========================================================")
	print("               TEST RUNNER SUMMARY")
	print("========================================================")
	print("Total Suites:  %d" % total_suites)
	print("Passed Suites: %d" % passed_suites)
	print("Failed Suites: %d" % failed_suites)
	
	if failed_suites > 0:
		print("\nFailed Suites List:")
		for f in failed_names:
			print("  - %s" % f)
		print("\nOVERALL STATUS: FAILED")
		print("========================================================\n")
		quit(1)
	else:
		print("\nOVERALL STATUS: ALL SUITES PASSED (100%)")
		print("========================================================\n")
		quit(0)
