extends SceneTree
var failures := 0
var rows: Array=[]
func check(ok: bool,title: String):
	if not ok: failures+=1; push_error(title)
func _initialize():
	create_timer(90).timeout.connect(func(): quit(2))
	var Document=load("res://core/cae/cae_document.gd")
	var Mesher=load("res://core/cae/cylinder_mesher.gd")
	var Display=load("res://core/cae/mesh_display.gd")
	var manager=load("res://core/cae/extreme_jobs.gd").new()
	var previous_error:=1.0
	for density in [1,2,3]:
		var doc=Document.new()
		doc.execute("CreatePart",{"kind":"Cylinder","parameters":{"diameter":0.4,"length":1.0}})
		if density==2:
			doc.execute("SetRotation",{"index":0,"values":[0.3,0.7,-0.4]})
			doc.execute("SetPosition",{"index":0,"values":[1.0,-2.0,3.0]})
		var part: Dictionary=doc.data.parts[0]
		var axis: Array=Mesher.sub(Mesher.transform([0,1,0],part),part.position)
		if density==2:
			var reference_axis: Vector3=Basis.from_euler(Vector3(0.3,0.7,-0.4))*Vector3.UP
			check(Vector3(axis[0],axis[1],axis[2]).distance_to(reference_axis)<1e-6,"Mesh rotation matches independent Godot display basis")
		check(not doc.validate().is_empty(),"Unconstrained cylinder rejected")
		doc.execute("AssignMaterial",{"index":0,"material":{"name":"Analytical axial fixture","E":1000.0,"nu":0.0,"density":1.0,"k":10.0,"cp":1.0}})
		doc.execute("ApplySupport",{"index":0,"face":"Bottom"})
		doc.execute("ApplyLoad",{"index":0,"face":"Top","force":axis})
		check(doc.generate_mesh(density).is_empty(),"Cylinder meshing")
		if density==3:
			doc.execute("RemoveCondition",{"index":0,"key":"load_face"})
			doc.execute("ApplyPressure",{"index":0,"face":"Top","value":-1.0/(0.5*(8*density)*0.04*sin(TAU/(8*density)))})
			doc.generate_mesh(density)
		var mesh: Dictionary=doc.data.mesh
		var area: float=0.5*(8*density)*0.2*0.2*sin(TAU/(8*density))
		check(absf(mesh.quality.total_volume-area)<1e-12,"Polygon reference volume")
		check(mesh.material_regions.size()==mesh.elements.size(),"Every tet has owner")
		var surface_count:=0
		for region in mesh.surface_regions[doc.data.parts[0].id]: surface_count+=mesh.surface_regions[doc.data.parts[0].id][region].size()
		check(surface_count==Display.exterior_faces(mesh.elements).size(),"Every exterior face has exactly one physical region")
		for cell in mesh.elements:
			check(cell.size()==4,"True tetrahedra")
			check(Mesher.determinant(Mesher.sub(mesh.nodes[cell[1]],mesh.nodes[cell[0]]),Mesher.sub(mesh.nodes[cell[2]],mesh.nodes[cell[0]]),Mesher.sub(mesh.nodes[cell[3]],mesh.nodes[cell[0]]))>0,"Positive tet orientation")
		var directory: String=manager.launch(doc,1,256)
		check(not directory.is_empty(),"Structural export: "+manager.last_error)
		var deadline=Time.get_ticks_msec()+15000
		while manager.load_result(directory).is_empty() and Time.get_ticks_msec()<deadline: await process_frame
		var imported: Dictionary=manager.load_result(directory)
		check(not imported.is_empty(),"Structural cylinder solve")
		if imported.is_empty(): quit(1); return
		var result: Dictionary=imported.results
		var top: Array=mesh.regions[doc.data.parts[0].id].Top
		var u:=0.0
		for id in top:
			for j in 3: u+=result.displacement[id][j]*axis[j]/top.size()
		var reaction:=0.0
		for vector in result.reactions:
			for j in 3: reaction+=vector[j]*axis[j]
		var error: float=absf(u/(1.0/(1000*PI*0.04))-1)
		check(absf(u/(1.0/(1000*area))-1)<1e-5,"Axial displacement vs exact polygon rod nu=0")
		check(absf(reaction+1)<1e-6,"Applied force / reaction balance")
		check(error<previous_error,"Circle displacement convergence")
		previous_error=error
		doc.execute("ClearAnalysisConditions",{"index":0})
		doc.execute("SetAnalysis",{"analysis":{"type":"steady_thermal","element":"TET4"}})
		doc.execute("ApplyThermalBoundary",{"index":0,"boundary":{"face":"Bottom","kind":"temperature","value":300.0}})
		doc.execute("ApplyThermalBoundary",{"index":0,"boundary":{"face":"Top","kind":"temperature","value":400.0}})
		doc.execute("ApplyThermalBoundary",{"index":0,"boundary":{"face":"Lateral","kind":"flux","value":0.0}})
		doc.generate_mesh(density)
		directory=manager.launch(doc,1,256)
		check(not directory.is_empty(),"Thermal export")
		deadline=Time.get_ticks_msec()+15000
		while manager.load_result(directory).is_empty() and Time.get_ticks_msec()<deadline: await process_frame
		imported=manager.load_result(directory)
		check(not imported.is_empty(),"Thermal cylinder solve")
		if imported.is_empty(): quit(1); return
		result=imported.results
		var temperature_error:=0.0
		for i in mesh.nodes.size():
			var delta: Array=Mesher.sub(mesh.nodes[i],part.position)
			var y: float=delta[0]*axis[0]+delta[1]*axis[1]+delta[2]*axis[2]
			temperature_error=maxf(temperature_error,absf(result.temperature[i]-(350+100*y)))
		check(temperature_error<1e-5,"Linear axial temperature field")
		var heat:=0.0
		for id in top: heat+=result.heat_reactions[id]
		check(absf(absf(heat)/(1000*area)-1)<1e-5,"Analytical polygon heat rate")
		rows.append({"density":density,"nodes":mesh.nodes.size(),"tets":mesh.elements.size(),"polygon_area":area,"displacement_m":u,"circle_displacement_relative_error":error,"reaction_N":reaction,"temperature_max_error_K":temperature_error,"heat_rate_W":absf(heat),"circle_heat_rate_relative_error":absf(absf(heat)/(1000*PI*0.04)-1),"generation_ms":mesh.quality.generation_ms})
	# Geometry validity under transformed, translated, scaled and slender cylinders.
	for length in [0.05,2.0]:
		for density in [1,2,4]:
			var doc=Document.new()
			doc.execute("CreatePart",{"kind":"Cylinder","parameters":{"diameter":0.4,"length":length}})
			doc.execute("SetRotation",{"index":0,"values":[0.3,0.7,-0.4]})
			doc.execute("SetPosition",{"index":0,"values":[1.0,-2.0,3.0]})
			doc.execute("SetScale",{"index":0,"values":[1.5,0.75,1.5]})
			check(doc.generate_mesh(density).is_empty(),"Transformed/aspect cylinder geometry")
			var expected_volume: float=0.5*(8*density)*0.3*0.3*sin(TAU/(8*density))*length*0.75
			check(absf(doc.data.mesh.quality.total_volume/expected_volume-1)<1e-10,"Scaled transformed polygon volume")
			check(doc.data.mesh.quality.minimum_jacobian>0,"Transformed positive determinant")
	var doc=Document.new()
	doc.execute("CreatePart",{"kind":"Cylinder"})
	doc.execute("SetScale",{"index":0,"values":[1,1,2]})
	check(not doc.generate_mesh(1).is_empty(),"Elliptical radial scaling rejected")
	var report={"failures":failures,"cases":rows}
	var file=FileAccess.open("res://docs/workbench-2/stage4-cylinder-numerical.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ",true,true))
	print("Cylinder FEM failures=",failures)
	quit(0 if failures==0 else 1)
