extends PanelContainer
signal back_requested
signal ai_prompt_requested(text: String)
const Document = preload("res://core/cae/cae_document.gd")
const Tokens = preload("res://ui/theme/design_tokens.gd")
var document = Document.new()
var selected := -1
var tree: Tree
var properties: VBoxContainer
var status: Label
var scene_root: Node3D
var camera: Camera3D
var view: SubViewportContainer
var cad: SubViewportContainer
var face: OptionButton
var divisions: SpinBox
var dialog: FileDialog
var meshes: Array[MeshInstance3D] = []
var mesh_visible := false
var mesh_inspection = preload("res://core/cae/mesh_inspection.gd").new()
var quality_metric := ""
var mesh_pick_mode := ""
var inspection_mesh_key := ""
var _saving := false
var selection_mode: OptionButton
var active := false
var inspector_bindings: Array = []
var inspector_id := ""
var name_edit: LineEdit
var visibility_edit: CheckButton
var _syncing := false
var tree_items: Array[TreeItem] = []
var overlay_key: Array = []
var ai_input: LineEdit
var view_selector: OptionButton
var structural_buttons: Array[Control] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_top = 52
	install_theme()
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation",5)
	add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	button(header,"← Back to AI Sandbox",func(): back_requested.emit())
	label(header,"ENGINEERING WORKBENCH",true)
	var menus := HBoxContainer.new()
	layout.add_child(menus)
	menu(menus,"File",["New","Open...","Save as..."],[new_project,func(): file_dialog(false),func(): file_dialog(true)])
	menu(menus,"Edit",["Undo","Redo","Duplicate","Delete"],[document.undo,document.redo,func(): run_command("Duplicate"),func(): run_command("Delete")])
	menu(menus,"View",["Fit all","Fit selection","Reset view","Orthographic / perspective","Mesh edges"],[fit_model,func(): cad.fit(selected),func(): cad.target=Vector3.ZERO; cad.set_view("Perspective"),toggle_projection,func(): mesh_visible=not mesh_visible; render_model()])
	menu(menus,"Mesh inspection",["Solid geometry","Solid with mesh edges","Pick element","Pick node","Jacobian (m³)","Volume (m³)","Edge aspect ratio","Distortion"],[func(): set_mesh_display(""),func(): set_mesh_display("edges"),func(): mesh_pick_mode="element"; set_mesh_display("edges"),func(): mesh_pick_mode="node"; set_mesh_display("edges"),func(): set_mesh_display("jacobian"),func(): set_mesh_display("volume"),func(): set_mesh_display("aspect_ratio"),func(): set_mesh_display("distortion")])
	menu(menus,"Materials",["Library / custom materials"],[open_material_library])
	menu(menus,"Geometry",["Box","Cylinder","Sphere","Pipe"],[func(): create_part("Box"),func(): create_part("Cylinder"),func(): create_part("Sphere"),func(): create_part("Pipe")])
	menu(menus,"Simulation",["Study / boundary setup...","Generate box volume mesh","Mesh quality","Validate","Solve","Cancel"],[open_analysis_editor,generate_analysis_mesh,show_mesh_quality,func(): report("\n".join(document.validate())),solve,func():
		if native_solver != null: native_solver.cancel()])
	menu(menus,"Results",["Displacement","Von Mises stress","Temperature","Inspect result probes","Export JSON"],[func(): select_result_field("displacement"),func(): select_result_field("von_mises"),func(): select_result_field("temperature"),show_result_inspector,export_results])
	menu(menus,"AI",["Focus engineering command"],[func(): ai_input.grab_focus()])
	var outer := HSplitContainer.new()
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(outer)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 155
	outer.add_child(left)
	label(left,"MODEL TREE")
	tree = Tree.new()
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.hide_root = false
	left.add_child(tree)
	tree.item_selected.connect(func():
		if _syncing: return
		var item := tree.get_selected()
		if item != null and item.get_metadata(0) != null: select_body(int(item.get_metadata(0))))
	var inner := HSplitContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(inner)
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.custom_minimum_size = Vector2(180,100)
	inner.add_child(center)
	var toolbar := HBoxContainer.new()
	center.add_child(toolbar)
	for kind in ["Box","Cylinder","Sphere","Pipe"]: button(toolbar,kind,func(): create_part(kind))
	button(toolbar,"Fit",fit_model)
	view_selector = OptionButton.new()
	for title in ["Perspective","Front","Back","Left","Right","Top","Bottom","Isometric"]: view_selector.add_item(title)
	toolbar.add_child(view_selector)
	view_selector.item_selected.connect(func(index): cad.set_view(view_selector.get_item_text(index)))
	var viewport_frame := Control.new()
	viewport_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(viewport_frame)
	cad = preload("res://ui/cae/cad_viewport.gd").new()
	cad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport_frame.add_child(cad)
	view = cad
	scene_root = cad.scene_root
	camera = cad.camera
	var orientation := preload("res://ui/cae/orientation_widget.gd").new()
	viewport_frame.add_child(orientation)
	orientation.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	orientation.offset_left = 8
	orientation.offset_right = 108
	orientation.offset_top = -108
	orientation.offset_bottom = -8
	orientation.camera = camera
	cad.camera_changed.connect(orientation.queue_redraw)
	orientation.view_requested.connect(func(title): cad.set_view(title); view_selector.select(["Perspective","Front","Back","Left","Right","Top","Bottom","Isometric"].find(title)))
	cad.body_picked.connect(func(index, face_name):
		if not mesh_pick_mode.is_empty():
			inspect_mesh_click(cad.get_local_mouse_position())
			return
		select_body(index)
		if selection_mode.selected == 1:
			for i in face.item_count:
				if face.get_item_text(i) == face_name: face.select(i))
	var help := Label.new()
	help.text = "RMB orbit  |  MMB / Shift+RMB pan  |  Wheel zoom"
	help.add_theme_font_size_override("font_size",11)
	center.add_child(help)
	var setup := HBoxContainer.new()
	center.add_child(setup)
	selection_mode = OptionButton.new()
	selection_mode.add_item("Body")
	selection_mode.add_item("Box face")
	setup.add_child(selection_mode)
	face = OptionButton.new()
	for value in ["X-","X+","Y-","Y+","Z-","Z+"]: face.add_item(value)
	setup.add_child(face)
	button(setup,"Fix",func(): run_command("ApplySupport",{"face":face.get_item_text(face.selected)}))
	structural_buttons.append(setup.get_child(setup.get_child_count()-1))
	button(setup,"Force",func(): run_command("ApplyLoad",{"face":face.get_item_text(face.selected),"force":current_force()}))
	structural_buttons.append(setup.get_child(setup.get_child_count()-1))
	button(setup,"Setup",open_analysis_editor)
	divisions = SpinBox.new()
	divisions.min_value=1
	divisions.max_value=16
	divisions.value=4
	divisions.tooltip_text="Box mesh divisions per axis"
	setup.add_child(divisions)
	button(setup,"Solve",solve)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 245
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inner.add_child(scroll)
	properties = VBoxContainer.new()
	properties.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	properties.custom_minimum_size.x=225
	scroll.add_child(properties)
	var ai_row := HBoxContainer.new()
	layout.add_child(ai_row)
	ai_input = LineEdit.new()
	ai_input.placeholder_text = "AI: Create a steel cylinder with a diameter of 100 mm and a length of 500 mm"
	ai_input.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	ai_row.add_child(ai_input)
	ai_input.text_submitted.connect(func(text): ai_prompt_requested.emit(text))
	button(ai_row,"Send",func(): ai_prompt_requested.emit(ai_input.text))
	status=Label.new()
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(status)
	document.changed.connect(refresh)
	refresh()
	report("Ready")
	set_active(false)

