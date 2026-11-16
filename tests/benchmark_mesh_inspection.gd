extends SceneTree
func _initialize():
	var doc=load("res://core/cae/cae_document.gd").new()
	doc.execute("CreatePart")
	var camera:=Camera3D.new()
	root.add_child(camera)
	camera.position=Vector3(2,2,3)
	camera.look_at(Vector3.ZERO)
	camera.current=true
	var results:=[]
	for size in [4,8,16]:
		var start:=Time.get_ticks_usec()
		doc.generate_mesh(size)
		var generation:=(Time.get_ticks_usec()-start)/1000.0
		var inspect=load("res://core/cae/mesh_inspection.gd").new()
		var before:=OS.get_static_memory_usage()
		start=Time.get_ticks_usec()
		inspect.prepare(doc.data.mesh)
		inspect.geometry("solid"); inspect.geometry("edges"); inspect.contour("jacobian")
		var preparation:=(Time.get_ticks_usec()-start)/1000.0
		var memory:=OS.get_static_memory_usage()-before
		var times:=[]
		for i in 100:
			start=Time.get_ticks_usec()
			inspect.pick(camera,camera.unproject_position(Vector3.ZERO)+Vector2(i%10,i/10))
			times.append((Time.get_ticks_usec()-start)/1000.0)
		times.sort()
		results.append({"stages":inspect.timings,"nodes":doc.data.mesh.nodes.size(),"elements":doc.data.mesh.elements.size(),"generation_ms":generation,"preparation_ms":preparation,"pick_p95_ms":times[94],"memory_delta_bytes":memory})
	print(JSON.stringify(results))
	var file:=FileAccess.open("res://.tools/mesh-benchmark.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t"))
	quit()
