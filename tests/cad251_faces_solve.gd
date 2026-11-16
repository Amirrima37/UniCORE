extends SceneTree
var out = OS.get_environment("UNICORE_FACE_OUT")
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	if not ok:
		push_error(message)
		quit(1)
		assert(false,message)
func run():
	var rows=[]
	for scenario in ([OS.get_environment("UNICORE_FACE_CASE")] if not OS.get_environment("UNICORE_FACE_CASE").is_empty() else ["duplicate","translated","rotated","step","touching","reassigned"]):
		for order in [1,2]:
			var d=preload("res://core/cae/cae_document.gd").new()
			var source=JSON.parse_string(FileAccess.get_file_as_string(out+"/source-part.json"))
			if scenario=="step":
				var bytes=FileAccess.get_file_as_bytes("res://tests/fixtures/step/bar.step")
				source.cad_faces=[];source.support="";source.load_face=""
				source.erase("instance_uuid")
				source.cad_base64=Marshalls.raw_to_base64(bytes);source.cad_sha256=d.cad_sha256(bytes);source.cad_format="step"
				var preview=preload("res://core/cae/calculix_workbench.gd").new().preview_step({"parts":[source]})
				check(not preview.has("error"),str(preview))
				source.cad_faces=preview.face_areas.keys();source.cad_face_areas=preview.face_areas;source.cad_face_centers=preview.face_centers
				source.cad_source_units=preview.source_units;source.cad_source_to_m=preview.source_to_m
				source.support="";source.load_face=""
				var lo=INF;var hi=-INF
				for key in source.cad_faces:
					var y=source.cad_face_centers[key][1]
					if y<lo:lo=y;source.support=key
					if y>hi:hi=y;source.load_face=key
				source.dimensions=[0.1,hi-lo,0.1]
			d.data.parts=[source]
			preload("res://core/cae/assembly_model.gd").synchronize(d.data)
			check(d.execute("AddInstance",{"definition_uuid":source.definition_uuid}).is_empty(),"add")
			check(d.execute("SetPosition",{"index":1,"values":[2,0,0]}).is_empty(),"translate")
			for k in 2:
				var p=d.data.parts[k]
				p.mesh_settings=preload("res://core/cae/mesh_config.gd").defaults(0.05)
				p.mesh_settings.schema=2;p.mesh_settings.order=order
				var lower=source.support;var upper=source.load_face
				if scenario=="duplicate" and k==1:
					lower=source.load_face;upper=source.support
				var force=[0,-1500,0] if scenario=="duplicate" and k==1 else [0,0,0] if scenario=="touching" and k==1 else [0,1000 if k==0 else 500,0]
				check(d.execute("ApplySupport",{"index":k,"face":lower}).is_empty(),"explicit support")
				check(d.execute("ApplyLoad",{"index":k,"face":upper,"force":force}).is_empty(),"explicit load")
			if scenario in ["rotated","step"]:
				check(d.execute("SetRotation",{"index":1,"values":[0,0,deg_to_rad(37.0)]}).is_empty(),"nontrivial rotation after assignment")
				check(d.execute("ApplyLoad",{"index":1,"face":d.data.parts[1].load_face,"force":[-500*sin(deg_to_rad(37.0)),500*cos(deg_to_rad(37.0)),0]}).is_empty(),"global rotated axial force")
			if scenario=="touching":check(d.execute("SetPosition",{"index":1,"values":[0.1,0,0]}).is_empty(),"touch placement")
			if scenario=="translated":check(d.execute("SetPosition",{"index":1,"values":[3,0,.3]}).is_empty(),"move assigned faces")
			if scenario=="reassigned":
				var job=preload("res://core/cae/cad_geometry_job.gd").new()
				var reviewed=job.evaluate({"action":"review_faces","part":d.data.parts[0]})
				check(reviewed.get("ok",false),str(reviewed))
				check(d.execute("RefreshCADFaces",{"index":0,"metadata":reviewed.metadata}).is_empty(),"explicit definition review")
				check(d.data.parts[0].boundary_refs.load_face.state=="unresolved","review requires reassignment")
				for k in 2:
					var p=d.data.parts[k];var lo=INF;var hi=-INF;var lower="";var upper=""
					for key in p.cad_faces:
						var y=p.cad_face_centers[key][1]
						if y<lo:lo=y;lower=key
						if y>hi:hi=y;upper=key
					check(d.execute("ApplySupport",{"index":k,"face":lower}).is_empty(),"reassign support")
					check(d.execute("ApplyLoad",{"index":k,"face":upper,"force":p.force}).is_empty(),"reassign load")
			d.data.analysis={"type":"static_structural","backend":"calculix","element":"TET10" if order==2 else "TET4"}
			var bridge=preload("res://core/cae/calculix_workbench.gd").new()
			for reopen in [false,true]:
				if reopen:
					var path=out+"/"+scenario+str(order)+".json"
					check(d.save_project(path)==OK,"save")
					var restored=preload("res://core/cae/cae_document.gd").new()
					var error=restored.open_project(path);check(error.is_empty(),error)
					check(restored.data.parts[1].instance_uuid==d.data.parts[1].instance_uuid,"identity")
					d=restored
				var mesh=bridge.generate_mesh(d.data,0.05);check(not mesh.has("error"),str(mesh.get("error")))

				d.data.mesh=mesh
				var result=bridge.solve_model(d.data);check(result.get("ok",false),str(result))
				var stale=d.data.duplicate(true)
				stale.parts[0].position[0]+=0.01
				check(not bridge.solve_model(stale).get("ok",false),"stale geometry accepted")
				stale=d.data.duplicate(true);stale.parts[0].cad_pending_boundaries={"support":true}
				check(not bridge.solve_model(stale).get("ok",false),"pending boundary accepted")
				d.data.results=result
				d.data.results.model_parts=d.data.parts.duplicate(true)
				d.data.results.model_analysis=d.data.analysis.duplicate(true)
				check(mesh.interference.pairs[0].classification==("TOUCHING" if scenario=="touching" else "SEPARATED"),"interference")
				for k in 2:
					var p=d.data.parts[k];var applied=Vector3(p.force[0],p.force[1],p.force[2])
					var direction=applied.normalized() if applied.length()>0 else Vector3.UP
					var tip=0.0;var reaction=Vector3.ZERO;var reaction_moment=Vector3.ZERO
					for n in mesh.groups[p.id][p.load_face]:
						var u=result.displacement[n];tip+=Vector3(u[0],u[1],u[2]).dot(direction)/mesh.groups[p.id][p.load_face].size()
					for n in range(int(mesh.instances[p.id].node_range[0]),int(mesh.instances[p.id].node_range[1])):
						check(mesh.node_owners[n]==p.id,"instance node owner")
						var r=result.reactions[n];var rf=Vector3(r[0],r[1],r[2]);reaction+=rf
						var xyz=mesh.nodes[n];reaction_moment+=Vector3(xyz[0],xyz[1],xyz[2]).cross(rf)
					var length=abs(p.cad_face_centers[p.load_face][1]-p.cad_face_centers[p.support][1])
					var expected=applied.length()*length/(p.material.E*p.cad_face_areas[p.load_face])
					var error=abs(tip/expected-1) if expected>0 else abs(tip)
					var imbalance=(reaction+applied).length()/1000
					var proof=mesh.part_meshes[p.id].face_resolution
					var c=proof.world_faces[p.load_face].center;var moment=Vector3(c[0],c[1],c[2]).cross(applied)
					var moment_error=(reaction_moment+moment).length()/maxf(1000,moment.length())
					check(error<0.0001 and imbalance<0.00001 and moment_error<0.00001,str([scenario,order,error,imbalance,moment_error]))
					if expected==0:check(abs(tip)<1e-14,"no unintended force transfer")
					rows.append({"case":scenario,"order":order,"reopen":reopen,"instance":p.instance_uuid,"part_id":p.id,"definition":p.definition_uuid,"references":p.boundary_refs,"resolution":proof,"error":error,"imbalance":imbalance,"moment_error":moment_error,"displacement_m":tip,"expected_m":expected,"force_N":p.force,"reaction_N":[reaction.x,reaction.y,reaction.z],"moment_Nm":[moment.x,moment.y,moment.z],"reaction_moment_Nm":[reaction_moment.x,reaction_moment.y,reaction_moment.z],"job":ProjectSettings.globalize_path(bridge.directory),"completion":result.completion})
				var f=FileAccess.open(out+"/solves-"+scenario+".json",FileAccess.WRITE);f.store_string(JSON.stringify(rows,"  "));f.close()
				print("SOLVE_PASS ",scenario," ",order," reopen=",reopen)
	print("FACE_SOLVES_PASS")
	quit()
