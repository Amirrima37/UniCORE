extends SceneTree
func _initialize():
	var rows: Array=[]
	for backend in ["legacy","graded"]:
		var mesher=load("res://tests/fixtures/stage6_cylinder_v1.gd" if backend=="legacy" else "res://core/cae/cylinder_mesher.gd")
		for density in [2,4]:
			var doc=load("res://core/cae/cae_document.gd").new()
			doc.execute("CreatePart",{"kind":"Cylinder","parameters":{"diameter":0.2,"length":0.4}})
			doc.execute("AssignMaterial",{"index":0,"material":{"name":"Axial benchmark","E":1000.0,"nu":0.0,"density":1.0,"k":10.0,"cp":1.0}})
			doc.execute("ApplySupport",{"index":0,"face":"Bottom"})
			doc.execute("ApplyLoad",{"index":0,"face":"Top","force":[0,1,0]})
			doc.execute("SetAnalysis",{"analysis":{"type":"static_structural","element":"TET4"}})
			print("Benchmark ",backend," density ",density)
			var memory_before:=OS.get_static_memory_usage()
			var start:=Time.get_ticks_usec()
			var generated: Dictionary=mesher.generate(doc.data,density)
			assert(not generated.has("error"))
			var row: Dictionary={"backend":backend,"density":density,"generation_ms":(Time.get_ticks_usec()-start)/1000.0,"static_memory_delta_bytes":OS.get_static_memory_usage()-memory_before,"process_static_peak_bytes":OS.get_static_memory_peak_usage()}
			doc.data.mesh=generated.mesh
			row.nodes=generated.mesh.nodes.size(); row.elements=generated.mesh.elements.size()
			var mean: Array=[];var edge: Array=[]
			for cell in generated.mesh.elements:
				var q: Dictionary=load("res://core/cae/mesh_display.gd").quality(generated.mesh,cell)
				mean.append(q.mean_ratio); edge.append(q.edge_ratio)
			mean.sort();edge.sort()
			row.mean_ratio={"min":mean[0],"median":mean[mean.size()/2]}
			row.edge_ratio={"min":edge[0],"median":edge[edge.size()/2],"max":edge[-1]}
			var jobs=load("res://core/cae/extreme_jobs.gd").new()
			for study in ["static_structural","steady_thermal"]:
				if study=="steady_thermal":
					doc.execute("ClearAnalysisConditions",{"index":0})
					doc.execute("SetAnalysis",{"analysis":{"type":study,"element":"TET4"}})
					doc.execute("ApplyThermalBoundary",{"index":0,"boundary":{"face":"Bottom","kind":"temperature","value":300.0}})
					doc.execute("ApplyThermalBoundary",{"index":0,"boundary":{"face":"Top","kind":"temperature","value":400.0}})
					doc.data.mesh=generated.mesh
				start=Time.get_ticks_usec()
				var directory: String=jobs.launch(doc,1,256)
				if directory.is_empty():
					print("EXPORT FAILURE: ",jobs.last_error); quit(1); return
				var export_ms: float=(Time.get_ticks_usec()-start)/1000.0
				var deadline:=Time.get_ticks_msec()+15000
				while jobs.status(directory).get("state")!="Completed" and Time.get_ticks_msec()<deadline: await process_frame
				var elapsed_ms: float=(Time.get_ticks_usec()-start)/1000.0
				if jobs.load_result(directory,doc.data).is_empty():
					print("IMPORT FAILURE: ",jobs.last_error); quit(1); return
				var native: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(directory+"/results.json"))
				row[study]={"export_launch_ms":export_ms,"export_solve_poll_ms":elapsed_ms,"native_solve_ms":native.get("solve_ms"),"native_assembly_ms":native.get("assembly_ms"),"residual":native.get("relative_residual")}
			rows.append(row)
			print(JSON.stringify(row))
	var file=FileAccess.open("res://docs/workbench-2/stage6-cylinder-performance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"  "))
	quit()
