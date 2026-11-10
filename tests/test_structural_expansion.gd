extends SceneTree
var failures:=0
func check(ok: bool,message: String):
	if not ok: failures+=1; push_error(message)
func _initialize():
	create_timer(60).timeout.connect(func(): quit(2))
	GDExtensionManager.load_extension("res://bin/unicore_native.gdextension")
	var solver=ClassDB.instantiate("UniCoreStructuralSolver")
	var doc=load("res://core/cae/cae_document.gd").new()
	doc.execute("CreatePart")
	doc.execute("SetDimensions",{"index":0,"values":[1,1,1]})
	doc.execute("AssignMaterial",{"index":0,"material":{"name":"Patch","E":1000,"nu":0,"density":2}})
	doc.execute("ApplySupport",{"index":0,"face":"X-"})
	doc.execute("ApplyLoad",{"index":0,"face":"X+","force":[100,0,0]})
	doc.data.analysis={"type":"static_structural","element":"HEX8"}
	doc.data.mesh=solver.generate_mesh(doc.data,2).mesh
	var r: Dictionary=solver.solve_model(doc.data)
	check(r.get("ok",false),"HEX8 solve: "+str(r.get("error","")))
	if not r.get("ok",false): quit(1); return
	print("HEX8 axial relative displacement error: ",abs(r.max_displacement-.1)/.1)
	check(abs(r.max_displacement-.1)<1e-8,"HEX8 exact axial patch")
	check(r.mesh_quality.minimum_jacobian>0 and r.elements.size()==8,"Positive Jacobians and HEX8 count")
	doc.data.parts[0].rotation=[0,0,PI/2]
	doc.data.parts[0].force=[0,100,0]
	var rotated: Dictionary=solver.solve_model(doc.data)
	check(rotated.get("ok",false) and abs(rotated.get("max_displacement",0)-.1)<1e-7,"Rotation invariance with transformed force")
	doc.data.parts[0].scale=[2,1,1]
	var scaled: Dictionary=solver.solve_model(doc.data)
	check(scaled.get("ok",false) and abs(scaled.get("max_displacement",0)-.2)<1e-7,"Physical scale changes length/stiffness")
	doc.data.parts[0].rotation=[0,0,0]
	doc.data.parts[0].scale=[1,1,1]
	doc.data.parts[0].load_face=""
	doc.data.parts[0].pressure={"face":"X+","value":100}
	var pressured: Dictionary=solver.solve_model(doc.data)
	check(pressured.get("ok",false) and abs(pressured.get("max_displacement",0)-.1)<1e-7,"Pressure converts to consistent inward traction")
	if pressured.get("ok",false):
		check(pressured.displacement.back()[0]<0,"Positive pressure pushes X+ face inward")
	doc.data.parts[0].erase("pressure")
	doc.data.parts[0].prescribed={"face":"X+","values":[.01,0,0]}
	var prescribed: Dictionary=solver.solve_model(doc.data)
	check(prescribed.get("ok",false) and abs(prescribed.get("max_displacement",0)-.01)<1e-8,"Nonzero prescribed displacements")
	doc.data.parts[0].erase("prescribed")
	doc.data.parts[0].gravity=[0,-9.81,0]
	var gravity: Dictionary=solver.solve_model(doc.data)
	var reaction:=Vector3.ZERO
	if gravity.get("ok",false):
		for v in gravity.reactions: reaction+=Vector3(v[0],v[1],v[2])
	check(gravity.get("ok",false) and abs(reaction.y-19.62)<1e-6,"Gravity force/reaction balance")
	doc.data.parts[0].erase("gravity")
	doc.data.parts[0].dimensions=[1,.2,.2]
	doc.data.parts[0].material={"E":210e9,"nu":.3,"density":7850,"name":"Benchmark"}
	doc.data.parts[0].load_face="X+"
	doc.data.parts[0].force=[0,-1000,0]
	var reference:=1000.0/(3*210e9*(.2*pow(.2,3)/12))
	for n in [2,4,8,16]:
		doc.data.mesh=solver.generate_mesh(doc.data,n).mesh
		var bending: Dictionary=solver.solve_model(doc.data)
		check(bending.get("ok",false),"HEX8 bending solve")
		if bending.get("ok",false): print("HEX8 beam n=",n," u=",bending.max_displacement," relative beam error=",abs(bending.max_displacement/reference-1))
		if n==16 and bending.get("ok",false): check(abs(bending.max_displacement/reference-1)<.03,"16-division cantilever within 3 percent beam-reference tolerance")
	print("Expanded structural checks: ",failures," failures")
	quit(1 if failures else 0)

