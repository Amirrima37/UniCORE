extends SceneTree
func _initialize():
	var rows=[]
	var bridge=load("res://core/cae/calculix_workbench.gd").new()
	for resolution in [2,3,4]:
		for bending in [false,true]:
			var p={"id":"bar","kind":"Box","dimensions":[1.0,0.1,0.1],"position":[0,0,0],"rotation":[0,0,0],"scale":[1,1,1],"material":{"E":210e9,"nu":0.3 if bending else 0.0},"support":"X-","load_face":"X+","force":[0,-1000,0] if bending else [1000,0,0]}
			var data={"schema":1,"revision":0,"parts":[p],"analysis":{"type":"static_structural","backend":"calculix"}}
			data.mesh=bridge.generate_mesh(data,0.1/resolution)
			if data.mesh.has("error"):push_error(data.mesh.error);quit(1);return
			var r=bridge.solve_model(data)
			if not r.ok:push_error(r.error);quit(1);return
			var value=0.0
			for id in data.mesh.groups.bar["X+"]:value+=r.displacement[id][1 if bending else 0]
			value=absf(value/data.mesh.groups.bar["X+"].size())
			var reference=1000.0/(3*210e9*(0.1*pow(0.1,3)/12)) if bending else 1000.0/(210e9*0.01)
			var error=absf(value/reference-1)
			rows.append({"bending":bending,"resolution":resolution,"nodes":r.nodes.size(),"elements":r.elements.size(),"tip_mean_m":value,"reference_m":reference,"relative_error":error,"job":bridge.directory})
			if not bending and error>1e-5:push_error("Axial benchmark mismatch");quit(1);return
	var f=FileAccess.open(preload("res://tests/development_paths.gd").godot_environment("gmsh-benchmarks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(rows,"  "));f.close()
	print("CALCULIX_GMSH_BENCHMARKS "+JSON.stringify(rows))
	quit()

