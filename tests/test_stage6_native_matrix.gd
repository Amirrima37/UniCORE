extends SceneTree
func _initialize():
	var rows: Array=[]
	for binary in ["unicore_solver.exe","unicore_solver_debug.exe","unicore_solver_noomp.exe","unicore_solver_debug_noomp.exe"]:
		for thermal in [false,true]:
			var doc=load("res://core/cae/cae_document.gd").new()
			assert(doc.execute("CreatePart",{"kind":"Cylinder","parameters":{"diameter":0.2,"length":0.2}}).is_empty())
			assert(doc.execute("AssignMaterial",{"index":0,"material":{"name":"Matrix","E":1000.0,"nu":0.0,"density":1.0,"k":10.0,"cp":1.0}}).is_empty())
			if thermal:
				assert(doc.execute("SetAnalysis",{"analysis":{"type":"steady_thermal","element":"TET4"}}).is_empty())
				for boundary in [{"face":"Bottom","kind":"temperature","value":300.0},{"face":"Top","kind":"temperature","value":400.0}]:
					assert(doc.execute("ApplyThermalBoundary",{"index":0,"boundary":boundary}).is_empty())
			else:
				assert(doc.execute("ApplySupport",{"index":0,"face":"Bottom"}).is_empty())
				assert(doc.execute("ApplyLoad",{"index":0,"face":"Top","force":[0,1,0]}).is_empty())
			assert(doc.generate_mesh(1).is_empty())
			var jobs=load("res://core/cae/extreme_jobs.gd").new()
			jobs.solver_executable="res://bin/"+binary
			var threads: int=1 if binary.contains("noomp") else 2
			var directory: String=jobs.launch(doc,threads,256)
			assert(not directory.is_empty(),jobs.last_error)
			var deadline:=Time.get_ticks_msec()+15000
			while jobs.status(directory).get("state")!="Completed" and Time.get_ticks_msec()<deadline:await process_frame
			var imported: Dictionary=jobs.load_result(directory,doc.data)
			assert(not imported.is_empty(),jobs.last_error)
			var r: Dictionary=imported.results
			assert(is_finite(r.relative_residual) and r.relative_residual<1e-8)
			var area: float=0.5*8*0.01*sin(TAU/8)
			var error:=0.0
			if thermal:
				for i in r.temperature.size():error=maxf(error,absf(r.temperature[i]-(350+500*doc.data.mesh.nodes[i][1])))
				assert(error<1e-5)
				var balance:=0.0
				for value in r.heat_reactions:balance+=value
				assert(absf(balance)<1e-6)
			else:
				for id in doc.data.mesh.regions[doc.data.parts[0].id].Top:error=maxf(error,absf(r.displacement[id][1]/(0.2/(1000*area))-1))
				assert(error<1e-5)
				var reaction:=0.0
				for value in r.reactions:reaction+=value[1]
				assert(absf(reaction+1)<1e-6)
			var process=JSON.parse_string(FileAccess.get_file_as_string(directory+"/process.json"))
			deadline=Time.get_ticks_msec()+5000
			while OS.is_process_running(process.pid) and Time.get_ticks_msec()<deadline:await process_frame
			assert(not OS.is_process_running(process.pid))
			rows.append({"binary":binary,"threads":threads,"thermal":thermal,"directory":ProjectSettings.globalize_path(directory),"residual":r.relative_residual,"reference_error":error,"pid_stopped":true})
	var file=FileAccess.open("res://docs/workbench-2/stage6-final/native-matrix-fields.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"  "));file.close()
	print("Native Release/Debug with and without OpenMP: eight TET4 solves, verified imports, axial references, balance and process cleanup PASS")
	quit()