func install_theme() -> void:
	theme=Theme.new()
	theme.default_font_size=12
	if ResourceLoader.exists(Tokens.FONT_SANS_PATH): theme.default_font=load(Tokens.FONT_SANS_PATH)
	for type in ["Label","Button","MenuButton","OptionButton","LineEdit","Tree","CheckButton","PopupMenu"]:
		theme.set_color("font_color",type,Color("d7dce2"))
		theme.set_color("font_hover_color",type,Color.WHITE)
		for state in ["normal","panel"]:
			var style:=StyleBoxFlat.new()
			style.bg_color=Color("282e35")
			style.set_content_margin_all(4)
			theme.set_stylebox(state,type,style)
		var hover:=StyleBoxFlat.new()
		hover.bg_color=Color("3d4855")
		hover.set_content_margin_all(4)
		theme.set_stylebox("hover",type,hover)
	var panel:=StyleBoxFlat.new()
	panel.bg_color=Color("181d23")
	panel.set_content_margin_all(6)
	add_theme_stylebox_override("panel",panel)

func set_active(value: bool) -> void:
	active=value
	visible=value
	mouse_filter=Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE
	if cad != null: cad.set_active(value)
	# Worker polling is enabled only for the lifetime of a job.
	set_process(solve_thread != null)

func dismiss_dialogs() -> bool:
	for popup in [material_editor,analysis_editor]:
		if popup != null and popup.visible:
			for child in popup.find_children("*","FileDialog",true,false):
				if child.visible: child.hide(); return true
			popup.hide()
			return true
	if dialog != null and dialog.visible:
		dialog.hide()
		return true
	for node in find_children("*","PopupMenu",true,false):
		if node.visible:
			node.hide()
			return true
	return false

func menu(parent: Node,title: String,entries: Array,actions: Array) -> void:
	var control:=MenuButton.new()
	control.text=title
	parent.add_child(control)
	for entry in entries: control.get_popup().add_item(entry)
	control.get_popup().id_pressed.connect(func(index): actions[index].call())

func label(parent: Node,text: String,expand:=false) -> Label:
	var node:=Label.new()
	node.text=text
	node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	if expand: node.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(node)
	return node

func button(parent: Node,text: String,action: Callable) -> void:
	var node:=Button.new()
	node.text=text
	node.focus_mode=Control.FOCUS_NONE
	node.pressed.connect(action)
	parent.add_child(node)

func report(message: String) -> void:
	status.text="Units: mm (solver SI) | " + ("Ready" if message.is_empty() else message)

