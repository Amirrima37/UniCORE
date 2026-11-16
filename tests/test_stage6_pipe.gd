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
	var previous_heat_error:=INF
	for density in [1,2,4]:
		var doc=Document.new()
		doc.execute("CreatePart",{"kind":"Pipe","parameters":{"outer_radius":0.1,"inner_radius":0.05,"length":0.1}})
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
		doc.execute("ApplySupport",{"index":0,"face":"InletEnd"})
		doc.execute("ApplyLoad",{"index":0,"face":"OutletEnd","force":axis})
		check(doc.generate_mesh(density).is_empty(),"Cylinder meshing")
		if density==4:
			doc.execute("RemoveCondition",{"index":0,"key":"load_face"})
			doc.execute("ApplyPressure",{"index":0,"face":"OutletEnd","value":-1.0/(0.5*(16*density)*0.0075*sin(TAU/(16*density)))})
			doc.generate_mesh(density)
		var mesh: Dictionary=doc.data.mesh
		var area: float=0.5*(16*density)*0.0075*sin(TAU/(16*density))
		check(absf(mesh.quality.total_volume-area*0.1)<1e-12,"Polygon reference volume")
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
		var top: Array=mesh.regions[doc.data.parts[0].id].OutletEnd
		var u:=0.0
		for id in top:
			for j in 3: u+=result.displacement[id][j]*axis[j]/top.size()
		var reaction:=0.0
		for vector in result.reactions:
			for j in 3: reaction+=vector[j]*axis[j]
		var error: float=absf(u/(0.1/(1000*PI*0.0075))-1)
		check(absf(u/(0.1/(1000*area))-1)<1e-5,"Axial displacement vs exact polygon rod nu=0")
		check(absf(reaction+1)<1e-6,"Applied force / reaction balance")
		check(error<previous_error,"Circle displacement convergence")
		previous_error=error
		var stress_error:=0.0
		for stress in result.stress:
			var projected: float=axis[0]*axis[0]*stress[0]+axis[1]*axis[1]*stress[1]+axis[2]*axis[2]*stress[2]+2*axis[0]*axis[1]*stress[3]+2*axis[1]*axis[2]*stress[4]+2*axis[0]*axis[2]*stress[5]
			stress_error=maxf(stress_error,absf(projected-1/area))
		check(stress_error<1e-5,"Axial stress reference")
		var structural_residual: float=result.relative_residual
		var structural_solve_ms=result.get("solve_ms")
		var topology=load("res://tests/pipe_topology_fixture.gd").new()
		topology.verify(mesh,part.id)
		var repeat: Dictionary=load("res://core/cae/pipe_mesher.gd").generate(doc.data,density).mesh
		for key in ["nodes","elements","regions","surface_regions"]:check(mesh[key]==repeat[key],"Determinism")
		var areas: Dictionary={};var quality: Array=[]
		for cell in mesh.elements: quality.append(Display.quality(mesh,cell).mean_ratio)
		quality.sort()
		var arithmetic=load("res://core/cae/extreme_jobs.gd").new()
		for name in mesh.surface_regions[part.id]:
			areas[name]=0.0
			for face in mesh.surface_regions[part.id][name]:
				var p: Array=mesh.nodes[face[0]]
				var normal: Array=arithmetic.cross64(Mesher.sub(mesh.nodes[face[1]],p),Mesher.sub(mesh.nodes[face[2]],p))
				areas[name]+=sqrt(arithmetic.dot64(normal,normal))/2
				var delta: Array=Mesher.sub(p,part.position)
				var axial: float=arithmetic.dot64(delta,axis)
				var radial: Array=[]
				for j in 3:radial.append(delta[j]-axial*axis[j])
				var signed: float=arithmetic.dot64(normal,radial) if name in ["InnerWall","OuterWall"] else arithmetic.dot64(normal,axis)
				check(signed<0 if name in ["InnerWall","InletEnd"] else signed>0,"Material outward normal")
		check(absf(areas.InnerWall/(16*density*2*0.05*sin(PI/(16*density))*0.1)-1)<1e-10,"Inner area")
		check(absf(areas.OuterWall/(16*density*2*0.1*sin(PI/(16*density))*0.1)-1)<1e-10,"Outer area")
		doc.execute("ClearAnalysisConditions",{"index":0})
		doc.execute("SetAnalysis",{"analysis":{"type":"steady_thermal","element":"TET4"}})
		for name in ["InnerWall","OuterWall"]:
			doc.execute("ApplyThermalBoundary",{"index":0,"boundary":{"face":name,"kind":"temperature","value":400.0 if name=="InnerWall" else 300.0}})
		for name in ["InletEnd","OutletEnd"]:doc.execute("ApplyThermalBoundary",{"index":0,"boundary":{"face":name,"kind":"flux","value":0.0}})
		doc.generate_mesh(density)
		directory=manager.launch(doc,1,256)
		check(not directory.is_empty(),manager.last_error)
		deadline=Time.get_ticks_msec()+15000
		while manager.load_result(directory).is_empty() and Time.get_ticks_msec()<deadline:await process_frame
		imported=manager.load_result(directory,doc.data);check(not imported.is_empty(),manager.last_error)
		if imported.is_empty():quit(1);return
		result=imported.results
		var temperature_error:=0.0;var heat:=0.0;var balance:=0.0
		for id in mesh.nodes.size():
			var delta: Array=Mesher.sub(mesh.nodes[id],part.position)
			var axial: float=arithmetic.dot64(delta,axis)
			var radius:=sqrt(maxf(0,arithmetic.dot64(delta,delta)-axial*axial))
			temperature_error=maxf(temperature_error,absf(result.temperature[id]-(300+100*log(0.1/radius)/log(2.0))))
			balance+=result.heat_reactions[id]
		for id in mesh.regions[part.id].InnerWall:heat+=result.heat_reactions[id]
		var expected:=2*PI*10*0.1*100/log(2.0)
		var heat_error:=absf(absf(heat)/expected-1)
		check(heat_error<previous_heat_error,"Radial heat convergence");previous_heat_error=heat_error
		check(heat>0,"Inner heat enters material")
		check(absf(balance)<1e-6,"Thermal energy balance")
		var flux_error:=0.0;var flux_reference:=0.0
		for e in mesh.elements.size():
			var center: Array=[0.0,0.0,0.0]
			for id in mesh.elements[e]:
				for j in 3:center[j]+=(mesh.nodes[id][j]-part.position[j])/4
			var axial: float=arithmetic.dot64(center,axis)
			var radial: Array=[]
			for j in 3:radial.append(center[j]-axial*axis[j])
			check(arithmetic.dot64(result.heat_flux[e],radial)>0,"Outward conductive flux")
			var r2: float=arithmetic.dot64(radial,radial)
			for j in 3:
				var exact: float=1000*radial[j]/(log(2.0)*r2)
				flux_error+=pow(result.heat_flux[e][j]-exact,2);flux_reference+=exact*exact
		rows.append({"structural_stress_max_error_Pa":stress_error,"structural_residual":structural_residual,"structural_native_solve_ms":structural_solve_ms,"thermal_native_solve_ms":result.get("solve_ms"),"centroid_flux_relative_rms":sqrt(flux_error/flux_reference),"density":density,"nodes":mesh.nodes.size(),"elements":mesh.elements.size(),"volume_relative_error":absf(mesh.quality.total_volume/(PI*0.0075*0.1)-1),"areas":areas,"mean_ratio_min":quality[0],"mean_ratio_median":quality[quality.size()/2],"displacement_m":u,"reaction_N":reaction,"temperature_max_error_K":temperature_error,"heat_inner_W":heat,"heat_relative_error":absf(absf(heat)/expected-1),"energy_balance_W":balance,"residual":result.relative_residual,"generation_ms":mesh.quality.generation_ms})

	var file=FileAccess.open("res://docs/workbench-2/stage6-pipe-numerical.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures":failures,"cases":rows},"  "))
	print("Pipe failures=",failures)
	quit(0 if failures==0 else 1)
