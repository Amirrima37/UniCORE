extends ConfirmationDialog
signal study_chosen(settings: Dictionary)
signal boundary_chosen(command: String,args: Dictionary)
var settings: Dictionary={}
var analysis: OptionButton
var element: OptionButton
var boundary: OptionButton
var face: OptionButton
var numbers: Array[SpinBox]=[]
var captions: Array[Label]=[]
var dt: SpinBox
var steps: SpinBox
var initial: SpinBox
var help: Label
func _ready():
	title="Analysis and geometric boundary conditions"
	get_ok_button().text="Save study settings"
	var box:=VBoxContainer.new()
	add_child(box)
	analysis=OptionButton.new()
	for title in ["Static Structural","Steady-State Thermal","Transient Thermal"]: analysis.add_item(title)
	box.add_child(analysis)
	analysis.select(["static_structural","steady_thermal","transient_thermal"].find(settings.get("type","static_structural")))
	element=OptionButton.new()
	element.add_item("TET4 — constant strain")
	element.add_item("HEX8 — full 2×2×2 integration")
	element.select(1 if settings.get("element","TET4")=="HEX8" else 0)
	box.add_child(element)
	dt=number(box,"Time step (s)",settings.get("time_step",.1),.000001,1e6,.01)
	steps=number(box,"Steps (1–200)",settings.get("steps",10),1,200,1)
	initial=number(box,"Initial temperature (K)",settings.get("initial_temperature",293.15),0,10000,.01)
	face=OptionButton.new()
	for title in ["X-","X+","Y-","Y+","Z-","Z+"]: face.add_item(title)
	box.add_child(face)
	boundary=OptionButton.new()
	box.add_child(boundary)
	for i in 3:
		var label:=Label.new()
		box.add_child(label)
		captions.append(label)
		numbers.append(number(box,"",0,-1e12,1e12,.001))
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
	clear.pressed.connect(func(): boundary_chosen.emit("ClearAnalysisConditions",{}))
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
	return {"type":["static_structural","steady_thermal","transient_thermal"][analysis.selected],"element":"HEX8" if element.selected==1 else "TET4","time_step":dt.value,"steps":int(steps.value),"initial_temperature":initial.value}
func populate():
	element.visible=analysis.selected==0
	for control in [dt,steps,initial]: control.get_parent().visible=analysis.selected==2
	boundary.clear()
	for title in (["Fixed support","Force","Pressure","Prescribed displacement","Gravity"] if analysis.selected==0 else ["Temperature","Heat flux","Convection","Heat source"]): boundary.add_item(title)
	refresh_fields()
func refresh_fields():
	var names: Array=[]
	if analysis.selected==0:
		names=[[],["Fx (N)","Fy (N)","Fz (N)"],["Pressure (Pa), positive inward"],["Ux (m)","Uy (m)","Uz (m)"],["gx (m/s²)","gy (m/s²)","gz (m/s²)"]][boundary.selected]
	else: names=[["Temperature (K)"],["Heat flux (W/m²), positive inward"],["h (W/m²/K)","Ambient temperature (K)"],["Volumetric source (W/m³)"]][boundary.selected]
	for i in 3:
		captions[i].text=names[i] if i<names.size() else ""
		numbers[i].get_parent().visible=i<names.size()
	help.text="Global vector components; face IDs remain local to the body. Conditions persist in the document. Multiple bodies are currently disconnected."
func apply_boundary():
	study_chosen.emit(current_settings())
	var face_name:=face.get_item_text(face.selected)
	var values: Array=[numbers[0].value,numbers[1].value,numbers[2].value]
	if analysis.selected==0:
		match boundary.selected:
			0: boundary_chosen.emit("ApplySupport",{"face":face_name})
			1: boundary_chosen.emit("ApplyLoad",{"face":face_name,"force":values})
			2: boundary_chosen.emit("ApplyPressure",{"face":face_name,"value":values[0]})
			3: boundary_chosen.emit("ApplyDisplacement",{"face":face_name,"values":values})
			4: boundary_chosen.emit("ApplyGravity",{"values":values})
	else:
		match boundary.selected:
			0: boundary_chosen.emit("ApplyThermalBoundary",{"boundary":{"face":face_name,"kind":"temperature","value":values[0]}})
			1: boundary_chosen.emit("ApplyThermalBoundary",{"boundary":{"face":face_name,"kind":"flux","value":values[0]}})
			2: boundary_chosen.emit("ApplyThermalBoundary",{"boundary":{"face":face_name,"kind":"convection","h":values[0],"ambient":values[1]}})
			3: boundary_chosen.emit("SetHeatSource",{"value":values[0]})