func create_part(kind: String) -> void:
	var parameters: Dictionary={"length":.2,"diameter":.1} if kind != "Box" else {"length":.1,"width":.1,"height":.1}
	if kind == "Pipe": parameters.inner_diameter=.07
	var error: String=document.execute("CreatePart",{"kind":kind,"parameters":parameters})
	if error.is_empty():
		select_body(document.data.parts.size()-1)
		cad.fit(selected)
	report(error)
	if not error.is_empty(): inspect()

func new_project() -> void:
	document.undo_stack.append(document.data)
	document.redo_stack.clear()
	document.data={"schema":1,"revision":document.data.revision+1,"units":"m-N-Pa-kg","parts":[],"mesh":{},"results":{}}
	selected=-1
	refresh()

func run_command(command: String,args: Dictionary={}) -> void:
	args.index=selected
	var error: String=document.execute(command,args)
	if command == "Duplicate" and error.is_empty(): select_body(document.data.parts.size()-1)
	report(error)
	if not error.is_empty(): inspect()

func select_body(index: int) -> void:
	selected=index
	_syncing=true
	if selected >= 0 and selected < tree_items.size(): tree_items[selected].select(0)
	else: tree.deselect_all()
	_syncing=false
	inspect()
	render_model()

func refresh() -> void:
	if tree == null: return
	for control in structural_buttons: control.visible = document.data.get("analysis",{}).get("type","static_structural") == "static_structural"
	if selected >= document.data.parts.size(): selected=document.data.parts.size()-1
	_syncing=true
	tree.clear()
	tree_items.clear()
	var root:=tree.create_item()
	root.set_text(0,"Project · r%d" % document.data.revision)
	var geometry:=tree.create_item(root)
	geometry.set_text(0,"Geometry")
	for i in document.data.parts.size():
		var item:=tree.create_item(geometry)
		item.set_text(0,document.data.parts[i].name + (" (hidden)" if not document.data.parts[i].get("visible",true) else ""))
		item.set_metadata(0,i)
		tree_items.append(item)
		if i == selected: item.select(0)
	var diagnostics: PackedStringArray = document.validate()
	var physics_name: String = document.data.get("analysis",{}).get("type","static_structural")
	for text in ["Materials (see body requirements)","Mesh: %d cells" % document.data.mesh.get("elements",[]).size(),"Physics: " + physics_name + (" · ready" if diagnostics.is_empty() else " · %d issues" % diagnostics.size()),"Results" + (" (outdated)" if not document.data.results.is_empty() and not results_current() else "")]:
		var item:=tree.create_item(root)
		item.set_text(0,text)
		item.set_tooltip_text(0,text + "\n" + "\n".join(diagnostics))
	_syncing=false
	inspect()
	render_model()

func field(title: String,value: float,low: float,high: float,step: float) -> SpinBox:
	var row:=HBoxContainer.new()
	properties.add_child(row)
	label(row,title,true)
	var spin:=SpinBox.new()
	spin.custom_minimum_size.x=95
	spin.min_value=low
	spin.max_value=high
	spin.step=step
	spin.value=value
	row.add_child(spin)
	return spin

func bound_field(title: String,getter: Callable,command: String,argument: Callable,step:=.1,positive:=true) -> SpinBox:
	var p: Dictionary=document.data.parts[selected]
	var spin:=field(title,float(getter.call(p)),0.0 if positive else -1000000,1000000,step)
	inspector_bindings.append({"node":spin,"getter":getter})
	spin.value_changed.connect(func(value):
		if not _syncing: run_command(command,argument.call(value)))
	return spin

var force_fields: Array[SpinBox]=[]
func current_force() -> Array:
	if force_fields.size()!=3: return [0,-1000,0]
	return [force_fields[0].value,force_fields[1].value,force_fields[2].value]

