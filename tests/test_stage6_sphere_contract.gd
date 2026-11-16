extends SceneTree
const S=preload("res://core/cae/sphere_mesher.gd")
func _initialize():
	var doc=load("res://core/cae/cae_document.gd").new()
	doc.execute("CreatePart",{"kind":"Sphere","parameters":{"radius":0.1}})
	for key in ["position","rotation","scale"]:
		for invalid in [[NAN,1,1],[INF,1,1],[-INF,1,1],[1,2],"invalid"]:
			var changed: Dictionary=doc.data.duplicate(true);changed.parts[0][key]=invalid
			assert(S.generate(changed,1).has("error"))
	for invalid in [[0,0,0],[-1,-1,-1],[1,2,1]]:
		var changed: Dictionary=doc.data.duplicate(true);changed.parts[0].scale=invalid
		assert(S.generate(changed,1).has("error"))
	for radius in [0,-1,NAN,INF,1e-30]:
		var changed: Dictionary=doc.data.duplicate(true);changed.parts[0].dimensions[0]=radius*2
		assert(S.generate(changed,1).has("error"))
	for density in [0,5,8,1000000]: assert(S.generate(doc.data,density).has("error"))
	var changed: Dictionary=doc.data.duplicate(true);changed.parts.append(changed.parts[0].duplicate(true))
	assert(S.generate(changed,1).has("error"))
	doc.execute("SetScale",{"index":0,"values":[2,2,2]})
	doc.execute("SetRotation",{"index":0,"values":[0.3,0.7,-0.4]})
	doc.execute("SetPosition",{"index":0,"values":[1,-2,3]})
	var mesh: Dictionary=S.generate(doc.data,3).mesh
	var groups: Dictionary=mesh.regions[doc.data.parts[0].id]
	var surfaces: Dictionary=mesh.surface_regions[doc.data.parts[0].id]
	for name in groups:
		var resolved: Array=[]
		for face in surfaces.OuterSurface:
			if face.all(func(id):return groups[name].has(id)):resolved.append(face)
		assert(resolved==surfaces[name])
	for id in groups.OuterSurface:
		var point: Array=mesh.nodes[id]
		var length:=sqrt(pow(point[0]-1,2)+pow(point[1]+2,2)+pow(point[2]-3,2))
		assert(absf(length-0.2)<1e-12)
	doc.execute("AssignMaterial",{"index":0,"material":{"name":"Pressure reference","E":1000.0,"nu":0.25,"density":1.0,"k":10.0,"cp":1.0}})
	doc.execute("ApplySupport",{"index":0,"face":"NegativeY"})
	doc.execute("ApplyPressure",{"index":0,"face":"OuterSurface","value":1.0})
	assert(doc.generate_mesh(2).is_empty())
	var jobs=load("res://core/cae/extreme_jobs.gd").new()
	var directory: String=jobs.launch(doc,1,256);assert(not directory.is_empty(),jobs.last_error)
	var deadline:=Time.get_ticks_msec()+15000
	while jobs.status(directory).get("state")!="Completed" and Time.get_ticks_msec()<deadline: await process_frame
	var loaded: Dictionary=jobs.load_result(directory,doc.data);assert(not loaded.is_empty(),jobs.last_error)
	var sum: Array=[0.0,0.0,0.0];var maximum:=0.0
	for value in loaded.results.reactions:
		for j in 3: sum[j]+=value[j]
	for value in loaded.results.displacement:maximum=maxf(maximum,Vector3(value[0],value[1],value[2]).length())
	assert(sqrt(jobs.dot64(sum,sum))<1e-8 and maximum>0 and is_finite(maximum))
	var file=FileAccess.open("res://docs/workbench-2/stage6-sphere-pressure.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"reaction_norm_N":sqrt(jobs.dot64(sum,sum)),"max_displacement_m":maximum,"residual":loaded.results.get("relative_residual")}))
	print("Sphere invalid-input/boundedness/surface resolution/uniform scale/pressure workflow PASS")
	quit()
