extends SceneTree
var failures := 0
func check(value: bool, message: String):
	if not value:
		failures += 1
		push_error(message)
func _initialize():
	GDExtensionManager.load_extension("res://bin/unicore_native.gdextension")
	check(ClassDB.class_exists("UniCoreStructuralSolver"), "Native structural class registered")
	if failures: quit(1); return
	var solver = ClassDB.instantiate("UniCoreStructuralSolver")
	var doc = load("res://core/cae/cae_document.gd").new()
	doc.execute("CreatePart")
	doc.execute("SetDimensions", {"index":0,"values":[1,1,1]})
	doc.execute("AssignMaterial", {"index":0,"material":{"name":"Patch","E":1000,"nu":0,"density":1}})
	doc.execute("ApplySupport", {"index":0,"face":"X-"})
	doc.execute("ApplyLoad", {"index":0,"face":"X+","force":[100,0,0]})
	check(doc.generate_mesh(2) == "", "C++ box mesher")
	var result: Dictionary = solver.solve_model(doc.data)
	check(result.get("ok",false), "Native solve: " + str(result.get("error","")))
	if not result.get("ok",false): quit(1); return
	check(abs(result.max_displacement - 0.1)<1e-8, "Exact axial displacement F L / E A")
	var reaction := Vector3.ZERO
	for v in result.reactions: reaction += Vector3(v[0],v[1],v[2])
	check((reaction - Vector3(-100,0,0)).length()<1e-6, "Force balance")
	for stress in result.stress:
		check(abs(stress[0]-100)<1e-5, "Uniform axial stress")
	check(result.relative_residual<1e-7, "Residual tolerance")
	solver.cancel()
	check(solver.solve_model(doc.data).get("error") == "CANCELLED", "Cancellation")
	solver.reset_cancel()
	check(solver.solve_model(doc.data).get("ok",false), "Recovery after cancellation")
	var bad: Dictionary = doc.data.duplicate(true)
	bad.parts[0].support = ""
	check(not solver.solve_model(bad).get("ok",true), "Missing supports rejected")
	bad = doc.data.duplicate(true)
	bad.parts[0].material.nu = 0.5
	check(not solver.solve_model(bad).get("ok",true), "Invalid material rejected")
	doc.data.results = result
	check(doc.save_project("res://.tools/structural-test.ucae") == OK, "Save results")
	var restored = load("res://core/cae/cae_document.gd").new()
	check(restored.open_project("res://.tools/structural-test.ucae") == "", "Reopen results")
	var repeated: Dictionary = solver.solve_model(restored.data)
	check(abs(repeated.max_displacement - result.max_displacement)<1e-12, "Reproducible solve")
	# Bending convergence: linear tetrahedra are stiff on coarse meshes.
	doc.execute("SetDimensions", {"index":0,"values":[1,.2,.2]})
	doc.execute("AssignMaterial", {"index":0,"material":{"name":"Steel","E":210e9,"nu":.3,"density":7850}})
	doc.execute("ApplyLoad", {"index":0,"face":"X+","force":[0,-1000,0]})
	var last := 0.0
	for resolution in [2,4,8]:
		doc.generate_mesh(resolution)
		var bending: Dictionary = solver.solve_model(doc.data)
		check(bending.get("ok",false), "Cantilever solve at " + str(resolution))
		if bending.get("ok",false):
			print("Cantilever divisions ", resolution, ": ", bending.max_displacement, " m")
			check(bending.max_displacement > last, "Bending displacement increases with refinement")
			last = bending.max_displacement
	# Euler-Bernoulli reference excludes shear and clamp effects: diagnostic only.
	print("Euler-Bernoulli reference: ", 1000.0/(3*210e9*(.2*pow(.2,3)/12)), " m")
	print("Structural bridge checks: ", failures, " failures")
	quit(1 if failures else 0)