func inspect() -> void:
	if selected < 0 or selected >= document.data.parts.size():
		clear_inspector()
		label(properties,"Select a body to edit")
		return
	var p: Dictionary=document.data.parts[selected]
	var context_key: String=p.id + "|" + str(document.data.get("analysis",{})) + "|" + JSON.stringify(p.material,"",true,true)
	if inspector_id == context_key:
		_syncing=true
		for binding in inspector_bindings: binding.node.set_value_no_signal(float(binding.getter.call(p)))
		if not name_edit.has_focus(): name_edit.text=p.name
		visibility_edit.set_pressed_no_signal(p.get("visible",true))
		_syncing=false
		return
	clear_inspector()
	inspector_id=context_key
	label(properties,"PROPERTIES / mm")
	name_edit=LineEdit.new()
	name_edit.text=p.name
	properties.add_child(name_edit)
	name_edit.text_submitted.connect(func(title): run_command("Rename",{"name":title}))
	visibility_edit=CheckButton.new()
	visibility_edit.text="Visible"
	visibility_edit.button_pressed=p.get("visible",true)
	properties.add_child(visibility_edit)
	visibility_edit.toggled.connect(func(value): run_command("SetVisibility",{"visible":value}))
	if p.kind == "Box":
		for i in 3:
			bound_field(["Length","Height","Width"][i],func(part): return part.dimensions[i]*1000,"SetParameters",func(value): return {"parameters":{["length","height","width"][i]:value/1000}})
	else:
		bound_field("Outer diameter" if p.kind=="Pipe" else "Diameter",func(part): return part.dimensions[0]*1000,"SetParameters",func(value): return {"parameters":{"diameter":value/1000}})
		bound_field("Radius",func(part): return part.dimensions[0]*500,"SetParameters",func(value): return {"parameters":{"radius":value/1000}})
		if p.kind != "Sphere": bound_field("Length",func(part): return part.dimensions[1]*1000,"SetParameters",func(value): return {"parameters":{"length":value/1000}})
		if p.kind=="Pipe":
			bound_field("Inner diameter",func(part): return part.inner_diameter*1000,"SetParameters",func(value): return {"parameters":{"inner_diameter":value/1000}})
			bound_field("Wall thickness",func(part): return (part.dimensions[0]-part.inner_diameter)*500,"SetParameters",func(value): return {"parameters":{"wall_thickness":value/1000}})
	for key in ["position","rotation","scale"]:
		label(properties,key.capitalize() + (" (mm)" if key=="position" else " (degrees)" if key=="rotation" else ""))
		for i in 3:
			bound_field(["X","Y","Z"][i],func(part): return part.get(key,[1,1,1] if key=="scale" else [0,0,0])[i]*(1000 if key=="position" else 180/PI if key=="rotation" else 1),{"position":"SetPosition","rotation":"SetRotation","scale":"SetScale"}[key],func(value):
				var values: Array=document.data.parts[selected].get(key,[1,1,1] if key=="scale" else [0,0,0]).duplicate()
				values[i]=value/(1000 if key=="position" else 180/PI if key=="rotation" else 1)
				return {"values":values},.1,key=="scale")
	label(properties,"Material: " + str(p.material.get("name","Unassigned")))
	if ClassDB.class_exists("UniCoreGeometryTools"):
		var validation: Dictionary = ClassDB.instantiate("UniCoreGeometryTools").validate_material(p.material,document.data.get("analysis",{}).get("type","static_structural"))
		label(properties,"Material requirements: missing " + str(validation.missing) + "; " + str(validation.errors))
	button(properties,"Material library...",open_material_library)
	if ClassDB.class_exists("UniCoreGeometryTools"):
		button(properties,"Measure volume / mass",func():
			var tools = ClassDB.instantiate("UniCoreGeometryTools")
			var metrics: Dictionary = tools.measure_primitive(document.data.parts[selected])
			if metrics.get("ok",false): report("C++ geometry | volume %s m³ | area %s m² | mass %s kg | local centroid inertia %s kg·m²" % [metrics.volume_m3,metrics.area_m2,metrics.mass_kg,metrics.local_inertia_kg_m2])
			else: report(str(metrics.get("error","Measurement failed"))))
	var modulus:=field("E (GPa)",material_number(p.material,"E")/1e9,0,10000,.1)
	var poisson:=field("Poisson ratio",material_number(p.material,"nu"),-.99,.499,.01)
	var density:=field("Density kg/m³",material_number(p.material,"density"),0,1e6,1)
	inspector_bindings.append({"node":modulus,"getter":func(part): return material_number(part.material,"E")/1e9})
	inspector_bindings.append({"node":poisson,"getter":func(part): return material_number(part.material,"nu")})
	inspector_bindings.append({"node":density,"getter":func(part): return material_number(part.material,"density")})
	button(properties,"Assign material",func(): run_command("AssignMaterial",{"material":{"name":"Custom","E":modulus.value*1e9,"nu":poisson.value,"density":density.value}}))
	if document.data.get("analysis",{}).get("type","static_structural")=="static_structural":
		label(properties,"Total face force (N)")
		for i in 3: force_fields.append(field(["Fx","Fy","Fz"][i],p.force[i],-1e12,1e12,100))
	button(properties,"Reset property values",func(): inspector_id=""; inspect())

func clear_inspector() -> void:
	for child in properties.get_children():
		properties.remove_child(child)
		child.queue_free()
	inspector_id=""
	inspector_bindings.clear()
	force_fields.clear()

func show_result_inspector() -> void:
	clear_inspector()
	inspect_results()
	if document.data.results.is_empty(): label(properties,"No solved results")

func render_model() -> void:
	cad.sync_model(document.data.parts,selected)
	if not quality_metric.is_empty() or (show_results and results_current() and document.data.results.has("temperature")):
		for body in cad.meshes: body.visible=false
	meshes=cad.meshes.duplicate()
	var key: Array=[document.data.revision,document.data.mesh.get("divisions",0),mesh_visible,show_results,deformation_scale,results_current(),result_field,thermal_frame,quality_metric]
	if key == overlay_key: return
	overlay_key=key
	for child in cad.overlay_root.get_children():
		cad.overlay_root.remove_child(child)
		child.queue_free()
	if mesh_visible and not document.data.mesh.is_empty():
		var overlay:=MeshInstance3D.new()
		overlay.mesh=preload("res://core/cae/mesh_display.gd").boundary_edges(document.data.mesh)
		overlay.material_override=cad.line_material(Color("c2a36b"))
		cad.overlay_root.add_child(overlay)
	render_results()

func update_camera() -> void:
	cad.update_camera()
func fit_model() -> void:
	cad.fit()
func toggle_projection() -> void:
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL if camera.projection==Camera3D.PROJECTION_PERSPECTIVE else Camera3D.PROJECTION_PERSPECTIVE
	cad.update_camera()
