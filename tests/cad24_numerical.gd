extends SceneTree
var OUT=preload("res://tests/development_paths.gd").output("CAD/cad24-completion")
var rows=[]
func fail(message: String):push_error(message);quit(1)
func _initialize():
	var bridge=preload("res://core/cae/calculix_workbench.gd").new()
	for name in ["overlap","through-hole","step-scaled"]:
		for order in [1,2]:
			var d=preload("res://core/cae/cae_document.gd").new()
			var error=d.open_project(OUT+"/"+name+".json")
			if not error.is_empty():fail(error);return
			# Historical face names predate D. Exercise deliberate native review,
			# then explicitly assign the intended planar ends through document commands.
			var reviewed=preload("res://core/cae/cad_geometry_job.gd").new().evaluate({"action":"review_faces","part":d.data.parts[0]})
			if not reviewed.get("ok",false):fail(str(reviewed));return
			error=d.execute("RefreshCADFaces",{"index":0,"metadata":reviewed.metadata})
			if not error.is_empty():fail(error);return
			var p=d.data.parts[0];var low=INF;var high=-INF
			for face in p.cad_faces:
				if not p.cad_definition_faces[face].has("plane_outward_normal"):continue
				var y=float(p.cad_face_centers[face][1])
				if y<low:low=y;p.support=face
				if y>high:high=y;p.load_face=face
			p.force=[0,1000,0];p.material.nu=0.0
			var support=p.support;var load_face=p.load_face
			var support_error=d.execute("ApplySupport",{"index":0,"face":support})
			var load_error=d.execute("ApplyLoad",{"index":0,"face":load_face,"force":[0,1000,0]})
			if not support_error.is_empty() or not load_error.is_empty():fail(support_error+load_error);return
			p=d.data.parts[0]
			p.mesh_settings=preload("res://core/cae/mesh_config.gd").defaults(.09 if name=="step-scaled" else .035)
			p.mesh_settings.schema=2;p.mesh_settings.order=order
			if name=="through-hole":
				p.mesh_settings.curvature_points=24;p.mesh_settings.min_size=.002;p.mesh_settings.target_size=.015
			d.data.analysis.element="TET10" if order==2 else "TET4"
			var snapshot=d.data.duplicate(true);var worker=Thread.new();worker.start(func():return bridge.generate_mesh(snapshot,p.mesh_settings.target_size))
			var frames=0
			while worker.is_alive():frames+=1;await process_frame
			var mesh=worker.wait_to_finish()
			if mesh.has("error"):fail(mesh.error);return
			d.data.mesh=mesh;snapshot=d.data.duplicate(true)
			var unresolved=snapshot.duplicate(true);unresolved.parts[0].cad_pending_boundaries={"support":true}
			var blocked=bridge.solve_model(unresolved)
			if blocked.get("ok",false) or not "reassignment" in blocked.get("error",""):fail("Unreviewed boundary reached the solver path");return
			worker=Thread.new();worker.start(func():return bridge.solve_model(snapshot))
			while worker.is_alive():frames+=1;await process_frame
			var result=worker.wait_to_finish()
			if not result.get("ok",false):fail(result.get("error","Solve failed"));return
			var reaction=Vector3.ZERO;var moment=Vector3.ZERO
			for i in result.reactions.size():
				var r=result.reactions[i];var rf=Vector3(r[0],r[1],r[2]);reaction+=rf
				var xyz=mesh.nodes[i];moment+=Vector3(xyz[0],xyz[1],xyz[2]).cross(rf)
			var imbalance=(reaction+Vector3(0,1000,0)).length()/1000
			if imbalance>1e-4:fail("Reaction imbalance");return
			var tip=0.0
			for i in mesh.groups[p.id][p.load_face]:tip+=result.displacement[i][1]
			tip/=mesh.groups[p.id][p.load_face].size()
			var reference=1000*(high-low)/(210e9*p.cad_face_areas[p.load_face])
			if name!="through-hole" and absf(tip/reference-1)>1e-4:fail("Axial analytic displacement mismatch");return
			result.model_parts=d.data.parts.duplicate(true);result.model_analysis=d.data.analysis.duplicate(true);result.source_mesh_sha256=preload("res://core/cae/mesh_fingerprint.gd").fingerprint(mesh);result.mesh_fingerprint_version=2;d.data.results=result
			var path=OUT+"/"+name+"-tet"+str(order)+".ucae"
			if d.save_project(path)!=OK or not d.open_project(path).is_empty():fail("Save/reopen failed");return
			rows.append({"case":name,"order":order,"tip_m":tip,"analytic_reference_m":reference,"reaction_relative_imbalance":imbalance,"reaction_moment_Nm":[moment.x,moment.y,moment.z],"solver_job":bridge.directory,"heartbeat_frames":frames,"completion":result.completion})
			var f=FileAccess.open(OUT+"/structural-numerical.json",FileAccess.WRITE);f.store_string(JSON.stringify(rows,"  "));f.close()
	print("CAD24_NUMERICAL_PASS");quit()
