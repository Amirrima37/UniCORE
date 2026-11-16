extends SceneTree
func _initialize():
	var doc=load("res://core/cae/cae_document.gd").new()
	doc.execute("CreatePart",{"kind":"Pipe","parameters":{"outer_radius":0.1,"inner_radius":0.05,"length":0.04}})
	var mesher=load("res://core/cae/pipe_mesher.gd")
	var quality=load("res://core/cae/mesh_display.gd")
	var rows: Array=[]
	for inner in [0.05,0.09,0.099]:
		for density in [1,2,4]:
			var changed: Dictionary=doc.data.duplicate(true);changed.parts[0].inner_diameter=2*inner
			var result: Dictionary=mesher.generate(changed,density)
			if result.has("error"):
				assert("limit" in result.error);rows.append({"inner_radius":inner,"density":density,"rejected":result.error});continue
			var mesh: Dictionary=result.mesh
			load("res://tests/pipe_topology_fixture.gd").new().verify(mesh,doc.data.parts[0].id)
			var sectors: int=mesh.circumferential_sectors
			var values: Array=[];var edges: Array=[];var warning:=0
			for cell in mesh.elements:
				# All projected vertices share one sector half-plane, so the entire
				# convex tetrahedron stays outside the polygonal bore.
				var cx:=0.0;var cz:=0.0
				for id in cell:cx+=mesh.nodes[id][0];cz+=mesh.nodes[id][2]
				var theta:=atan2(cz,cx);var sector:=int(floor(fposmod(theta,TAU)/(TAU/(sectors))))
				var midpoint: float=TAU*(sector+0.5)/(sectors)
				for id in cell:assert(mesh.nodes[id][0]*cos(midpoint)+mesh.nodes[id][2]*sin(midpoint)>=inner*cos(PI/(sectors))-1e-12)
				var q: Dictionary=quality.quality(mesh,cell);values.append(q.mean_ratio);edges.append(q.edge_ratio);warning+=int(q.status=="warning")
			values.sort();edges.sort()
			rows.append({"inner_radius":inner,"density":density,"nodes":mesh.nodes.size(),"elements":mesh.elements.size(),"mean_ratio_min":values[0],"mean_ratio_median":values[values.size()/2],"edge_ratio_max":edges[-1],"warnings":warning,"generation_ms":mesh.quality.generation_ms})
	for value in [0,-0.1,0.2,NAN,INF]:
		var changed: Dictionary=doc.data.duplicate(true);changed.parts[0].inner_diameter=value
		assert(mesher.generate(changed,1).has("error"))
	for key in ["position","rotation","scale"]:
		var changed: Dictionary=doc.data.duplicate(true);changed.parts[0][key]=[NAN,1,1]
		assert(mesher.generate(changed,1).has("error"))
	doc.execute("AssignMaterial",{"index":0,"material":{"name":"Pipe pressure","E":1000.0,"nu":0.0,"density":1.0,"k":10.0,"cp":1.0}})
	doc.execute("ApplySupport",{"index":0,"face":"InletEnd"})
	doc.execute("ApplyPressure",{"index":0,"face":"InnerWall","value":1.0})
	assert(doc.generate_mesh(2).is_empty())
	var jobs=load("res://core/cae/extreme_jobs.gd").new()
	var directory: String=jobs.launch(doc,1,256);assert(not directory.is_empty(),jobs.last_error)
	var deadline:=Time.get_ticks_msec()+15000
	while jobs.status(directory).get("state")!="Completed" and Time.get_ticks_msec()<deadline:await process_frame
	var imported: Dictionary=jobs.load_result(directory,doc.data);assert(not imported.is_empty(),jobs.last_error)
	var radial:=0.0;var reactions: Array=[0.0,0.0,0.0]
	for id in doc.data.mesh.regions[doc.data.parts[0].id].OutletEnd:
		var p: Array=doc.data.mesh.nodes[id];radial+=p[0]*imported.results.displacement[id][0]+p[2]*imported.results.displacement[id][2]
	for reaction in imported.results.reactions:
		for j in 3:reactions[j]+=reaction[j]
	assert(radial>0 and sqrt(jobs.dot64(reactions,reactions))<1e-7)
	doc.data=imported;assert(doc.save_project("res://.tools/stage6-pipe.ucae")==OK)
	var reopened=load("res://core/cae/cae_document.gd").new();assert(reopened.open_project("res://.tools/stage6-pipe.ucae").is_empty())
	assert(not jobs.load_result(directory,reopened.data).is_empty())
	doc.execute("SetParameters",{"index":0,"parameters":{"inner_radius":0.06}});assert(doc.generate_mesh(2).is_empty());assert(jobs.load_result(directory,doc.data).is_empty())
	assert(doc.data.parts[0].pressure.face=="InnerWall")
	var file=FileAccess.open("res://docs/workbench-2/stage6-pipe-contract.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"meshes":rows,"inner_pressure_radial_dot_sum":radial,"reaction_norm_N":sqrt(jobs.dot64(reactions,reactions)),"pressure_residual":imported.results.relative_residual},"  "))
	print("Pipe thin/thick bore/topology/pressure/provenance/persistence PASS")
	quit()