func view_input(event: InputEvent) -> void:
	cad.navigate(event)

func file_dialog(saving: bool) -> void:
	_saving=saving
	if dialog != null: dialog.queue_free()
	dialog=FileDialog.new()
	dialog.access=FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE if saving else FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters=PackedStringArray(["*.ucae ; UniCORE engineering project"])
	add_child(dialog)
	dialog.file_selected.connect(func(path: String):
		if _saving: report("Saved " + path if document.save_project(path)==OK else "Unable to save project")
		else: report(document.open_project(path)))
	dialog.popup_centered_ratio(.7)
var _last_progress_tick := 0
var pending_result_field := ""
var solve_thread: Thread
var native_solver: RefCounted
var solve_signature := ""
var show_results := false
var deformation_scale := 1.0

func model_signature() -> String:
	return JSON.stringify([document.data.parts, document.data.mesh, document.data.revision], "", true, true)

func solve() -> void:
	if solve_thread != null:
		report("A solve is already running")
		return
	var errors: PackedStringArray = document.validate()
	if not errors.is_empty():
		report("\n".join(errors))
		return
	var thermal: bool = document.data.get("analysis",{}).get("type","static_structural") in ["steady_thermal","transient_thermal"]
	var solver_class: String = "UniCoreThermalSolver" if thermal else "UniCoreStructuralSolver"
	if not ClassDB.class_exists(solver_class):
		report("Structural GDExtension unavailable. Build the updated native library and restart UniCORE.")
		return
	if document.data.mesh.is_empty():
		var error: String = document.generate_mesh(int(divisions.value))
		if not error.is_empty():
			report(error)
			return
	native_solver = ClassDB.instantiate(solver_class)
	native_solver.reset_cancel()
	var snapshot: Dictionary = document.data.duplicate(true)
	solve_signature = model_signature()
	solve_thread = Thread.new()
	set_process(true)
	var error := solve_thread.start(func(): return native_solver.solve_model(snapshot))
	if error != OK:
		solve_thread = null
		set_process(false)
		report("Unable to start solve worker")
		return
	report("Solving immutable revision %s in C++..." % snapshot.revision)

func _process(_delta: float) -> void:
	if solve_thread == null: return
	if solve_thread.is_alive():
		if Time.get_ticks_msec()-_last_progress_tick>200 and native_solver.has_method("get_phase"):
			_last_progress_tick=Time.get_ticks_msec()
			var phase: int=native_solver.get_phase()
			report(["Preparing","Meshing / input validation","Boundary mapping","Sparse assembly","Linear solve","Field recovery","Complete"][clampi(phase,0,6)])
		return
	var result: Dictionary = solve_thread.wait_to_finish()
	solve_thread = null
	set_process(false)
	if not result.get("ok", false):
		report("Solve stopped: " + str(result.get("error", "Unknown failure")))
		return
	if solve_signature != model_signature():
		report("Solve completed for an older model; solve again to inspect the edited project.")
		return
	result["model_parts"] = document.data.parts.duplicate(true)
	document.data.results = result
	show_results = true
	result_field = "temperature" if result.has("temperature") else "von_mises" if pending_result_field=="von_mises" else "displacement"
	pending_result_field=""
	thermal_frame=-1
	show_result_inspector()
	render_model()
	if result.has("temperature"):
		report("%s | T range %s–%s K | heat balance %s W" % [result.backend,result.min_temperature,result.max_temperature,result.energy_balance_W])
	else:
		report("%s | %s elements | residual %s | displacement %s m" % [result.backend,result.stress.size(),result.relative_residual,result.max_displacement])

func _exit_tree() -> void:
	if solve_thread != null:
		native_solver.cancel()
		solve_thread.wait_to_finish()

func results_current() -> bool:
	var r: Dictionary = document.data.get("results", {})
	return r.get("ok", false) and r.get("revision", -1) == document.data.revision and r.get("model_parts", []) == document.data.parts and r.get("mesh_divisions", -1) == document.data.mesh.get("divisions", -2)

func render_results() -> void:
	if not show_results or not results_current(): return
	if document.data.results.has("temperature"):
		render_temperature()
		return
	var r: Dictionary = document.data.results
	var lines := ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	var maximum: float = maxf(float(r.von_mises.max()) if result_field=="von_mises" else float(r.max_displacement),1e-30)
	var cells: Array = r.get("elements",r.tetrahedra)
	for cell_index in cells.size():
		var tet: Array = cells[cell_index]
		for edge in ([[0,1],[1,2],[2,3],[3,0],[4,5],[5,6],[6,7],[7,4],[0,4],[1,5],[2,6],[3,7]] if tet.size()==8 else [[0,1],[1,2],[2,0],[0,3],[1,3],[2,3]]):
			for corner in edge:
				var id: int = tet[corner]
				var xyz: Array = r.nodes[id]
				var u: Array = r.displacement[id]
				var displacement := Vector3(u[0], u[1], u[2])
				lines.surface_set_color(Color("367aff").lerp(Color("ff4c38"), clampf((r.von_mises[cell_index] if result_field=="von_mises" else displacement.length())/maximum,0,1)))
				lines.surface_add_vertex(Vector3(xyz[0],xyz[1],xyz[2]) + displacement*deformation_scale)
	lines.surface_end()
	var instance := MeshInstance3D.new()
	instance.mesh = lines
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	instance.material_override = material
	cad.overlay_root.add_child(instance)
	meshes.append(instance)

