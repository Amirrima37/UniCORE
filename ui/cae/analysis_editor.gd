extends ConfirmationDialog
signal study_chosen(settings: Dictionary)
signal boundary_chosen(command: String,args: Dictionary)
signal condition_requested(settings: Dictionary,command: String,args: Dictionary)
var settings: Dictionary={}
var surface_names: Array=["X-","X+","Y-","Y+","Z-","Z+"]
var analysis: OptionButton
var element: OptionButton
var boundary: OptionButton
var face: OptionButton
var numbers: Array[SpinBox]=[]
var captions: Array[Label]=[]
var dt: SpinBox
var steps: SpinBox
var initial: SpinBox
var use_material: CheckButton
var help: Label
var expansion_fields := false
var displacement_fields := false
var solver_backend: OptionButton
func _ready():
	title="Analysis and geometric boundary conditions"
	get_ok_button().text="Save study settings"
	var box:=VBoxContainer.new()
	add_child(box)
	var backend := OptionButton.new()
	for entry in preload("res://core/cae/backend_registry.gd").new().discover():
		if entry.status != "missing_dependency":
			backend.add_item(entry.label)
			backend.set_item_metadata(backend.item_count-1,entry.id)
	backend.tooltip_text = "External engines appear only after their adapter is validated. Existing native execution is preserved."
	box.add_child(backend)
	solver_backend=backend
	if FileAccess.file_exists(preload("res://core/cae/calculix_workbench.gd").new().python) and FileAccess.file_exists("res://.tools/engines/gmsh-4.15.2-Windows64-sdk/lib/gmsh-4.15.dll") and FileAccess.get_sha256("res://.tools/engines/calculix/CalculiX-2.23.0-win-x64/bin/ccx.exe")=="27a9426a1ee2f72c38fbe892e0ffaf38e14867628ffd0235770261b6f3ec9c5f":
		backend.add_item("CalculiX 2.23 — Static TET4 (experimental)")
		backend.set_item_metadata(backend.item_count-1,"calculix")
		if settings.get("backend","")=="calculix": backend.select(backend.item_count-1)
	var dependencies := Button.new()
	dependencies.text = "Solver dependency status"
	box.add_child(dependencies)
	dependencies.pressed.connect(func():
		var panel := preload("res://ui/cae/backend_settings.gd").new()
		add_child(panel)
		panel.confirmed.connect(panel.queue_free)
		panel.popup_centered())
	analysis=OptionButton.new()
	for title in ["Static Structural","Steady-State Thermal","Transient Thermal"]: analysis.add_item(title)
	box.add_child(analysis)
	analysis.select(["static_structural","steady_thermal","transient_thermal"].find(settings.get("type","static_structural")))
	element=OptionButton.new()
	element.add_item("TET4 — constant strain")
	element.add_item("HEX8 — full 2×2×2 integration")
	element.add_item("TET10 — CalculiX quadratic")
	element.select(2 if settings.get("element")=="TET10" else 1 if settings.get("element","TET4")=="HEX8" else 0)
	box.add_child(element)
	dt=number(box,"Time step (s)",settings.get("time_step",.1),.000001,1e6,.01)
	steps=number(box,"Steps (1–200)",settings.get("steps",10),1,200,1)
	initial=number(box,"Initial temperature (K)",settings.get("initial_temperature",293.15),0,10000,.01)
	face=OptionButton.new()
	for title in surface_names: face.add_item(title)
	box.add_child(face)
	boundary=OptionButton.new()
	box.add_child(boundary)
	for i in 3:
		var label:=Label.new()
		box.add_child(label)
		captions.append(label)
		numbers.append(number(box,"",0,-1e12,1e12,.001))
	use_material=CheckButton.new();use_material.text="Use material emissivity (must be specified)";box.add_child(use_material)
	var apply:=Button.new()
	apply.text="Apply condition to selected body / face"
	box.add_child(apply)
	help=Label.new()
	help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size.x=470
	box.add_child(help)
	analysis.item_selected.connect(func(_i): populate())
	boundary.item_selected.connect(func(_i): refresh_fields())
	apply.pressed.connect(apply_boundary)
	var clear := Button.new()
	clear.text = "Clear conditions on selected body"
	box.add_child(clear)
	clear.pressed.connect(func(): emit_boundary("ClearAnalysisConditions",{}))
	confirmed.connect(func(): study_chosen.emit(current_settings()))
	populate()
