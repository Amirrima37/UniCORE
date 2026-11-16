extends AcceptDialog
const Config=preload("res://core/cae/mesh_config.gd")
var workspace
var config={}
var numeric={}
var algorithm: OptionButton
var optimization: OptionButton
var boundary: CheckBox
var element_order: OptionButton
var face_picker: OptionButton
var rule_picker: OptionButton
var local_mode: OptionButton
var local_size: SpinBox
var near: SpinBox
var far: SpinBox
var enabled: CheckBox
var message: Label
var faces=[]
var expected=""
func spin(parent: Node, value: float, low: float, high: float, step: float) -> SpinBox:
	var control=SpinBox.new();control.min_value=low;control.max_value=high;control.step=step;control.value=value;control.custom_minimum_size.x=140;parent.add_child(control);return control
func label(parent: Node,text: String):
	var control=Label.new();control.text=text;control.custom_minimum_size.x=185;control.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;parent.add_child(control);return control
func page(tabs: TabContainer,title: String,content: Control):
	var scroll=ScrollContainer.new();scroll.name=title;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;tabs.add_child(scroll);scroll.add_child(content);content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
func button(parent: Node,text: String,action: Callable):
	var control=Button.new();control.text=text;control.pressed.connect(action);parent.add_child(control);return control
func configure(w, local_tab: bool=false):
	workspace=w;title="Gmsh TET4 / TET10 engineering mesh";size=Vector2i(940,610)
	var p=w.document.data.parts[maxi(0,w.selected)];config=p.get("mesh_settings",Config.defaults()).duplicate(true);faces=load("res://core/cae/cae_document.gd").surface_names(p)
	expected=p.id
	var box=VBoxContainer.new();add_child(box);var tabs=TabContainer.new();box.add_child(tabs);tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL;tabs.custom_minimum_size=Vector2(880,420)
	var global=GridContainer.new();global.columns=4;page(tabs,"Global sizing",global)
	label(global,"Finite element order");element_order=OptionButton.new();element_order.add_item("Linear - TET4");element_order.add_item("Quadratic - TET10");element_order.select(int(config.get("order",1))-1)
	element_order.set_item_disabled(1,w.document.data.get("analysis",{}).get("backend")!="calculix");global.add_child(element_order)
	label(global,"TET10 uses genuine CalculiX C3D10; 4 stress integration points.");label(global,"Curved Jacobian certification is required.")
	for definition in [["target_size","Target (mm)",true],["min_size","Minimum (mm)",true],["max_size","Maximum (mm)",true],["curvature_points","Elements per 2 pi",false],["max_nodes","Max nodes",false],["max_elements","Max elements",false],["timeout_s","Timeout (s)",false],["memory_mb","Worker memory (MiB)",false],["min_quality","Min mean ratio (0..1)",false],["max_edge_ratio","Max edge ratio",false],["optimize_iterations","Optimization passes",false]]:
		var key=definition[0];var scale=1000.0 if definition[2] else 1.0
		label(global,"Min shape score (0..1)" if key=="min_quality" else definition[1]);numeric[key]=spin(global,float(config[key])*scale,0,1e6,0.01 if key in ["min_quality","target_size","min_size","max_size"] else 1)
	label(global,"3D algorithm");algorithm=OptionButton.new();for value in ["delaunay","hxt"]:algorithm.add_item(value)
	algorithm.select(["delaunay","hxt"].find(config.algorithm));global.add_child(algorithm)
	label(global,"Optimization");optimization=OptionButton.new();for value in ["none","gmsh","netgen"]:optimization.add_item(value)
	optimization.select(["none","gmsh","netgen"].find(config.optimization));global.add_child(optimization)
	boundary=CheckBox.new();boundary.text="Extend boundary sizing into volume";boundary.button_pressed=config.boundary_extension;global.add_child(boundary)
	var local=VBoxContainer.new();page(tabs,"Face refinement",local)
	label(local,"Select a physical CAD face, size and transition. All distances below display mm.")
	face_picker=OptionButton.new();for face in faces:face_picker.add_item(face)
	if w.face!=null and w.face.selected>=0:face_picker.select(faces.find(w.face.get_item_text(w.face.selected)))
	local.add_child(face_picker);rule_picker=OptionButton.new();local.add_child(rule_picker)
	rule_picker.item_selected.connect(func(_i):load_rule())
	local_mode=OptionButton.new();local_mode.add_item("face");local_mode.add_item("distance");local.add_child(local_mode)
	var grid=GridContainer.new();grid.columns=2;local.add_child(grid)
	label(grid,"Face target (mm)");local_size=spin(grid,config.target_size*1000/3,0,1e6,0.1)
	label(grid,"Fine zone distance (mm)");near=spin(grid,0,0,1e6,0.1)
	label(grid,"Coarse zone distance (mm)");far=spin(grid,30,0,1e6,0.1)
	local_mode.item_selected.connect(func(index):near.editable=index==1;far.editable=index==1)
	near.editable=false;far.editable=false
	label(local,"Face mode transitions over one local element size. Distance mode uses the fine/coarse distances above.")
	enabled=CheckBox.new();enabled.text="Enable selected rule";enabled.button_pressed=true;local.add_child(enabled)
	button(local,"Add rule for selected CAD face",add_rule)
	button(local,"Update selected rule",save_rule)
	button(local,"Remove selected rule",func():
		if rule_picker.selected>=0:config.local.remove_at(rule_picker.selected);reload_rules())
	reload_rules()
	var stats=VBoxContainer.new();page(tabs,"Measured statistics",stats)
	var mesh=w.document.data.mesh;var q=mesh.get("quality",{})
	label(stats,"Mesh current: "+str(Config.current(w.document.data))+" | nodes "+str(mesh.get("nodes",[]).size())+" | "+str(mesh.get("formulation","elements"))+" "+str(mesh.get("elements",[]).size()))
	for key in ["cad_volume","mesh_volume","absolute_volume_difference","relative_volume_difference","exterior_triangles","minimum_volume","maximum_volume","minimum_mean_ratio","maximum_edge_ratio","edge_min","edge_mean","edge_max","inverted_elements","degenerate_elements","worst_element"]:label(stats,key+": "+str(q.get(key,"not generated")))
	label(stats,"Volumes: m3; edge lengths: m; mean ratio and edge ratio: dimensionless. Relative volume difference is a fraction.")
	label(stats,("Quadratic-score" if mesh.get("formulation")=="TET10" else "Mean-ratio")+" histogram, bins [0,.1), ... [.9,1]: "+str(q.get("quality_histogram",[])))
	label(stats,"Linear precursor / final corner mean ratio (quadratic geometry excluded): "+str(mesh.get("optimization",{}).get("before",{}).get("minimum_mean_ratio","n/a"))+" / "+str(q.get("minimum_mean_ratio","n/a")))
	label(stats,"Generation: "+str(mesh.get("generation_id","legacy/unmeshed")))
	label(stats,"Order: "+str(mesh.get("formulation","unknown"))+" / corners "+str(mesh.get("corner_nodes","all"))+" / midsides "+str(mesh.get("midside_nodes",0)))
	label(stats,"Quadratic score (corner q * detJ bound ratio): "+str(q.get("minimum_quadratic_quality","n/a"))+"; Bernstein detJ lower/upper: "+str(q.get("minimum_jacobian"))+" / "+str(q.get("maximum_jacobian")))
	if mesh.get("formulation")=="TET10":label(stats,"Four integration-point detJ range (m3): "+str(q.get("gauss_jacobian_min","n/a"))+" / "+str(q.get("gauss_jacobian_max","n/a")))
	message=Label.new();message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(message)
	get_ok_button().text="Apply mesh settings";confirmed.connect(apply_settings)
	var generate=add_button("Apply and generate Gmsh mesh",true,"generate");generate.pressed.connect(func():
		if apply_settings():workspace.generate_analysis_mesh())
	canceled.connect(queue_free);tabs.current_tab=1 if local_tab else 0