func inspect_results() -> void:
	if document.data.results.has("temperature"):
		inspect_thermal_results()
		return
	if document.data.get("results", {}).is_empty(): return
	label(properties, "RESULTS" + ("" if results_current() else " / OUTDATED"))
	if not results_current(): return
	var r: Dictionary = document.data.results
	label(properties, "Nodal displacement: m\nElement stress: Pa (unaveraged)\nEngineering strain: dimensionless\nOrder: xx, yy, zz, xy, yz, xz")
	label(properties, "Colors: blue = 0; red = " + str(r.von_mises.max() if result_field=="von_mises" else r.max_displacement) + (" Pa (unaveraged centers)" if result_field=="von_mises" else " m"))
	var magnification := field("Deformation scale", deformation_scale, 0, 1000000, 1)
	magnification.value_changed.connect(func(value): deformation_scale = value; render_model())
	label(properties, "Backend: " + r.backend + "\nRevision: " + str(r.revision) + "\nNodes: " + str(r.nodes.size()) + "\nElements: " + str(r.stress.size()) + "\nRelative residual: " + str(r.relative_residual))
	var total := Vector3.ZERO
	for v in r.reactions: total += Vector3(v[0], v[1], v[2])
	label(properties, "Total support reaction (N): " + str(total))
	var node := field("Probe node ID", 0, 0, r.nodes.size()-1, 1)
	var element := field("Probe element ID", 0, 0, r.stress.size()-1, 1)
	var output := label(properties, "")
	output.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var update := func(_value = 0):
		var i := int(node.value)
		var e := int(element.value)
		output.text = "u (m): %s\nReaction (N): %s\nStress (Pa): %s\nStrain: %s\nvon Mises (Pa): %s" % [r.displacement[i], r.reactions[i], r.stress[e], r.strain[e], r.von_mises[e]]
		if r.has("principal_stress"): output.text += "\nPrincipal stress (Pa, descending): " + str(r.principal_stress[e])
	node.value_changed.connect(update)
	element.value_changed.connect(update)
	update.call()


func engineering_context() -> Dictionary:
	return {"active":active,"revision":document.data.revision,"selected_index":selected,"parts":document.data.parts.duplicate(true),"units":"m-N-Pa-kg","signature":JSON.stringify([document.data.revision,document.data.parts,selected], "", true, true)}

func apply_engineering_response(response: Dictionary, expected_signature: String) -> String:
	if engineering_context().signature != expected_signature: return "Model or selection changed while AI was responding; send the request again"
	var commands = response.get("commands", [])
	if not commands is Array or commands.is_empty() or commands.size()>32: return "Expected 1 to 32 engineering commands"
	var staging = Document.new()
	staging.data = document.data.duplicate(true)
	var next_selection := selected
	var request_solve := false
	var request_view := ""
	var generated_mesh := false
	for entry in commands:
		if not entry is Dictionary or not entry.get("args", {}) is Dictionary: return "Invalid command envelope"
		var command: String = str(entry.get("command", ""))
		if command == "GenerateMesh":
			var size = entry.get("args",{}).get("target_size")
			if not (size is int or size is float) or not is_finite(float(size)) or size<=0: return "Mesh target_size must be positive metres"
			var largest := 0.0
			for part in staging.data.parts:
				for axis in 3: largest=maxf(largest,float(part.dimensions[axis])*float(part.get("scale",[1,1,1])[axis]))
			var resolution:=maxi(1,ceili(largest/float(size)))
			if resolution>16: return "Requested mesh exceeds current 16 divisions/axis limit"
			var mesh_error: String=staging.generate_mesh(resolution)
			if not mesh_error.is_empty(): return mesh_error
			generated_mesh=true
			continue
		if command == "SolveAnalysis": request_solve=true; continue
		if command == "CreateResultView":
			request_view=str(entry.get("args",{}).get("field",""))
			if request_view not in ["displacement","von_mises","temperature"]: return "Unsupported result field"
			continue
		if command not in ["CreatePart","SetParameters","SetPosition","SetRotation","SetScale","AssignMaterial","Rename","Duplicate","Delete","SetVisibility","ApplySupport","ApplyLoad","ApplyPressure","ApplyDisplacement","ApplyGravity","AssignMaterialById","SetAnalysis","ApplyThermalBoundary","SetHeatSource"]: return "Unsupported engineering command: " + command
		var args: Dictionary = entry.get("args", {}).duplicate(true)
		if not args.has("index"): args.index = next_selection
		var error: String = staging.execute(command, args)
		if not error.is_empty(): return error
		if command in ["CreatePart","Duplicate"]: next_selection = staging.data.parts.size()-1
	if generated_mesh and staging.data.mesh.is_empty(): return "Generate the mesh after all modeling changes"
	if request_solve:
		var diagnostics: PackedStringArray=staging.validate()
		if not diagnostics.is_empty(): return "\n".join(diagnostics)
	var changed_model: bool=staging.data.parts!=document.data.parts or staging.data.get("analysis",{})!=document.data.get("analysis",{})
	if not changed_model and not generated_mesh:
		if request_solve: pending_result_field=request_view; solve()
		elif not request_view.is_empty(): select_result_field(request_view)
		return ""
	document.undo_stack.append(document.data)
	document.redo_stack.clear()
	document.data = staging.data
	selected = next_selection
	document.changed.emit()
	cad.fit(selected)
	if request_solve: pending_result_field=request_view; solve()
	elif not request_view.is_empty(): select_result_field(request_view)
	report("AI applied %d validated commands. %s" % [commands.size(),str(response.get("assumptions", []))])
	return ""