func number(parent: Node,title: String,value: float,low: float,high: float,step: float) -> SpinBox:
	var row:=HBoxContainer.new()
	parent.add_child(row)
	var label:=Label.new()
	label.text=title
	label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var spin:=SpinBox.new()
	spin.custom_minimum_size.x=160
	spin.min_value=low
	spin.max_value=high
	spin.step=step
	spin.value=value
	row.add_child(spin)
	return spin
func current_settings() -> Dictionary:
	var result: Dictionary = {"type":["static_structural","steady_thermal","transient_thermal"][analysis.selected],"element":["TET4","HEX8","TET10"][element.selected],"time_step":dt.value,"steps":int(steps.value),"initial_temperature":initial.value}
	if settings.has("extreme_solver"): result.extreme_solver=settings.extreme_solver.duplicate(true)
	result.backend=solver_backend.get_item_metadata(solver_backend.selected) if solver_backend.selected>=0 else settings.get("backend","extreme_cpu")
	return result
func populate():
	element.visible=analysis.selected==0
	for control in [dt,steps,initial]: control.get_parent().visible=analysis.selected==2
	boundary.clear()
	for title in (["Fixed support","Force","Pressure","Prescribed displacement","Gravity"] + (["Sphere uniform expansion"] if "OuterSurface" in surface_names else []) if analysis.selected==0 else ["Temperature","Heat flux","Convection","Heat source","Radiation"]): boundary.add_item(title)
	refresh_fields()
func refresh_fields():
	var names: Array=[]
	if analysis.selected==0:
		names=[[],["Fx (N)","Fy (N)","Fz (N)"],["Pressure (Pa), positive inward"],["Ux (m)","Uy (m)","Uz (m)"],["gx (m/s²)","gy (m/s²)","gz (m/s²)"],["Uniform expansion strain (dimensionless)"]][boundary.selected]
	else: names=[["Temperature (K)"],["Heat flux (W/m²), positive inward"],["h (W/m²/K)","Ambient temperature (K)"],["Volumetric source (W/m³)"],["Emissivity (0–1)","Surroundings temperature (K)"]][boundary.selected]
	if displacement_fields:
		for spin in numbers:
			spin.allow_greater=false;spin.allow_lesser=false;spin.min_value=-1e12;spin.max_value=1e12;spin.step=0.001
	displacement_fields=analysis.selected==0 and boundary.selected==3
	if displacement_fields:
		for spin in numbers:
			spin.min_value=-1;spin.max_value=1;spin.step=0.000000001;spin.allow_greater=true;spin.allow_lesser=true
	if expansion_fields:
		numbers[0].min_value=-1e12;numbers[0].max_value=1e12;numbers[0].step=0.001
	expansion_fields=analysis.selected==0 and boundary.selected==5
	if expansion_fields:
		numbers[0].min_value=-0.1;numbers[0].max_value=0.1;numbers[0].step=0.000001
	use_material.visible=analysis.selected!=0 and boundary.selected==4
	for i in 3:
		captions[i].text=names[i] if i<names.size() else ""
		numbers[i].get_parent().visible=i<names.size()
	help.text="Global vector components; face IDs remain local to the body. Conditions persist in the document. Multiple bodies are currently disconnected."
func emit_boundary(command: String,args: Dictionary):
	condition_requested.emit(current_settings(),command,args)
	boundary_chosen.emit(command,args)

func apply_boundary():
	var face_name:=face.get_item_text(face.selected)
	var values: Array=[numbers[0].value,numbers[1].value,numbers[2].value]
	if analysis.selected==0:
		match boundary.selected:
			0: emit_boundary("ApplySupport",{"face":face_name})
			1: emit_boundary("ApplyLoad",{"face":face_name,"force":values})
			2: emit_boundary("ApplyPressure",{"face":face_name,"value":values[0]})
			3: emit_boundary("ApplyDisplacement",{"face":face_name,"values":values})
			4: emit_boundary("ApplyGravity",{"values":values})
			5: emit_boundary("ApplySphereExpansion",{"strain":values[0]})
	else:
		match boundary.selected:
			0: emit_boundary("ApplyThermalBoundary",{"boundary":{"face":face_name,"kind":"temperature","value":values[0]}})
			1: emit_boundary("ApplyThermalBoundary",{"boundary":{"face":face_name,"kind":"flux","value":values[0]}})
			2: emit_boundary("ApplyThermalBoundary",{"boundary":{"face":face_name,"kind":"convection","h":values[0],"ambient":values[1]}})
			3: emit_boundary("SetHeatSource",{"value":values[0]})
			4: emit_boundary("ApplyThermalBoundary",{"boundary":{"face":face_name,"kind":"radiation","use_material_emissivity":use_material.button_pressed,"emissivity":values[0],"surroundings":values[1]}})
