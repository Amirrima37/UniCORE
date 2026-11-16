extends SceneTree
var OUT=preload("res://tests/development_paths.gd").output("CAD/step-final")
func _initialize():
	var rows=[]
	var bridge=load("res://core/cae/calculix_workbench.gd").new()
	for fixture in ["bar","cylinder"]:
		var document=load("res://core/cae/cae_document.gd").new()
		var bytes=FileAccess.get_file_as_bytes("res://tests/fixtures/step/"+fixture+".step")
		var error=document.execute("ImportSTEP",{"cad_base64":Marshalls.raw_to_base64(bytes),"cad_sha256":document.cad_sha256(bytes),"name":fixture+".step"})
		if not error.is_empty():push_error(error);quit(1);return
		var p=document.data.parts[0]
		var preview=bridge.preview_step(document.data)
		if preview.has("error"):push_error(preview.error);quit(1);return
		p.cad_faces=preview.face_areas.keys();p.cad_face_areas=preview.face_areas;p.cad_face_centers=preview.face_centers
		var low=INF;var high=-INF
		for face in p.cad_faces:
			var y=float(preview.face_centers[face][1])
			if y<low:low=y;p.support=face
			if y>high:high=y;p.load_face=face
		for bending in ([false,true] if fixture=="bar" else [false]):
			p.material.E=210e9;p.material.nu=0.3 if bending else 0.0
			p.force=[1000.0,0.0,0.0] if bending else [0.0,1000.0,0.0]
			for size in ([0.07,0.05,0.03333333333333333] if fixture=="bar" else [0.06,0.04,0.025]):
				document.data.mesh=bridge.generate_mesh(document.data,size)
				if document.data.mesh.has("error"):push_error(document.data.mesh.error);quit(1);return
				var start=Time.get_ticks_msec()
				var r=bridge.solve_model(document.data)
				var seconds=(Time.get_ticks_msec()-start)/1000.0
				if not r.ok:push_error(r.error);quit(1);return
				var tip=0.0;var reaction=[0.0,0.0,0.0];var minimum_quality=INF
				for id in document.data.mesh.groups[p.id][p.load_face]:tip+=r.displacement[id][0 if bending else 1]
				tip=absf(tip/document.data.mesh.groups[p.id][p.load_face].size())
				for force in r.reactions:
					for axis in 3:reaction[axis]+=force[axis]
				# Dimensionless tetrahedron mean ratio: 12*(3V)^(2/3)/sum(edge length squared).
				for cell in r.elements:
					var points=[]
					for id in cell:
						var xyz=r.nodes[id];points.append(Vector3(xyz[0],xyz[1],xyz[2]))
					var det=absf((points[1]-points[0]).dot((points[2]-points[0]).cross(points[3]-points[0])))
					var edges=0.0
					for i in 4:
						for j in range(i+1,4):edges+=points[i].distance_squared_to(points[j])
					minimum_quality=minf(minimum_quality,12*pow(det/2,2.0/3)/edges)
				var length=1.0 if fixture=="bar" else 0.2
				var area=0.01 if fixture=="bar" else PI*0.1*0.1
				var reference=1000*pow(length,3)/(3*210e9*(pow(0.1,4)/12)) if bending else 1000*length/(210e9*area)
				var imbalance=Vector3(reaction[0]+p.force[0],reaction[1]+p.force[1],reaction[2]+p.force[2]).length()/1000
				rows.append({"fixture":fixture,"bending":bending,"size_m":size,"nodes":r.nodes.size(),"tet4":r.elements.size(),"minimum_mean_ratio":minimum_quality,"minimum_jacobian":document.data.mesh.quality.minimum_jacobian,"tip_mean_m":tip,"maximum_displacement_m":r.max_displacement,"reference_m":reference,"relative_error":absf(tip/reference-1),"reactions_N":reaction,"reaction_relative_imbalance":imbalance,"wall_solve_s":seconds,"maximum_von_mises_Pa":r.von_mises.max(),"job":ProjectSettings.globalize_path(bridge.directory),"provenance":r.provenance,"mesh_provenance":document.data.mesh.provenance,"cad_bounds_m":preview.bounds,"support":p.support,"load_face":p.load_face,"support_area_m2":preview.face_areas[p.support],"load_area_m2":preview.face_areas[p.load_face],"E_Pa":p.material.E,"nu":p.material.nu,"total_force_N":p.force.duplicate()})
				var f=FileAccess.open(OUT+"/numerical.json",FileAccess.WRITE);f.store_string(JSON.stringify(rows,"  ",true,true));f.close()
				print("STEP_NUMERICAL ",fixture," bending=",bending," size=",size," error=",absf(tip/reference-1)," equilibrium=",imbalance)
	print("STEP_FINAL_NUMERICAL_PASS")
	quit()
