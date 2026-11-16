extends SceneTree
func _initialize():
	create_timer(60).timeout.connect(func():quit(2))
	GDExtensionManager.load_extension("res://bin/unicore_native.gdextension")
	var doc=load("res://core/cae/cae_document.gd").new();var manager=load("res://core/cae/extreme_jobs.gd").new()
	doc.execute("CreatePart");doc.execute("AssignMaterialById",{"index":0,"material_id":"Aluminum 6061-T6"})
	doc.execute("ApplySupport",{"index":0,"face":"X-"});doc.execute("ApplyLoad",{"index":0,"face":"X+","force":[100,0,0]})
	var rows:=[]
	for kind in ["static_structural","steady_thermal","transient_thermal"]:
		if kind!="static_structural":
			doc.execute("AssignMaterialById",{"index":0,"material_id":"Stainless steel 316"})
			doc.execute("ApplyThermalBoundary",{"index":0,"boundary":{"kind":"temperature","face":"X-","value":600}})
			doc.execute("ApplyThermalBoundary",{"index":0,"boundary":{"kind":"radiation","face":"X+","emissivity":0.8,"surroundings":300}})
		doc.execute("SetAnalysis",{"analysis":{"type":kind,"time_step":0.1,"steps":3,"initial_temperature":400}});doc.generate_mesh(2)
		var native_solver=ClassDB.instantiate("UniCoreStructuralSolver" if kind=="static_structural" else "UniCoreThermalSolver")
		var baseline: Dictionary=native_solver.solve_model(doc.data);print(kind," native ok=",baseline.get("ok")," ",baseline.get("error",""));assert(baseline.ok)
		var directory: String=manager.launch(doc,1,256);assert(not directory.is_empty(),manager.last_error)
		while not FileAccess.file_exists(directory+"/results.json"):
			await process_frame
			if FileAccess.file_exists(directory+"/status.json"):
				var stream:=FileAccess.open(directory+"/status.json",FileAccess.READ)
				if stream==null:continue
				var parser:=JSON.new()
				var text:=stream.get_as_text();stream.close()
				if parser.parse(text)!=OK:continue
				var state=parser.data
				assert(state==null or state.state!="Failed",str(state))
		var actual: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(directory+"/results.json"));var error:=0.0
		if kind=="static_structural":
			for i in baseline.displacement.size():
				for j in 3:error=maxf(error,absf(baseline.displacement[i][j]-actual.displacement_flat[3*i+j]))
		else:
			for i in baseline.temperature.size():error=maxf(error,absf(baseline.temperature[i]-actual.temperature[i]))
		var secondary_error:=0.0
		var history_error:=0.0
		if kind=="static_structural":
			for i in baseline.stress.size():
				for j in 6:secondary_error=maxf(secondary_error,absf(baseline.stress[i][j]-actual.stress[i][j]))
			assert(secondary_error<1e-6)
			for i in baseline.reactions.size():
				for j in 3:assert(absf(baseline.reactions[i][j]-actual.reactions_flat[3*i+j])<1e-8)
		else:
			for i in baseline.heat_flux.size():
				for j in 3:secondary_error=maxf(secondary_error,absf(baseline.heat_flux[i][j]-actual.heat_flux[i][j]))
			assert(secondary_error<1e-6)
			assert(absf(baseline.energy_balance_W-actual.energy_balance_W)<1e-7)
			assert(actual.history.size()==baseline.history.size())
			for frame in baseline.history.size():
				for i in baseline.history[frame].size():history_error=maxf(history_error,absf(baseline.history[frame][i]-actual.history[frame][i]))
			assert(history_error<1e-7)
		assert(actual.relative_residual<=1e-7 and baseline.relative_residual<=1e-7)
		print(kind," difference=",error)
		assert(error<(1e-13 if kind=="static_structural" else 1e-7))
		rows.append({"analysis":kind,"maximum_field_difference":error,"stress_or_flux_difference":secondary_error,"history_difference":history_error,"native_residual":baseline.relative_residual,"residual":actual.relative_residual,"iterations":actual.iterations})
	print(JSON.stringify(rows))
	var file:=FileAccess.open("res://docs/extreme-mode/equivalence.json",FileAccess.WRITE);file.store_string(JSON.stringify(rows,"\t"))
	print("Standalone numerical equivalence PASS");quit()
