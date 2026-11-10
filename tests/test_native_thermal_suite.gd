extends SceneTree
var failures:=0
func check(ok: bool,message: String):
	if not ok: failures+=1; push_error(message)
func _initialize():
	create_timer(30).timeout.connect(func(): quit(2))
	GDExtensionManager.load_extension("res://bin/unicore_native.gdextension")
	check(ClassDB.class_exists("UniCoreThermalSolver"),"Thermal class registered")
	if failures: quit(1); return
	var solver=ClassDB.instantiate("UniCoreThermalSolver")
	var mesher=ClassDB.instantiate("UniCoreStructuralSolver")
	var doc=load("res://core/cae/cae_document.gd").new()
	doc.execute("CreatePart")
	doc.data.parts[0].dimensions=[1,1,1]
	doc.data.parts[0].material={"name":"Analytical conductivity","k":10,"density":2,"cp":5}
	doc.data.parts[0].thermal=[{"kind":"temperature","face":"X-","value":300},{"kind":"temperature","face":"X+","value":400}]
	doc.data.analysis={"type":"steady_thermal"}
	doc.data.mesh=mesher.generate_mesh(doc.data,4).mesh
	var result: Dictionary=solver.solve_model(doc.data)
	check(result.get("ok",false),"Steady thermal solve: "+str(result.get("error","")))
	if not result.get("ok",false): quit(1); return
	var error:=0.0
	for i in result.nodes.size(): error=maxf(error,abs(result.temperature[i]-(350+100*result.nodes[i][0])))
	print("Conduction linear profile maximum error K: ",error," heat balance W: ",result.energy_balance_W)
	check(error<1e-6,"Exact one-dimensional linear temperature")
	for q in result.heat_flux: check(abs(q[0]+1000)<1e-5 and abs(q[1])+abs(q[2])<1e-5,"Exact Fourier flux")
	check(abs(result.energy_balance_W)<1e-5,"Steady energy balance")
	doc.data.parts[0].thermal=[{"kind":"temperature","face":"X-","value":300},{"kind":"convection","face":"X+","h":10,"ambient":400}]
	result=solver.solve_model(doc.data)
	check(result.get("ok",false) and abs(result.max_temperature-350)<1e-5,"Conduction-convection series resistance")
	doc.data.parts[0].thermal=[{"kind":"temperature","face":"X-","value":300},{"kind":"flux","face":"X+","value":100}]
	result=solver.solve_model(doc.data)
	check(result.get("ok",false) and abs(result.max_temperature-310)<1e-5,"Inward flux sign and magnitude")
	doc.data.parts[0].thermal=[]
	check(not solver.solve_model(doc.data).get("ok",true),"Unanchored steady thermal rejected")
	doc.data.analysis={"type":"transient_thermal","time_step":.1,"steps":10,"initial_temperature":300}
	doc.data.parts[0].heat_source=20
	result=solver.solve_model(doc.data)
	check(result.get("ok",false),"Transient insulated heat source")
	if result.get("ok",false):
		check(abs(result.min_temperature-302)<1e-6 and abs(result.max_temperature-302)<1e-6,"Uniform heating dT=Q*t/(rho*cp)")
		check(abs(result.energy_balance_W)<1e-5,"Transient energy conservation")
		check(result.times.size()>1,"Time-history fields returned")
	# Nonuniform transient field against the Fourier-series slab solution.
	doc.data.parts[0].material={"name":"Unit diffusivity benchmark","k":1,"density":1,"cp":1}
	doc.data.parts[0].heat_source=0
	doc.data.parts[0].thermal=[{"kind":"temperature","face":"X-","value":300},{"kind":"temperature","face":"X+","value":300}]
	doc.data.analysis={"type":"transient_thermal","time_step":.001,"steps":50,"initial_temperature":400}
	doc.data.mesh=mesher.generate_mesh(doc.data,8).mesh
	result=solver.solve_model(doc.data)
	check(result.get("ok",false),"Transient nonuniform slab solve")
	if result.get("ok",false):
		var expected:=300.0
		for mode in range(1,60,2): expected+=100*4/PI*sin(mode*PI*.5)/mode*exp(-mode*mode*PI*PI*.05)
		var midpoint:=4+9*4+81*4
		var slab_error: float=abs(result.temperature[midpoint]-expected)
		print("Transient slab midpoint error K: ",slab_error," Fourier reference K: ",expected)
		check(slab_error<1.5,"Transient slab within 1.5 K (1.5 percent initial excess)")
		check(abs(result.energy_balance_W)<1e-4,"Transient nonuniform slab energy balance")
	solver.cancel()
	check(solver.solve_model(doc.data).get("error")=="CANCELLED","Thermal cancellation")
	solver.reset_cancel()
	check(solver.solve_model(doc.data).get("ok",false),"Thermal recovery")
	print("Thermal analytical suite: ",failures," failures")
	quit(1 if failures else 0)