func _unhandled_key_input(event: InputEvent) -> void:
	if not active or not event is InputEventKey or not event.pressed or event.echo: return
	var focus:=get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit: return
	if event.ctrl_pressed and event.keycode==KEY_Z:
		if event.shift_pressed: document.redo()
		else: document.undo()
	elif event.ctrl_pressed and event.keycode==KEY_Y: document.redo()
	elif event.ctrl_pressed and event.keycode==KEY_S: file_dialog(true)
	elif event.keycode==KEY_DELETE: run_command("Delete")
	elif event.keycode==KEY_F: fit_model()
	else: return
	get_viewport().set_input_as_handled()

var material_editor: ConfirmationDialog
func material_number(material: Dictionary,key: String) -> float:
	var v=material.get(key)
	return float(v) if v is int or v is float else 0.0
func open_material_library() -> void:
	if selected<0: report("Select a body first"); return
	if material_editor!=null: material_editor.queue_free()
	material_editor=preload("res://ui/cae/material_editor.gd").new()
	material_editor.analysis=document.data.get("analysis",{}).get("type","static_structural")
	add_child(material_editor)
	material_editor.material_chosen.connect(func(material): run_command("AssignMaterial",{"material":material}); inspector_id=""; inspect())
	material_editor.popup_centered(Vector2i(680,600))

var analysis_editor: ConfirmationDialog
var result_field := "displacement"
var thermal_frame := -1
func open_analysis_editor() -> void:
	if selected<0: report("Select a body to configure analysis conditions"); return
	if analysis_editor!=null: analysis_editor.queue_free()
	analysis_editor=preload("res://ui/cae/analysis_editor.gd").new()
	analysis_editor.settings=document.data.get("analysis",{}).duplicate(true)
	add_child(analysis_editor)
	analysis_editor.study_chosen.connect(func(settings): report(document.execute("SetAnalysis",{"analysis":settings})))
	analysis_editor.boundary_chosen.connect(func(command,args): run_command(command,args))
	analysis_editor.popup_centered(Vector2i(540,600))
func generate_analysis_mesh() -> void:
	var error: String=document.generate_mesh(int(divisions.value))
	if not error.is_empty(): report(error)
	else: show_mesh_quality()
func show_mesh_quality() -> void:
	if document.data.mesh.is_empty(): report("Generate an analysis mesh first"); return
	var mesh: Dictionary=document.data.mesh
	report("%s nodes | %s cells | quality %s" % [mesh.nodes.size(),mesh.elements.size(),mesh.get("quality", "Native quality report unavailable")])
func select_result_field(field: String) -> void:
	if not results_current(): report("Solve the current revision first"); return
	if field=="temperature" and not document.data.results.has("temperature"): report("No thermal result in this study"); return
	if field!="temperature" and document.data.results.has("temperature"): report("This study contains thermal fields"); return
	result_field=field
	show_results=true
	render_model()
	show_result_inspector()
	report("Showing actual " + field + (" (Pa, element centers, unaveraged)" if field=="von_mises" else " (K)" if field=="temperature" else " (m)"))
func export_results() -> void:
	if not results_current(): report("No current result to export"); return
	if dialog!=null: dialog.queue_free()
	dialog=FileDialog.new()
	dialog.access=FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE
	dialog.filters=PackedStringArray(["*.json ; Actual solver result fields and diagnostics"])
	add_child(dialog)
	var snapshot: Dictionary=document.data.results.duplicate(true)
	dialog.file_selected.connect(func(path):
		var file:=FileAccess.open(path,FileAccess.WRITE)
		if file!=null: file.store_string(JSON.stringify(snapshot,"\t",true,true)); report("Exported actual solver fields"))
	dialog.popup_centered_ratio(.65)
func render_temperature() -> void:
	var r: Dictionary=document.data.results
	var mesh:=ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var values: Array=r.history[thermal_frame] if thermal_frame>=0 and thermal_frame<r.get("history",[]).size() else r.temperature
	var lo: float=values.min()
	var span: float=maxf(float(values.max())-lo,1e-12)
	# Piecewise-linear TET4 temperature, no invented fields or stress averaging.
	var boundary_faces := {}
	for cell in r.elements:
		for face_nodes in [[0,1,2],[0,3,1],[0,2,3],[1,3,2]]:
			var ids: Array=[cell[face_nodes[0]],cell[face_nodes[1]],cell[face_nodes[2]]]
			var sorted: Array=ids.duplicate()
			sorted.sort()
			var key:=str(sorted)
			if boundary_faces.has(key): boundary_faces[key].count+=1
			else: boundary_faces[key]={"count":1,"ids":ids}
	for entry in boundary_faces.values():
		if entry.count!=1: continue
		for id in entry.ids:
			mesh.surface_set_color(Color("3474ca").lerp(Color("e56742"),(values[id]-lo)/span))
			var xyz: Array=r.nodes[id]
			mesh.surface_add_vertex(Vector3(xyz[0],xyz[1],xyz[2]))
	mesh.surface_end()
	var instance:=MeshInstance3D.new()
	instance.mesh=mesh
	var material: StandardMaterial3D=cad.line_material(Color.WHITE)
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material.no_depth_test=false
	instance.material_override=material
	cad.overlay_root.add_child(instance)
