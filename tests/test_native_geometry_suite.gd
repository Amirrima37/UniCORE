extends SceneTree
var failures:=0
func check(ok: bool,message: String):
	if not ok:
		failures+=1
		push_error(message)
func _initialize():
	GDExtensionManager.load_extension("res://bin/unicore_native.gdextension")
	check(ClassDB.class_exists("UniCoreGeometryTools"),"Native geometry tools registered")
	if failures: quit(1); return
	var tools=ClassDB.instantiate("UniCoreGeometryTools")
	var part={"kind":"Box","dimensions":[2,3,4],"material":{"density":2}}
	var result: Dictionary=tools.measure_primitive(part)
	check(result.ok and abs(result.volume_m3-24)<1e-12,"Integer inputs bridge accurately")
	check(result.mass_kg==48 and result.local_inertia_kg_m2==[100.0,80.0,52.0],"Native box mass/inertia")
	part.kind="Pipe"
	part.inner_diameter=1
	check(abs(tools.measure_primitive(part).volume_m3-2.25*PI)<1e-12,"Native pipe volume")
	part.inner_diameter=3
	check(not tools.measure_primitive(part).ok,"Invalid wall rejected by C++")
	part.kind="Sphere"
	part.scale=[2,1,1]
	check(not tools.measure_primitive(part).ok,"Unsupported nonuniform scale rejected")
	part.kind="Box"
	part.scale=[2,1,1]
	check(abs(tools.measure_primitive(part).volume_m3-48)<1e-12,"Scaled box measurement")
	var doc=load("res://core/cae/cae_document.gd").new()
	doc.execute("CreatePart")
	doc.execute("SetRotation",{"index":0,"values":[0,.1,0]})
	check(ClassDB.instantiate("UniCoreStructuralSolver").generate_mesh(doc.data,2).ok,"Native mesher accepts validated rotated geometry")
	print("Native primitive geometry bridge: ",failures," failures")
	quit(1 if failures else 0)