func reload_rules():
	rule_picker.clear()
	for rule in config.local:rule_picker.add_item(("REVIEW / " if rule.needs_review else "ON / " if rule.enabled else "OFF / ")+rule.face+" / "+str(rule.size*1000)+" mm")
func add_rule():
	if face_picker.selected<0:return
	config.local.append({"id":"refinement_"+str(Time.get_ticks_usec()),"face":faces[face_picker.selected],"enabled":enabled.button_pressed,"needs_review":false,"mode":local_mode.get_item_text(local_mode.selected),"size":local_size.value/1000,"dist_min":near.value/1000,"dist_max":far.value/1000})
	reload_rules();rule_picker.select(config.local.size()-1)
func load_rule():
	if rule_picker.selected<0:return
	var r=config.local[rule_picker.selected];face_picker.select(faces.find(r.face));local_size.value=r.size*1000;near.value=r.dist_min*1000;far.value=r.dist_max*1000;enabled.button_pressed=r.enabled;local_mode.select(0 if r.mode=="face" else 1);near.editable=r.mode=="distance";far.editable=r.mode=="distance"
func save_rule():
	if rule_picker.selected<0:return
	var r=config.local[rule_picker.selected]
	if face_picker.selected>=0:r.face=faces[face_picker.selected];r.needs_review=false
	r.enabled=enabled.button_pressed;r.mode=local_mode.get_item_text(local_mode.selected);r.size=local_size.value/1000;r.dist_min=near.value/1000;r.dist_max=far.value/1000;reload_rules()
func apply_settings() -> bool:
	if workspace.selected<0 or workspace.document.data.parts[workspace.selected].id!=expected:message.text="Selected body changed; reopen mesh settings";return false
	for key in numeric:config[key]=numeric[key].value/(1000.0 if key in ["target_size","min_size","max_size"] else 1.0)
	config.algorithm=algorithm.get_item_text(algorithm.selected);config.optimization=optimization.get_item_text(optimization.selected);config.boundary_extension=boundary.button_pressed
	config.schema=2;config.order=element_order.selected+1
	var error=workspace.document.execute("SetMeshSettings",{"index":workspace.selected,"settings":config})
	if not error.is_empty():message.text=error;show();return false
	workspace.report("Gmsh settings applied; regenerate to obtain a current mesh");queue_free();return true