func inspect_thermal_results() -> void:
	if not results_current(): label(properties,"Thermal result is outdated"); return
	var r: Dictionary=document.data.results
	label(properties,"TEMPERATURE / HEAT FLUX")
	if not r.get("warnings",[]).is_empty(): label(properties,"Material review: " + str(r.warnings))
	label(properties,"Blue %s K → red %s K\nHeat flux is elementwise W/m²\nEnergy imbalance %s W\nRelative residual %s" % [r.min_temperature,r.max_temperature,r.energy_balance_W,r.relative_residual])
	var node:=field("Probe node",0,0,r.nodes.size()-1,1)
	var element:=field("Probe element",0,0,r.heat_flux.size()-1,1)
	var value:=label(properties,"")
	var update:=func(_v=0): value.text="Temperature: %s K\nHeat flux: %s W/m²" % [r.temperature[int(node.value)],r.heat_flux[int(element.value)]]
	node.value_changed.connect(update)
	element.value_changed.connect(update)
	update.call()
	if not r.get("history",[]).is_empty():
		var step:=field("History frame",r.history.size()-1,0,r.history.size()-1,1)
		var temperature_label:=label(properties,"")
		step.value_changed.connect(func(index):
			thermal_frame=int(index)
			var values: Array=r.history[thermal_frame]
			temperature_label.text="t=%s s; T(probe)=%s K; blue %s K → red %s K. Flux probe remains final-time." % [r.times[thermal_frame],values[int(node.value)],values.min(),values.max()]
			render_model())


func prepare_mesh_inspection() -> void:
	var key := JSON.stringify(document.data.mesh)
	if key!=inspection_mesh_key:
		mesh_inspection.prepare(document.data.mesh)
		inspection_mesh_key=key

func set_mesh_display(metric: String) -> void:
	if document.data.mesh.is_empty(): report("Generate an analysis mesh first"); return
	quality_metric="" if metric in ["","edges"] else metric
	mesh_visible=not metric.is_empty()
	show_results=false
	if metric.is_empty(): mesh_pick_mode=""
	render_model()
	cad.invalidate()
	if not quality_metric.is_empty():
		prepare_mesh_inspection()
		var contour: Dictionary=mesh_inspection.contour(quality_metric)
		clear_inspector()
		label(properties,"Mesh quality: " + quality_metric)
		label(properties,"Blue %.6g > red %.6g\nElement-centered, unaveraged\nPick element/node from Mesh inspection menu." % [contour.min,contour.max])
		label(properties,"Distortion = 1 ? minimum scaled Jacobian.\nHEX8: 8 Gauss samples; TET4: corner 0.\nAspect ratio = longest / shortest edge.\nThese are diagnostics, not solver acceptance criteria.")

func inspect_mesh_click(screen: Vector2) -> void:
	if document.data.mesh.is_empty(): return
	prepare_mesh_inspection()
	var hit: Dictionary=mesh_inspection.pick(camera,screen)
	if hit.is_empty(): return
	clear_inspector()
	var mesh: Dictionary=document.data.mesh
	var cell: Array=mesh.elements[hit.element]
	label(properties,"Element %d · %s (zero-based IDs)" % [hit.element,"TET4" if cell.size()==4 else "HEX8"])
	label(properties,"Connectivity: " + str(cell))
	if mesh_pick_mode=="node":
		if hit.node_distance>14: label(properties,"Click within 14 pixels of an exposed face node."); return
		var p: Vector3=mesh_inspection.point(hit.node)
		label(properties,"Node %d\nCoordinates (m): %.6g, %.6g, %.6g" % [hit.node,p.x,p.y,p.z])
	var region: String=str(mesh.get("material_regions",[])[hit.element]) if mesh.get("material_regions",[]).size()>hit.element else "Unavailable"
	label(properties,"Body / material region: " + region)
	for part in document.data.parts:
		if str(part.id)==region: label(properties,"Material: " + str(part.get("material",{}).get("name","Unspecified")))
	var groups: Array=[]
	for body in mesh.get("regions",{}):
		for group in mesh.regions[body]:
			var contains := true
			for id in hit.face:
				if not mesh.regions[body][group].has(id): contains=false
			if contains: groups.append(str(body)+" / "+str(group))
	label(properties,"Boundary groups: " + (", ".join(groups) if not groups.is_empty() else "None"))
	var q: Dictionary=mesh_inspection.metrics[hit.element]
	for key in ["jacobian","volume","aspect_ratio","distortion"]:
		label(properties,"%s: %.6g%s" % [key,q[key]," m?" if key in ["jacobian","volume"] else ""])
	label(properties,"Inverted: %s · Degenerate: %s" % [q.inverted,q.degenerate])
