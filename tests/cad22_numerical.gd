extends SceneTree
var OUT=preload("res://tests/development_paths.gd").output("CAD/cad22")
const Config=preload("res://core/cae/mesh_config.gd")
var rows=[]
func fail(message: String):push_error(message);quit(1)
func _initialize():
	var bridge=load("res://core/cae/calculix_workbench.gd").new()
	for name in ["axial-bar","axial-cylinder","bending","step-hole"]:
		var document=load("res://core/cae/cae_document.gd").new()
		if name=="step-hole":
			var error=document.open_project("res://docs/architecture/evidence/cad21/step-cut.json")
			if not error.is_empty():fail(error);return
		else:
			var fixture="cylinder" if name=="axial-cylinder" else "bar"
			var bytes=FileAccess.get_file_as_bytes("res://tests/fixtures/step/"+fixture+".step")
			var error=document.execute("ImportSTEP",{"cad_base64":Marshalls.raw_to_base64(bytes),"cad_sha256":document.cad_sha256(bytes),"name":fixture+".step"})
			if not error.is_empty():fail(error);return
			var snapshot=document.data.duplicate(true);var preview_worker=Thread.new();preview_worker.start(func():return bridge.preview_step(snapshot))
			while preview_worker.is_alive():await process_frame
			var preview=preview_worker.wait_to_finish()
			if preview.has("error"):fail(preview.error);return
			var part=document.data.parts[0];part.cad_faces=preview.face_areas.keys();part.cad_face_areas=preview.face_areas;part.cad_face_centers=preview.face_centers
		var p=document.data.parts[0];var low=INF;var high=-INF
		for face in p.cad_faces:
			var y=float(p.cad_face_centers[face][1])
			if y<low:low=y;p.support=face
			if y>high:high=y;p.load_face=face
		p.material.E=210e9;p.material.nu=0.3 if name=="bending" else 0.0;p.force=[1000,0,0] if name=="bending" else [0,1000,0]
		document.data.analysis={"type":"static_structural","backend":"calculix","element":"TET4"}
		for level in 4:
			var size=[.07,.05,.03333333333333333,.02222222222222222][level]
			var config=Config.defaults(size)
			if name=="axial-cylinder":config.curvature_points=[0,12,18,24][level]
			if name=="step-hole":
				config=Config.defaults(.05);config.min_size=.002;config.boundary_extension=false;config.curvature_points=[8,12,18,24][level]
				if level>0:
					var hole=""
					for key in p.cad_faces:
						if p.cad_face_descriptors[key].type=="Cylinder":hole=key
					config.local=[{"id":"hole-refinement","face":hole,"enabled":true,"needs_review":false,"mode":"distance","size":[.02,.015,.008,.005][level],"dist_min":.003,"dist_max":.025}]
			p.mesh_settings=config
			var snapshot=document.data.duplicate(true);var worker=Thread.new();worker.start(func():return bridge.generate_mesh(snapshot,size))
			while worker.is_alive():await process_frame
			var mesh=worker.wait_to_finish()
			if mesh.has("error"):fail(name+" mesh: "+mesh.error);return
			document.data.mesh=mesh;snapshot=document.data.duplicate(true)
			if not Config.current(document.data):
				print("CONFIG_CURRENT_DIAG settings=",p.mesh_settings==mesh.get("mesh_settings")," validation=",Config.validate(mesh.get("mesh_settings"),[],false))
				for key in p.mesh_settings:
					if p.mesh_settings[key]!=mesh.mesh_settings.get(key):print("SETTING_DIFF ",key," ",p.mesh_settings[key]," / ",mesh.mesh_settings.get(key))
				for key in ["id","kind","dimensions","position","rotation","scale","cad_sha256"]:
					if mesh.geometry_part.get(key)!=p.get(key):print("GEOMETRY_DIFF ",key," ",mesh.geometry_part.get(key)," / ",p.get(key))
			var start=Time.get_ticks_msec();worker=Thread.new();worker.start(func():return bridge.solve_model(snapshot))
			while worker.is_alive():await process_frame
			var result=worker.wait_to_finish();var solve_seconds=(Time.get_ticks_msec()-start)/1000.0
			if not result.get("ok",false):fail(name+" CalculiX: "+result.get("error","unknown"));return
			var tip=0.0
			for id in mesh.groups[p.id][p.load_face]:tip+=result.displacement[id][0 if name=="bending" else 1]
			tip=absf(tip/mesh.groups[p.id][p.load_face].size())
			var length=.2 if name=="axial-cylinder" else 1.0;var area=PI*.1*.1 if name=="axial-cylinder" else .01-PI*.02*.02 if name=="step-hole" else .01
			var reference=1000*pow(length,3)/(3*210e9*(pow(.1,4)/12)) if name=="bending" else 1000*length/(210e9*area)
			var reaction=Vector3.ZERO
			for r in result.reactions:reaction+=Vector3(r[0],r[1],r[2])
			var imbalance=(reaction+Vector3(p.force[0],p.force[1],p.force[2])).length()/1000
			if imbalance>1e-4:fail("Reaction imbalance "+str(imbalance));return
			var stress_id=result.von_mises.find(result.von_mises.max());var center=Vector3.ZERO
			for id in mesh.elements[stress_id]:center+=Vector3(mesh.nodes[id][0],mesh.nodes[id][1],mesh.nodes[id][2])/4
			var quality=mesh.quality.duplicate();quality.erase("per_element")
			rows.append({"case":name,"level":level,"settings":config.duplicate(true),"nodes":mesh.nodes.size(),"tet4":mesh.elements.size(),"quality":quality,"tip_mean_m":tip,"maximum_displacement_m":result.max_displacement,"reference_m":reference,"relative_displacement_error":absf(tip/reference-1),"maximum_von_mises_Pa":result.von_mises.max(),"stress_element":stress_id,"stress_location_m":[center.x,center.y,center.z],"reaction_relative_imbalance":imbalance,"meshing_s":mesh.meshing_seconds,"mesh_wall_s":mesh.completion.seconds,"mesh_peak_commit_bytes":mesh.completion.peak_memory_bytes,"solver_s":solve_seconds,"solver_peak_working_set_bytes":result.completion.get("peak_working_set_bytes",0),"solver_job":ProjectSettings.globalize_path(bridge.directory),"proof":result.provenance,"optimization":mesh.get("optimization",{})})
			var f=FileAccess.open(OUT+"/numerical.json",FileAccess.WRITE);f.store_string(JSON.stringify(rows,"  ",true,true));f.close()
			print("CAD22_NUMERICAL ",name," level=",level," nodes=",mesh.nodes.size()," volume_error=",quality.relative_volume_difference," displacement_error=",absf(tip/reference-1))
			if name=="step-hole" and level==3:
				result.model_parts=document.data.parts.duplicate(true);result.model_analysis=document.data.analysis.duplicate(true);result.source_mesh_sha256=preload("res://core/cae/mesh_fingerprint.gd").fingerprint(mesh);result.mesh_fingerprint_version=2;document.data.results=result
				if document.save_project(OUT+"/refined-hole.ucae")!=OK:fail("Refined project save");return
	print("CAD22_NUMERICAL_PASS");quit()
