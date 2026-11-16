extends SceneTree
func fail(message: String):
	push_error(message)
	quit(1)
func _initialize():
	var backend=preload("res://core/cae/calculix_backend.gd").new()
	backend.executable="res://.tools/engines/calculix/CalculiX-2.23.0-win-x64/bin/ccx.exe"
	var model={"schema":1,"units":"SI","analysis":"static_structural","nodes":[[0,0,0],[1,0,0],[0,1,0],[0,0,1]],"elements":[[0,1,2,3]],"material":{"E":1000.0,"nu":0.25},"constraints":[[0,0,0],[0,1,0],[0,2,0],[2,0,0],[2,2,0],[3,0,0]],"loads":[[1,0,1.0]]}
	var evidence=[]
	for factors in [[1.0,1.0],[2.0,1.0],[1.0,2.0]]:
		model.material.E=1000.0*factors[0];model.loads[0][2]=factors[1]
		var directory="res://docs/architecture/evidence/calculix/run_%d_%d" % [Time.get_ticks_usec(),evidence.size()]
		var job=backend.prepare_job(model,directory)
		if job.has("error"): fail(job.error); return
		var result=backend.execute_job(job)
		if result.has("error"): fail(result.error); return
		# Constant strain tetrahedron: V=1/6, uniform sigma_xx=F/V,
		# epsilon_xx=sigma/E, lateral strain=-nu*epsilon_xx.
		var expected=0.006*factors[1]/factors[0]
		var error=absf(result.displacement_by_id[1][0]/expected-1)
		if error>1e-6 or absf(result.stress_by_id[0][0]-6*factors[1])>1e-6: fail("Analytical patch mismatch"); return
		if absf(result.displacement_by_id[2][1]+0.25*expected)>1e-8: fail("Poisson strain mismatch");return
		evidence.append({"E_factor":factors[0],"F_factor":factors[1],"ux":result.displacement_by_id[1][0],"relative_error":error,"provenance":result.provenance,"directory":directory})
		var file=FileAccess.open(directory.path_join("parsed.json"),FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close()
		var original=FileAccess.get_file_as_string(directory.path_join("model.inp"))
		file=FileAccess.open(directory.path_join("model.inp"),FileAccess.WRITE);file.store_string(original+"\n");file.close()
		if not backend.import_results(job).has("error"): fail("Changed input accepted");return
		file=FileAccess.open(directory.path_join("model.inp"),FileAccess.WRITE);file.store_string(original);file.close()
	var summary=FileAccess.open("res://docs/architecture/evidence/calculix/numerical.json",FileAccess.WRITE)
	summary.store_string(JSON.stringify(evidence,"  "));summary.close()
	print("CALCULIX_NUMERICAL_PASS: analytical patch, Poisson strain, E/F scaling, input tamper rejection")
	quit()
