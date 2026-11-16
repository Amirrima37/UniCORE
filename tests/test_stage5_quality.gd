extends SceneTree
func _initialize():
	var doc=load("res://core/cae/cae_document.gd").new()
	doc.execute("CreatePart",{"kind":"Cylinder","parameters":{"length":0.4,"diameter":0.2}})
	assert(doc.generate_mesh(4).is_empty())
	var mesh: Dictionary=doc.data.mesh
	var rows:=[]
	var arithmetic=load("res://core/cae/extreme_jobs.gd").new()
	var counts={"scaled_only":0,"edge_only":0,"both":0,"invalid":0}
	var metrics={"scaled_jacobian":[],"edge_ratio":[],"volume_m3":[]}
	for i in mesh.elements.size():
		var q: Dictionary=load("res://core/cae/mesh_display.gd").quality(mesh,mesh.elements[i])
		var ids: Array=mesh.elements[i]
		var a: Array=arithmetic.sub64(mesh.nodes[ids[1]],mesh.nodes[ids[0]])
		var b: Array=arithmetic.sub64(mesh.nodes[ids[2]],mesh.nodes[ids[0]])
		var c: Array=arithmetic.sub64(mesh.nodes[ids[3]],mesh.nodes[ids[0]])
		var det: float=arithmetic.dot64(a,arithmetic.cross64(b,c))
		assert(abs(q.volume-det/6)<1e-11)
		var scaled64: float=det/sqrt(arithmetic.dot64(a,a)*arithmetic.dot64(b,b)*arithmetic.dot64(c,c))
		assert(abs(q.scaled_jacobian-scaled64)<1e-6)
		var scaled: bool=q.scaled_jacobian<0.2
		var edge: bool=q.aspect_ratio>5
		if scaled and edge:counts.both+=1
		elif scaled:counts.scaled_only+=1
		elif edge:counts.edge_only+=1
		counts.invalid+=int(q.invalid or q.degenerate or q.inverted)
		metrics.scaled_jacobian.append(q.scaled_jacobian)
		metrics.edge_ratio.append(q.aspect_ratio)
		metrics.volume_m3.append(q.volume)
		rows.append({"id":i,"nodes":mesh.elements[i],"scaled_jacobian":q.scaled_jacobian,"edge_ratio":q.aspect_ratio,"volume_m3":q.volume})
	var distributions:={}
	for key in metrics:
		var values: Array=metrics[key];values.sort()
		distributions[key]={"min":values[0],"p25":values[int(values.size()*0.25)],"median":values[int(values.size()*0.5)],"p75":values[int(values.size()*0.75)],"max":values[-1]}
	rows.sort_custom(func(a,b):return a.scaled_jacobian<b.scaled_jacobian)
	var report={"nodes":mesh.nodes.size(),"elements":rows.size(),"criteria_counts":counts,"distributions":distributions,"worst_scaled":rows.slice(0,10)}
	var file=FileAccess.open("res://docs/workbench-2/stage6-cylinder-quality.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	assert(mesh.nodes.size()<=2000 and counts.invalid==0)
	assert(counts.edge_only+counts.both < rows.size()/10)
	quit()
