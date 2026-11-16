extends SceneTree
var out = OS.get_environment("UNICORE_INTERFERENCE_OUT")
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	if not ok:
		push_error(message)
		quit(1)
		assert(false,message)
func run():
	var rows=[]
	for scenario in ([OS.get_environment("UNICORE_INTERFERENCE_CASE")] if not OS.get_environment("UNICORE_INTERFERENCE_CASE").is_empty() else ["rotated-disjoint","touching","step"]):
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
			if scenario=="rotated-disjoint":
				for k in 2:check(d.execute("SetRotation",{"index":k,"values":[0,0,PI/4]}).is_empty(),"rotate")
				check(d.execute("SetPosition",{"index":1,"values":[0.12/sqrt(2.0),0.12/sqrt(2.0),0]}).is_empty(),"translate")
			elif scenario=="touching":check(d.execute("SetPosition",{"index":1,"values":[0.1,0,0]}).is_empty(),"touch placement")
			for k in 2:
				var p=d.data.parts[k]
				p.mesh_settings=preload("res://core/cae/mesh_config.gd").defaults(0.05)
				p.mesh_settings.schema=2;p.mesh_settings.order=order
				p.force=[-1000/sqrt(2.0),1000/sqrt(2.0),0] if scenario=="rotated-disjoint" else [0,0,0] if scenario=="touching" and k==1 else [0,1000,0]
			for k in 2:
				check(d.execute("ApplySupport",{"index":k,"face":source.support}).is_empty(),"explicit instance support")
				check(d.execute("ApplyLoad",{"index":k,"face":source.load_face,"force":d.data.parts[k].force}).is_empty(),"explicit instance load")
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
				var diagnostic=FileAccess.open(out+"/diagnostic-"+scenario+".json",FileAccess.WRITE);diagnostic.store_string(JSON.stringify({"mesh":mesh.interference,"parts":d.data.parts},"",true,true));diagnostic.close()
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
				check(mesh.interference.pairs[0].classification==("TOUCHING" if scenario=="touching" else "SEPARATED"),"wrong classification")
				for k in 2:
					var p=d.data.parts[k];var direction=Vector3(-1/sqrt(2.0),1/sqrt(2.0),0) if scenario=="rotated-disjoint" else Vector3.UP
					var tip=0.0;var reaction=Vector3.ZERO
					for n in mesh.groups[p.id][p.load_face]:
						var u=result.displacement[n];tip+=Vector3(u[0],u[1],u[2]).dot(direction)/mesh.groups[p.id][p.load_face].size()
					for n in range(int(mesh.instances[p.id].node_range[0]),int(mesh.instances[p.id].node_range[1])):
						check(mesh.node_owners[n]==p.id,"node owner")
						var r=result.reactions[n];reaction+=Vector3(r[0],r[1],r[2])
					var length=abs(p.cad_face_centers[p.load_face][1]-p.cad_face_centers[p.support][1])
					var applied=Vector3(p.force[0],p.force[1],p.force[2])
					var expected=applied.length()*length/(p.material.E*p.cad_face_areas[p.load_face])
					var error=abs(tip/expected-1) if expected>0 else abs(tip)
					var imbalance=(reaction+applied).length()/1000
					check(error<0.0001 and imbalance<0.00001,str([scenario,order,error,imbalance]))
					if expected==0:check(abs(tip)<1e-14,"artificial force transfer")
					rows.append({"case":scenario,"order":order,"reopen":reopen,"instance":p.instance_uuid,"error":error,"imbalance":imbalance,"job":ProjectSettings.globalize_path(bridge.directory),"completion":result.completion,"interference":mesh.interference})
				var f=FileAccess.open(out+"/solves-"+scenario+".json",FileAccess.WRITE);f.store_string(JSON.stringify(rows,"  "));f.close()
				print("SOLVE_PASS ",scenario," ",order," reopen=",reopen)
	print("INTERFERENCE_SOLVES_PASS")
	quit()
