extends PanelContainer
signal back_requested
signal ai_prompt_requested(text: String)
const Conditions = preload("res://core/cae/condition_catalog.gd")
var face_highlight: MeshInstance3D
var condition_marker_visible := true
const Visuals=preload("res://core/cae/engineering_visuals.gd")
var tool_registry = preload("res://core/cae/tool_registry.gd").new()
var ribbon_tabs: HBoxContainer
var ribbon_tools: HBoxContainer
var ribbon_buttons: Array = []
var active_ribbon := "Home"
var outer_split: HSplitContainer
var inner_split: HSplitContainer
var tree_state: Dictionary = {}
var section_state: Dictionary = {}
var tree_popup: PopupMenu
var tool_browser: ConfirmationDialog
var project_status: Label
var console_log: RichTextLabel
var console_panel: VBoxContainer
var thermal_display=preload("res://core/cae/thermal_display.gd").new()
var thermal_display_key := ""
var thermal_low := NAN
var thermal_high := NAN
var thermal_palette := "temperature"
var thermal_field := "temperature"
var celsius := false
var show_flux_arrows := false
var flux_stride := 20
var flux_scale := 0.01
var normalize_flux := false
var thermal_isolines := 0
var fixed_thermal_scale := true
var playback: Timer
var playback_speed := 1.0
var color_palette := "viridis"
var contour_low := NAN
var contour_high := NAN
var contour_bands := 0
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
var inspection_mode := ""
var section_fraction := 1.0
var selection_highlight: MeshInstance3D
var quality_metric := ""
var mesh_pick_mode := ""
var inspection_mesh_key := ""
var preparation_jobs: Array=[]
var preparation_generation := 0
var preparation_key := ""
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
	button(header,"AI Sandbox",func(): back_requested.emit())
	label(header,"UniCORE  /  Engineering",true)
	project_status = label(header,"Untitled В· revision 0")
	project_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	project_status.custom_minimum_size.x = 270
	for child in header.get_children():
		if child is Label: child.autowrap_mode = TextServer.AUTOWRAP_OFF
	button(header,"Tools / roadmap",open_tool_browser)
	var menu_scroll := ScrollContainer.new()
	menu_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(menu_scroll)
	menu_scroll.hide()
	var menus := HBoxContainer.new()
	menu_scroll.add_child(menus)
	menu(menus,"File",["New","Open...","Save as..."],[new_project,func(): file_dialog(false),func(): file_dialog(true)])
	menu(menus,"Edit",["Undo","Redo","Duplicate","Delete"],[document.undo,document.redo,func(): run_command("Duplicate"),confirm_delete])
	menu(menus,"View",["Fit all","Fit selection","Reset view","Orthographic / perspective","Mesh edges"],[fit_model,func(): cad.fit(selected),func(): cad.target=Vector3.ZERO; cad.set_view("Perspective"),toggle_projection,func(): mesh_visible=not mesh_visible; render_model()])
	menu(menus,"Mesh inspection",["Solid mesh","Wireframe","Solid + wireframe","Nodes","Elements","Quality","Invalid elements","Controls"],[func(): set_inspection_mode("solid"),func(): set_inspection_mode("wireframe"),func(): set_inspection_mode("combined"),func(): set_inspection_mode("nodes"),func(): set_inspection_mode("elements"),func(): set_inspection_mode("quality"),func(): set_inspection_mode("invalid"),inspection_controls])
	menu(menus,"Extreme CPU",["Configure / jobs"],[open_extreme_mode])
	menu(menus,"Materials",["Library / custom materials"],[open_material_library])
	menu(menus,"Geometry",["Box","Cylinder","Sphere","Pipe","Import STEP...","Boolean CAD...","Edit CAD features..."],[func(): create_part("Box"),func(): create_part("Cylinder"),func(): create_part("Sphere"),func(): create_part("Pipe"),import_step_dialog,func():open_cad_boolean(false),func():open_cad_boolean(true)])
	menu(menus,"Simulation",["Study / boundary setup...","Generate box volume mesh","Mesh quality","Validate","Solve","Cancel"],[open_analysis_editor,generate_analysis_mesh,show_mesh_quality,func(): report("\n".join(document.validate())),solve,func():
		if native_solver != null: native_solver.cancel()])
	menu(menus,"Results",["Displacement","Von Mises stress","Temperature","Inspect result probes","Export JSON"],[func(): select_result_field("displacement"),func(): select_result_field("von_mises"),func(): select_result_field("temperature"),show_result_inspector,export_results])
	menu(menus,"AI",["Focus engineering command"],[func(): console_panel.show(); ai_input.grab_focus()])
	build_ribbon(layout)
	var outer := HSplitContainer.new()
	outer_split = outer
	outer.split_offset = 215
	outer.add_theme_constant_override("separation", 8)
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(outer)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 175
	outer.add_child(left)
	label(left,"MODEL EXPLORER")
	tree = Tree.new()
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.hide_root = false
	left.add_child(tree)
	tree.item_selected.connect(func():
		if _syncing: return
		var item := tree.get_selected()
		if item == null: return
		var meta = item.get_metadata(0)
		if meta is int: select_body(meta)
		elif meta is String: inspect_category(meta)
		elif meta is Dictionary: inspect_condition(meta))
	tree.item_collapsed.connect(func(item): tree_state[item.get_meta("key", "")] = item.collapsed)
	tree.item_mouse_selected.connect(func(_position, mouse_button):
		if mouse_button == MOUSE_BUTTON_RIGHT:
			tree_popup.position = Vector2i(get_viewport().get_mouse_position())
			tree_popup.popup())
	tree_popup = PopupMenu.new()
	add_child(tree_popup)
	for title in ["Fit selected body", "Duplicate body", "Toggle visibility", "Delete body..."]: tree_popup.add_item(title)
	tree_popup.about_to_popup.connect(func():
		for i in 4: tree_popup.set_item_disabled(i, selected < 0))
	tree_popup.id_pressed.connect(tree_context_action)
	var inner := HSplitContainer.new()
	inner_split = inner
	inner.split_offset = -290
	inner.add_theme_constant_override("separation", 8)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(inner)
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.custom_minimum_size = Vector2(320,100)
	inner.add_child(center)
	var toolbar := HBoxContainer.new()
	center.add_child(toolbar)
	var view_label := label(toolbar,"VIEW",false)
	view_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	button(toolbar,"Fit all",fit_model)
	button(toolbar,"Fit body",func(): cad.fit(selected))
	button(toolbar,"Ortho / perspective",toggle_projection)
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
		if selection_mode.selected == 1 and index>=0 and document.data.parts[index].kind in ["Box","CAD"]:
			for i in face.item_count:
				if face.get_item_text(i) == face_name: face.select(i)
			inspector_id="";inspect();show_selected_face()
			report("Selected "+document.data.parts[index].name+" / local face "+face_name))
	var help := Label.new()
	help.text = "RMB orbit  |  MMB / Shift+RMB pan  |  Wheel zoom"
	help.add_theme_font_size_override("font_size",11)
	center.add_child(help)
	var setup := HBoxContainer.new()
	center.add_child(setup)
	selection_mode = OptionButton.new()
	selection_mode.add_item("Body")
	selection_mode.add_item("Analysis surface")
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
	setup.hide()
	selection_mode.reparent(toolbar)
	face.reparent(toolbar)
	selection_mode.item_selected.connect(func(_i): mesh_pick_mode=""; show_selected_face())
	face.item_selected.connect(func(_i): inspector_id="";inspect();show_selected_face())
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 270
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inner.add_child(scroll)
	properties = VBoxContainer.new()
	properties.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	properties.custom_minimum_size.x=250
	scroll.add_child(properties)
	var console_toggle := Button.new()
	console_toggle.text = "Engineering console / AI commands"
	console_toggle.toggle_mode = true
	layout.add_child(console_toggle)
	console_panel = VBoxContainer.new()
	layout.add_child(console_panel)
	console_panel.visible = false
	console_toggle.toggled.connect(func(value): console_panel.visible=value)
	console_log = RichTextLabel.new()
	console_log.custom_minimum_size.y = 70
	console_log.scroll_following = true
	console_panel.add_child(console_log)
	var ai_row := HBoxContainer.new()
	console_panel.add_child(ai_row)
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
		var pressed := StyleBoxFlat.new()
		pressed.bg_color=Color("314b5c")
		pressed.border_color=Color("78a6bc")
		pressed.border_width_bottom=2
		pressed.set_content_margin_all(4)
		theme.set_stylebox("pressed",type,pressed)
		theme.set_color("font_disabled_color",type,Color("74808c"))
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
	set_process(solve_thread != null or cad_geometry_thread!=null or not preparation_jobs.is_empty())

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

func open_tool_browser() -> void:
	if tool_browser == null:
		tool_browser = preload("res://ui/cae/tool_browser.gd").new()
		tool_browser.registry = tool_registry
		add_child(tool_browser)
	tool_browser.popup_centered()
	tool_browser.query.grab_focus()

func tool_requirement(category: String, entry: String) -> String:
	if entry in ["Duplicate", "Delete"] or category == "Materials":
		if selected < 0: return "Select a body first"
	if entry == "Undo" and document.undo_stack.is_empty(): return "No document edit to undo"
	if entry == "Redo" and document.redo_stack.is_empty(): return "No document edit to redo"
	if entry == "Cancel" and solve_thread == null: return "No normal-mode solve is running"
	if category == "Results":
		if not results_current(): return "Solve the current model first"
		var required: String={"Displacement":"displacement","Von Mises stress":"von_mises","Temperature":"temperature"}.get(entry,"")
		if not required.is_empty() and not document.data.results.has(required): return "Field not produced by this analysis"
	if category == "Mesh inspection" and document.data.mesh.is_empty(): return "Generate a solver mesh first"
	return ""

func menu(parent: Node,title: String,entries: Array,actions: Array) -> void:
	var control:=MenuButton.new()
	control.text=title
	parent.add_child(control)
	var ids: Array = []
	for i in entries.size():
		var entry: String = entries[i]
		var shortcut: String = {"Undo":"Ctrl+Z","Redo":"Ctrl+Y","Save as...":"Ctrl+S","Fit all":"F","Delete":"Delete"}.get(entry, "")
		ids.append(tool_registry.register(title,entry,actions[i],func(): return tool_requirement(title,entry),shortcut))
		control.get_popup().add_item(entry)
	control.tooltip_text = title + " commands вЂ” also available in Tools / roadmap (Ctrl+K)"
	control.get_popup().about_to_popup.connect(func():
		for i in ids.size():
			control.get_popup().set_item_disabled(i, not tool_requirement(title,entries[i]).is_empty()))
	control.get_popup().id_pressed.connect(func(index):
		var error: String = tool_registry.execute(ids[index])
		if not error.is_empty(): report(error))

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

var last_console_message=""
const CONSOLE_PARAGRAPHS=512
const CONSOLE_CHARACTERS=131072
func report(message: String) -> void:
	if console_log != null and not message.is_empty() and message!=last_console_message:
		# Full diagnostics remain in external owned jobs; bound the transient UI log.
		console_log.append_text("[%s] %s\n" % [Time.get_time_string_from_system(), message.left(8192)])
		last_console_message=message
		while console_log.get_paragraph_count()>CONSOLE_PARAGRAPHS or console_log.get_total_character_count()>CONSOLE_CHARACTERS:
			console_log.remove_paragraph(0)
	status.tooltip_text = message
	status.text="Units: mm (solver SI) | " + ("Ready" if message.is_empty() else message)

func create_part(kind: String) -> void:
	var parameters: Dictionary={"length":.2,"diameter":.1} if kind != "Box" else {"length":.1,"width":.1,"height":.1}
	if kind == "Sphere": parameters={"radius":.05}
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
	if face!=null and selected>=0:
		face.clear()
		for region_name in Document.surface_names(document.data.parts[selected]): face.add_item(region_name)
	_syncing=true
	if is_instance_valid(face_highlight): face_highlight.hide()
	if selected >= 0 and selected < tree_items.size(): tree_items[selected].select(0)
	else: tree.deselect_all()
	_syncing=false
	inspect()
	update_ribbon_availability()
	render_model()

func refresh() -> void:
	if cad_metadata_installing:return
	if is_instance_valid(face_highlight): face_highlight.hide()
	if project_status != null:
		project_status.text = "Untitled В· r%d В· %s" % [document.data.revision, document.data.get("analysis",{}).get("type","static_structural").replace("_"," ")]
	inspection_mesh_key=""
	preparation_key=""
	preparation_generation+=1
	for job in preparation_jobs: job.cancel()
	overlay_key=[]
	reset_mesh_selection()
	if tree == null: return
	for control in structural_buttons: control.visible = document.data.get("analysis",{}).get("type","static_structural") == "static_structural"
	if selected >= document.data.parts.size(): selected=document.data.parts.size()-1
	_syncing=true
	rebuild_explorer()
	update_ribbon_availability()
	_syncing=false
	inspect()
	render_model()
	if document.data.parts.any(func(p):return p.kind=="CAD") and not complete_cad_display(document.data.mesh) and cad_preview.is_empty() and cad_preview_thread==null and cad_geometry_thread==null:start_cad_preview()

func field(title: String,value: float,low: float,high: float,step: float) -> SpinBox:
	var row:=HBoxContainer.new()
	properties.add_child(row)
	label(row,title,true)
	var spin:=SpinBox.new()
	spin.custom_minimum_size.x=112
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.get_line_edit().alignment = HORIZONTAL_ALIGNMENT_RIGHT
	spin.tooltip_text = title
	row.get_child(0).custom_minimum_size.x = 100
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
	var context_key: String=p.id + "|" + str(document.data.get("analysis",{})) + "|" + JSON.stringify(p.material,"",true,true)+"|"+str(p.get("analysis_enabled",true))
	if p.kind=="CAD":context_key+="|"+str(p.get("cad_geometry_revision",""))+"|"+JSON.stringify(p.get("cad_pending_boundaries",{}))+"|"+str(p.get("analysis_enabled",true))+"|"+str(p.get("cad_boundary_archive",[]).size())+"|"+JSON.stringify(p.get("boundary_refs",{}))+"|"+(face.get_item_text(face.selected) if face.selected>=0 else "")+"|"+str(p.get("cad_faces",[]))
	if inspector_id == context_key:
		_syncing=true
		for binding in inspector_bindings: binding.node.set_value_no_signal(float(binding.getter.call(p)))
		if not name_edit.has_focus(): name_edit.text=p.name
		visibility_edit.set_pressed_no_signal(p.get("visible",true))
		_syncing=false
		return
	clear_inspector()
	inspector_id=context_key
	var inspector_root := properties
	label(properties,"BODY / " + p.kind.to_upper())
	properties = property_section(inspector_root,"Identity",p.kind!="CAD")
	name_edit=LineEdit.new()
	name_edit.text=p.name
	properties.add_child(name_edit)
	name_edit.text_submitted.connect(func(title): run_command("Rename",{"name":title}))
	visibility_edit=CheckButton.new()
	visibility_edit.text="Visible"
	visibility_edit.button_pressed=p.get("visible",true)
	properties.add_child(visibility_edit)
	visibility_edit.toggled.connect(func(value): run_command("SetVisibility",{"visible":value}))
	var participation_control=CheckButton.new()
	participation_control.text="Include in analysis"
	participation_control.button_pressed=p.get("analysis_enabled",true)
	properties.add_child(participation_control)
	participation_control.toggled.connect(func(value):run_command("SetAnalysisEnabled",{"enabled":value}))
	if p.kind=="CAD":
		properties = property_section(inspector_root,"Face assignments",true)
		button(properties,"Review shared definition faces...",func():
			var review=AcceptDialog.new();add_child(review)
			review.title="Review definition face identity"
			review.dialog_text="Native source review marks assignments on this definition unresolved. Select and reassign each intended face afterwards."
			review.confirmed.connect(func():
				if start_cad_geometry({"action":"review_faces","part":p.duplicate(true)},self):pending_face_review_uuid=p.instance_uuid)
			review.popup_centered())
		label(properties,"Instance: "+str(p.get("instance_uuid","missing")).left(12)+"...").tooltip_text=str(p.get("instance_uuid","missing"))
		var selected_face_id=face.get_item_text(face.selected) if face.selected>=0 else "Wait for native faces"
		label(properties,"Selected face: "+selected_face_id.left(18)+"...").tooltip_text=selected_face_id
		for key in ["support","load_face"]:
			var assignment=p.get("boundary_refs",{}).get(key,{})
			var reference_face=str(assignment.get("definition_face_id","Unassigned"))
			label(properties,("Support" if key=="support" else "Force")+": "+reference_face.left(16)+"... / "+str(assignment.get("state","unassigned"))).tooltip_text=reference_face
			if key=="load_face":label(properties,"Global force (N): "+str(p.force))
			if assignment.get("state")=="unresolved":label(properties,"UNRESOLVED: "+str(assignment.get("reason","Select replacement")).left(64)).tooltip_text=str(assignment.get("reason","Select replacement"))
			var action_row=HBoxContainer.new();properties.add_child(action_row)
			button(action_row,("Reassign " if assignment.get("state")=="unresolved" else "Assign ")+("support" if key=="support" else "force"),func():
				if face.selected<0:report("Wait for verified native faces");return
				var target=face.get_item_text(face.selected)
				run_command("ApplySupport" if key=="support" else "ApplyLoad",{"face":target,"force":current_force()}))
			button(action_row,"Clear "+("support" if key=="support" else "force"),func():run_command("RemoveCondition",{"key":key}))

	properties = property_section(inspector_root,"Dimensions В· mm",true)
	if p.kind in ["Box","Cylinder","Sphere","Pipe"]:
		button(properties,"Validate native BRep...",func():
			var panel=load("res://ui/cae/cad_validation_panel.gd").new();add_child(panel);panel.configure(self,p);panel.popup_centered())
	if p.kind == "CAD":
		for i in 3:label(properties,["X extent: ","Y extent: ","Z extent: "][i]+str(snappedf(float(p.dimensions[i])*1000.0,0.001))+" mm")
		label(properties,"OCC volume: "+str(p.get("cad_volume",0.0))+" m³")
		label(properties,"Native validation: "+str(p.get("cad_validation",{}).get("status","inconclusive")))
		label(properties,"Native face history: "+str(p.get("cad_topology_metadata",{}).get("native_history",false)))
		button(properties,"Validate native BRep...",func():
			var panel=load("res://ui/cae/cad_validation_panel.gd").new();add_child(panel);panel.configure(self,p);panel.popup_centered())
		if not p.get("cad_pending_boundaries",{}).is_empty():label(properties,"NEEDS REVIEW: "+str(p.cad_pending_boundaries.keys()))
		var topology_picker=OptionButton.new()
		var topology_faces: Array=p.get("cad_topology_metadata",{}).get("faces",[])
		for record in topology_faces:topology_picker.add_item(str(record.state)+": "+str(record.identity))
		if not topology_faces.is_empty():
			properties.add_child(topology_picker)
			topology_picker.item_selected.connect(func(index):
				face.select(p.cad_faces.find(topology_faces[index].identity));show_selected_face())
		else:topology_picker.free()
		for archived in p.get("cad_boundary_archive",[]):
			label(properties,"Previous boundary: "+str(archived))
		label(properties,"CAD surfaces: "+str(p.get("cad_faces",[]).size()))
		label(properties,"Source identity: "+p.name+" / "+str(p.get("cad_sha256","")))
		if p.has("cad_model"):
			button(properties,"Edit CAD features...",func():open_cad_boolean(true))
			label(properties,"Topology review: "+str(p.get("cad_topology_review",{})))
			for feature in p.cad_model.nodes:
				if feature.type=="STEP":label(properties,"STEP input: "+str(feature.get("source_name","embedded"))+" / "+str(feature.get("source_units","unverified"))+" / "+str(feature.get("source_sha256","")))
		label(properties,"STEP source: "+str(p.get("cad_source_units","unverified"))+" → m")
	elif p.kind == "Box":
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
		if p.kind=="CAD" and key=="scale":continue
		properties = property_section(inspector_root,key.capitalize() + (" В· mm" if key=="position" else " В· degrees" if key=="rotation" else " В· ratio"),key=="position")
		for i in 3:
			bound_field(["X","Y","Z"][i],func(part): return part.get(key,[1,1,1] if key=="scale" else [0,0,0])[i]*(1000 if key=="position" else 180/PI if key=="rotation" else 1),{"position":"SetPosition","rotation":"SetRotation","scale":"SetScale"}[key],func(value):
				var values: Array=document.data.parts[selected].get(key,[1,1,1] if key=="scale" else [0,0,0]).duplicate()
				values[i]=value/(1000 if key=="position" else 180/PI if key=="rotation" else 1)
				return {"values":values},.1,key=="scale")
	properties = property_section(inspector_root,"Material",false)
	label(properties,"Material: " + str(p.material.get("name","Unassigned")))
	if ClassDB.class_exists("UniCoreGeometryTools"):
		var validation: Dictionary = ClassDB.instantiate("UniCoreGeometryTools").validate_material(p.material,document.data.get("analysis",{}).get("type","static_structural"))
		label(properties,"Material requirements: missing " + str(validation.missing) + "; " + str(validation.errors))
	button(properties,"Material library...",open_material_library)
	if p.kind!="CAD" and ClassDB.class_exists("UniCoreGeometryTools"):
		button(properties,"Measure volume / mass",func():
			var tools = ClassDB.instantiate("UniCoreGeometryTools")
			var metrics: Dictionary = tools.measure_primitive(document.data.parts[selected])
			if metrics.get("ok",false): report("C++ geometry | volume %s mВі | area %s mВІ | mass %s kg | local centroid inertia %s kgВ·mВІ" % [metrics.volume_m3,metrics.area_m2,metrics.mass_kg,metrics.local_inertia_kg_m2])
			else: report(str(metrics.get("error","Measurement failed"))))
	var modulus:=field("E (GPa)",material_number(p.material,"E")/1e9,0,10000,.1)
	var poisson:=field("Poisson ratio",material_number(p.material,"nu"),-.99,.499,.01)
	var density:=field("Density kg/mВі",material_number(p.material,"density"),0,1e6,1)
	inspector_bindings.append({"node":modulus,"getter":func(part): return material_number(part.material,"E")/1e9})
	inspector_bindings.append({"node":poisson,"getter":func(part): return material_number(part.material,"nu")})
	inspector_bindings.append({"node":density,"getter":func(part): return material_number(part.material,"density")})
	button(properties,"Assign material",func(): run_command("AssignMaterial",{"material":{"name":"Custom","E":modulus.value*1e9,"nu":poisson.value,"density":density.value}}))
	if document.data.get("analysis",{}).get("type","static_structural")=="static_structural":
		properties = property_section(inspector_root,"Face force В· N",false)
		for i in 3: force_fields.append(field(["Fx","Fy","Fz"][i],p.force[i],-1e12,1e12,100))
	properties = inspector_root
	button(properties,"Reset property values",func(): inspector_id=""; inspect())

func clear_inspector() -> void:
	for child in properties.get_children():
		properties.remove_child(child)
		child.queue_free()
	inspector_id=""
	inspector_bindings.clear()
	force_fields.clear()

var post_timings := {}
func show_result_inspector() -> void:
	var tick:=Time.get_ticks_usec()
	clear_inspector()
	inspect_results()
	if document.data.results.has("temperature"):
		button(properties,"Pick solver node",activate_node_pick)
		button(properties,"Pick solver element",activate_element_pick)
	button(properties,"Show / hide viewport legend",toggle_viewport_legend)
	if document.data.results.is_empty(): label(properties,"No solved results")

	post_timings.inspector_ms=(Time.get_ticks_usec()-tick)/1000.0

func complete_cad_display(source: Dictionary) -> bool:
	return not source.is_empty() and document.data.parts.all(func(p):return p.kind!="CAD" or source.get("surface_regions",{}).has(p.id))

func cad_display_source() -> Dictionary:
	return document.data.mesh if complete_cad_display(document.data.mesh) else cad_preview

func render_model() -> void:
	if complete_cad_display(document.data.mesh) and document.data.parts.any(func(p):return p.kind=="CAD"):
		# One immutable display snapshot: boundary/material edits can reuse geometry.
		cad_preview={"nodes":document.data.mesh.get("nodes",[]),"surface_regions":document.data.mesh.get("surface_regions",{})}
		cad_preview_identity=preview_signature()
	if is_instance_valid(viewport_legend):viewport_legend.visible=false
	if not cad_preview.is_empty() and preview_signature()!=cad_preview_identity:cad_preview={}
	cad.set_meta("cad_mesh",cad_display_source())
	cad.sync_model(document.data.parts,selected)
	if not inspection_mode.is_empty() or not quality_metric.is_empty() or (show_results and results_current()):
		for body in cad.meshes:
			var index=document.data.parts.find_custom(func(p):return p.id==body.get_meta("part_id"))
			if index>=0 and document.data.parts[index].get("analysis_enabled",true):body.visible=false
	meshes=cad.meshes.duplicate()
	var key: Array=[document.data.revision,document.data.mesh.get("divisions",0),mesh_visible,show_results,deformation_scale,structural_wireframe,results_current(),result_identity.generation,result_field,thermal_frame,thermal_field,celsius,show_flux_arrows,quality_metric,inspection_mode,section_fraction]
	if key == overlay_key:
		if is_instance_valid(viewport_legend):viewport_legend.visible=viewport_legend_enabled and show_results and results_current()
		return
	overlay_key=key
	for child in cad.overlay_root.get_children():
		cad.overlay_root.remove_child(child)
		child.queue_free()
	selection_highlight=null
	if not inspection_mode.is_empty() and not document.data.mesh.is_empty():
		if not prepare_mesh_inspection(): return
		render_inspection()
		return
	if mesh_visible and not document.data.mesh.is_empty():
		var overlay:=MeshInstance3D.new()
		overlay.mesh=preload("res://core/cae/mesh_display.gd").boundary_edges(document.data.mesh)
		overlay.material_override=cad.line_material(Color("c2a36b"))
		cad.overlay_root.add_child(overlay)
	render_results()

func update_camera() -> void:
	cad.update_camera()
func fit_model() -> void:
	if (not inspection_mode.is_empty() or show_results) and not document.data.mesh.is_empty():
		var nodes: Array=inspection_data().nodes
		if nodes.is_empty():return
		var first: Array=nodes[0];var bounds:=AABB(Vector3(first[0],first[1],first[2]),Vector3.ZERO)
		for node in nodes:bounds=bounds.expand(Vector3(node[0],node[1],node[2]))
		cad.target=bounds.get_center();cad.distance=maxf(bounds.size.length()*1.6,0.00001);cad.update_camera()
	else:cad.fit()
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
		else:
			var error := document.open_project(path)
			report(error)
			if error.is_empty(): start_cad_preview())
	dialog.popup_centered_ratio(.7)
func import_step_dialog() -> void:
	if dialog != null: dialog.queue_free()
	dialog=FileDialog.new()
	dialog.access=FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters=PackedStringArray(["*.step,*.stp ; STEP CAD solid"])
	add_child(dialog)
	dialog.file_selected.connect(func(path: String):
		var bytes := FileAccess.get_file_as_bytes(path)
		if bytes.is_empty() or bytes.size()>64*1024*1024: report("STEP asset empty or over 64 MiB");return
		var error := document.execute("ImportSTEP",{"cad_base64":Marshalls.raw_to_base64(bytes),"cad_sha256":Document.cad_sha256(bytes),"name":path.get_file()})
		if not error.is_empty(): report(error);return
		selected=0
		document.data.analysis={"backend":"calculix","type":"static_structural","element":"TET4"}
		start_cad_preview())
	dialog.popup_centered_ratio(.7)
var cad_preview_thread: Thread
var cad_preview_worker: RefCounted
var cad_geometry_thread: Thread
var cad_geometry_job: RefCounted
var cad_geometry_receiver
var cad_geometry_signature=""
func open_cad_boolean(edit: bool=false):
	if document.data.parts.size()<(1 if edit else 2):report("Create/import "+("a body" if edit else "two bodies")+" first");return
	if selected<0:selected=0
	var panel=preload("res://ui/cae/cad_boolean_panel.gd").new()
	add_child(panel);panel.configure(self,edit);panel.popup_centered()
func start_cad_geometry(request: Dictionary, receiver):
	if cad_geometry_thread!=null or cad_preview_thread!=null or external_mesh_thread!=null or solve_thread!=null:report("Wait for the active geometry/mesh/solver job");return false
	cad_geometry_receiver=receiver;cad_geometry_job=preload("res://core/cae/cad_geometry_job.gd").new()
	cad_geometry_signature=model_signature()
	cad_geometry_thread=Thread.new()
	if cad_geometry_thread.start(func():return cad_geometry_job.evaluate(request))!=OK:cad_geometry_thread=null;report("Unable to start CAD worker")
	set_process(true)
	return cad_geometry_thread!=null
func cancel_cad_geometry():
	if cad_geometry_job!=null:cad_geometry_job.cancel()
var cad_preview_identity := ""
var cad_preview: Dictionary = {}
var cad_metadata_installing=false
func preview_signature() -> String:
	var geometry=[]
	for part in document.data.parts:
		var identity={}
		for key in ["id","instance_uuid","definition_uuid","geometry_revision","transformation_revision","cad_sha256","cad_faces","kind","dimensions","position","rotation","scale"]:identity[key]=part.get(key)
		geometry.append(identity)
	return preload("res://core/cae/mesh_fingerprint.gd").canonical(geometry)

func start_cad_preview() -> void:
	cad_preview={}
	if not document.data.parts.any(func(p):return p.kind=="CAD") or cad_preview_thread!=null:return
	var snapshot: Dictionary=document.data.duplicate(true)
	cad_preview_identity=preview_signature()
	var worker=preload("res://core/cae/cad_geometry_job.gd").new()
	cad_preview_worker=worker
	cad_preview_thread=Thread.new()
	if cad_preview_thread.start(func():
		var result=worker.evaluate({"action":"preview_assembly","parts":snapshot.parts})
		return result.get("preview",{"error":result.get("error","CAD preview failed")}))!=OK:
		cad_preview_thread=null;report("Cannot start OCC preview");return
	set_process(true)
	report("Importing placed OCC geometry for viewport preview")
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
	if cad_geometry_thread!=null:report("Wait for or cancel CAD evaluation");return
	if cad_preview_thread!=null:report("Wait for CAD preview to finish");return
	if document.data.mesh.has("mesh_settings") and not preload("res://core/cae/mesh_config.gd").current(document.data):report("Mesh settings or geometry changed: regenerate the Gmsh mesh before solving");return
	if external_mesh_thread!=null:report("Wait for meshing to finish");return
	if document.data.get("analysis",{}).get("backend","")=="calculix":
		if solve_thread!=null: report("A solve is already running");return
		native_solver=preload("res://core/cae/calculix_workbench.gd").new()
		var snapshot: Dictionary=document.data.duplicate(true)
		solve_signature=model_signature()
		solve_thread=Thread.new()
		var code=solve_thread.start(func(): return native_solver.solve_model(snapshot))
		if code!=OK: solve_thread=null;report("Cannot start CalculiX worker");return
		set_process(true)
		report("CalculiX running — indeterminate progress; Cancel stops the owned solver")
		return
	if document.data.parts.any(func(part): return part.kind in ["Cylinder","Sphere","Pipe"]):
		report("Cylinder/sphere/pipe TET4 uses the independent CPU backend. Generate mesh, then launch/import through Extreme CPU.")
		open_extreme_mode()
		return
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
	var snapshot: Dictionary = preload("res://core/cae/analysis_participation.gd").view(document.data).duplicate(true)
	solve_signature = model_signature()
	solve_thread = Thread.new()
	set_process(true)
	var error := solve_thread.start(func(): return native_solver.solve_model(snapshot))
	if error != OK:
		solve_thread = null
		set_process(not preparation_jobs.is_empty())
		report("Unable to start solve worker")
		return
	report("Solving immutable revision %s in C++..." % snapshot.revision)

func _process(_delta: float) -> void:
	if cad_geometry_thread!=null and not cad_geometry_thread.is_alive():
		var result=cad_geometry_thread.wait_to_finish()
		cad_geometry_thread=null
		if cad_geometry_signature!=model_signature():result={"ok":false,"error":"CAD result is stale: document changed during evaluation; preview again"}
		if is_instance_valid(cad_geometry_receiver):cad_geometry_receiver.completed(result)
	if cad_preview_thread!=null and not cad_preview_thread.is_alive():
		var preview: Dictionary=cad_preview_thread.wait_to_finish()
		cad_preview_thread=null
		if preview_signature()==cad_preview_identity:
			if preview.has("error"): report(str(preview.error))
			else:
				cad_preview=preview
				cad_metadata_installing=true
				for index in document.data.parts.size():
					var part=document.data.parts[index]
					var original=preview.get("source_metadata",{}).get(part.id,{})
					if original.is_empty():continue
					var error=document.execute("InitializeCADMetadata",{"index":index,"metadata":original})
					if not error.is_empty():report(error)
				cad_metadata_installing=false
				cad_preview_identity=preview_signature()
				if selected>=0 and not preview.get("source_metadata",{}).is_empty():select_body(selected)
				render_model();fit_model()
		else: start_cad_preview()
	if external_mesh_thread!=null:
		if external_mesh_thread.is_alive():
			if Time.get_ticks_msec()-_last_progress_tick>200:
				_last_progress_tick=Time.get_ticks_msec()
				report("Gmsh running — indeterminate — elapsed %.1f s" % ((Time.get_ticks_msec()-external_mesh_started)/1000.0))
			return
		var generated: Dictionary=external_mesh_thread.wait_to_finish()
		external_mesh_thread=null
		if external_mesh_signature!=JSON.stringify([document.data.parts,document.data.get("analysis",{}),divisions.value],"",true,true):report("Discarded stale Gmsh result")
		elif generated.has("error"):report(generated.error)
		else:
			document.data.mesh=generated;document.data.results={}
			if document.data.parts.size()==1 and document.data.parts[0].kind=="CAD":
				var p: Dictionary=document.data.parts[0]
				p.cad_faces=generated.surface_regions.get(p.id,{}).keys()
				face.clear()
				for title in p.cad_faces: face.add_item(title)
			document.changed.emit();show_mesh_quality();render_model()
			if generated.has("interference"):
				var messages=PackedStringArray()
				for pair in generated.interference.pairs:
					messages.append(str(pair.classification)+": "+str(pair.instances))
				report("Assembly geometry: "+"; ".join(messages))
		set_process(solve_thread!=null or not preparation_jobs.is_empty())
	poll_mesh_preparation()
	if solve_thread == null: return
	if solve_thread.is_alive():
		if native_solver.has_method("status_text"):
			if Time.get_ticks_msec()-_last_progress_tick>200:
				_last_progress_tick=Time.get_ticks_msec()
				report(native_solver.status_text())
			return
		if Time.get_ticks_msec()-_last_progress_tick>200 and native_solver.has_method("get_phase"):
			_last_progress_tick=Time.get_ticks_msec()
			var phase: int=native_solver.get_phase()
			report(["Preparing","Meshing / input validation","Boundary mapping","Sparse assembly","Linear solve","Field recovery","Complete"][clampi(phase,0,6)])
		return
	var result: Dictionary = solve_thread.wait_to_finish()
	solve_thread = null
	set_process(not preparation_jobs.is_empty())
	if not result.get("ok", false):
		report("Solve stopped: " + str(result.get("error", "Unknown failure")))
		return
	if solve_signature != model_signature():
		report("Solve completed for an older model; solve again to inspect the edited project.")
		return
	result["source_mesh_sha256"] = preload("res://core/cae/mesh_fingerprint.gd").fingerprint(document.data.mesh)
	result["mesh_fingerprint_version"] = 2
	result["model_analysis"] = document.data.get("analysis",{}).duplicate(true)
	result["model_parts"] = document.data.parts.duplicate(true)
	document.data.results = result
	inspection_mode=""
	quality_metric=""
	mesh_pick_mode=""
	inspection_mesh_key=""
	reset_mesh_selection()
	show_results = true
	result_field = "temperature" if result.has("temperature") else "von_mises" if pending_result_field=="von_mises" else "displacement"
	pending_result_field=""
	thermal_frame=-1
	show_result_inspector()
	_syncing=true
	rebuild_explorer()
	_syncing=false
	update_ribbon_availability()
	render_model()
	if result.has("temperature"):
		report("Thermal: "+Visuals.number(result.min_temperature)+" to "+Visuals.number(result.max_temperature)+" K | balance "+Visuals.number(result.energy_balance_W)+" W | Newton "+str(result.get("nonlinear_iterations",0)))
	else:
		report("%s | %s elements | residual %s | displacement %s m" % [result.backend,result.stress.size(),result.relative_residual,result.max_displacement])

func _exit_tree() -> void:
	if cad_geometry_thread!=null:
		cad_geometry_job.cancel();cad_geometry_thread.wait_to_finish();cad_geometry_thread=null
	if cad_preview_thread!=null:
		if cad_preview_worker!=null:cad_preview_worker.cancel()
		cad_preview_thread.wait_to_finish()
		cad_preview_thread=null
	if external_mesh_thread!=null:
		native_solver.cancel()
		external_mesh_thread.wait_to_finish()
	for job in preparation_jobs: job.cancel()
	for job in preparation_jobs:
		if job.thread.is_started():job.thread.wait_to_finish()
	if solve_thread != null:
		native_solver.cancel()
		solve_thread.wait_to_finish()

var result_identity=preload("res://core/cae/result_identity.gd").new()
var structural_display=preload("res://core/cae/structural_display.gd").new()
func results_current() -> bool:
	var tick:=Time.get_ticks_usec()
	var valid: bool=result_identity.current(document.data)
	post_timings.current_ms=post_timings.get("current_ms",0.0)+(Time.get_ticks_usec()-tick)/1000.0
	return valid

func render_results() -> void:
	if not show_results or not results_current(): return
	if document.data.results.has("temperature"):
		render_temperature()
		return
	var r: Dictionary = document.data.results
	var display = structural_display
	var mapped: Dictionary = display.build(r,result_field,deformation_scale)
	post_timings.structural=display.timings.duplicate(true)
	if mapped.has("error"):
		report(mapped.error)
		return
	var instance := add_inspection_mesh(mapped.mesh,Color.WHITE)
	instance.material_override=mapped.material
	var element_field=result_field=="von_mises" or result_field.begins_with("stress_") or result_field.begins_with("strain_")
	var association="4-IP tensor mean" if r.get("element_type")=="C3D10" else "integration point" if r.backend=="CalculiX 2.23" else "element"
	var unit="1" if result_field.begins_with("strain_") else "Pa" if element_field else "m"
	update_result_legend(result_field+" ("+(association if element_field else "nodal")+")",unit,mapped.low,mapped.high,"viridis","display scale "+Visuals.number(deformation_scale))
	if structural_wireframe:
		add_inspection_mesh(preload("res://core/cae/mesh_display.gd").boundary_edges(r),Color("a5b3c2"))

var structural_wireframe := false
var viewport_legend_enabled := true
var viewport_legend: PanelContainer
func update_result_legend(title: String,unit: String,low: float,high: float,palette: String,detail: String) -> void:
	if not is_instance_valid(viewport_legend):
		viewport_legend=preload("res://ui/cae/result_legend.gd").new()
		cad.add_child(viewport_legend)
		viewport_legend.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		viewport_legend.offset_left=-285;viewport_legend.offset_right=-12
		viewport_legend.offset_top=42
	viewport_legend.visible=viewport_legend_enabled
	viewport_legend.configure(title,unit,low,high,palette,detail)
func toggle_viewport_legend() -> void:
	viewport_legend_enabled=not viewport_legend_enabled
	if is_instance_valid(viewport_legend):viewport_legend.visible=viewport_legend_enabled and show_results and results_current()
	cad.invalidate()

func automatic_deformation_scale() -> float:
	var r: Dictionary=document.data.results
	var maximum: float=r.get("max_displacement",0)
	if maximum<=0 or not is_finite(maximum):return 1.0
	var lo:=Vector3(INF,INF,INF);var hi:=-lo
	for p in r.nodes:
		var v:=Vector3(p[0],p[1],p[2]);lo=Vector3(minf(lo.x,v.x),minf(lo.y,v.y),minf(lo.z,v.z));hi=Vector3(maxf(hi.x,v.x),maxf(hi.y,v.y),maxf(hi.z,v.z))
	return 0.1*(hi-lo).length()/maximum


func inspect_results() -> void:
	if document.data.results.has("temperature"):
		inspect_thermal_results()
		return
	if document.data.get("results", {}).is_empty(): return
	label(properties, "RESULTS" + ("" if results_current() else " / OUTDATED"))
	if not results_current(): return
	var r: Dictionary = document.data.results
	button(properties,"Pick solver node",func():activate_mesh_pick("node"))
	button(properties,"Pick solver element",func():activate_mesh_pick("element"))
	var quadratic=r.get("element_type")=="C3D10"
	label(properties, "Nodal displacement: m\nElement stress: Pa ("+("4-IP tensor mean" if quadratic else "unaveraged")+")\nEngineering strain: dimensionless; shear = gamma\nOrder: "+("xx, yy, zz, xy, xz, yz" if r.backend=="CalculiX 2.23" else "xx, yy, zz, xy, yz, xz"))
	if r.backend=="CalculiX 2.23":
		var fields:=OptionButton.new()
		var names=["displacement","ux","uy","uz","von_mises","stress_xx","stress_yy","stress_zz","stress_xy","stress_xz","stress_yz","strain_xx","strain_yy","strain_zz","strain_xy","strain_xz","strain_yz"]
		for name in names: fields.add_item(name)
		fields.select(maxi(0,names.find(result_field)))
		properties.add_child(fields)
		fields.item_selected.connect(func(index): select_result_field(names[index]))
	var display = structural_display
	var bounds: Dictionary = display.bounds(display.values(r,result_field))
	if not bounds.is_empty():
		var elemental=result_field=="von_mises" or result_field.begins_with("stress_") or result_field.begins_with("strain_")
		var association="arithmetic mean of 4 IP tensors" if r.get("element_type")=="C3D10" else "integration point, unaveraged"
		numerical_legend(properties,result_field+": "+(association if elemental else "nodal"),bounds.low,bounds.high,"1" if result_field.begins_with("strain_") else "Pa" if elemental else "m","viridis")
	if r.get("element_type")=="C3D10":label(properties,"C3D10: all 4 integration-point tensors retained; displayed stress/strain uses their arithmetic tensor mean. No nodal averaging.")
	label(properties,"Display scale does not change physical displacement. 0: undeformed; 1: true scale.")
	var wire := CheckButton.new()
	wire.text="Undeformed wireframe overlay"
	wire.button_pressed=structural_wireframe
	properties.add_child(wire)
	wire.toggled.connect(func(value): structural_wireframe=value; render_model())
	button(properties,"Automatic display scale (10% diagonal)",func(): deformation_scale=automatic_deformation_scale(); render_model(); show_result_inspector())
	button(properties,"True scale",func(): deformation_scale=1.0; render_model(); show_result_inspector())
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
		if command not in ["CreatePart","SetParameters","SetPosition","SetRotation","SetScale","AssignMaterial","Rename","Duplicate","Delete","SetVisibility","SetAnalysisEnabled","ApplySupport","ApplyLoad","ApplyPressure","ApplyDisplacement","ApplyGravity","AssignMaterialById","SetAnalysis","ApplyThermalBoundary","SetHeatSource"]: return "Unsupported engineering command: " + command
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
	if event.ctrl_pressed and event.keycode == KEY_K:
		open_tool_browser()
		get_viewport().set_input_as_handled()
		return
	var focus:=get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit: return
	if event.ctrl_pressed and event.keycode==KEY_Z:
		if event.shift_pressed: document.redo()
		else: document.undo()
	elif event.ctrl_pressed and event.keycode==KEY_Y: document.redo()
	elif event.ctrl_pressed and event.keycode==KEY_S: file_dialog(true)
	elif event.keycode==KEY_DELETE: confirm_delete()
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
var last_extreme_directory := ""
var result_field := "displacement"
var thermal_frame := -1
func open_analysis_editor() -> void:
	if selected<0: report("Select a body to configure analysis conditions"); return
	if analysis_editor!=null: analysis_editor.queue_free()
	analysis_editor=preload("res://ui/cae/analysis_editor.gd").new()
	analysis_editor.surface_names=Document.surface_names(document.data.parts[selected])
	analysis_editor.settings=document.data.get("analysis",{}).duplicate(true)
	add_child(analysis_editor)
	analysis_editor.study_chosen.connect(func(settings): report(document.execute("SetAnalysis",{"analysis":settings})))
	analysis_editor.condition_requested.connect(apply_dialog_condition)
	analysis_editor.popup_centered(Vector2i(540,600))
func apply_dialog_condition(settings: Dictionary,command: String,args: Dictionary) -> void:
	args.index=selected
	report(document.execute("ApplyStudyBoundary",{"analysis":settings,"command":command,"arguments":args}))

var external_mesh_thread: Thread
var external_mesh_signature := ""
var external_mesh_started := 0
func generate_analysis_mesh() -> void:
	if cad_geometry_thread!=null:report("Wait for or cancel CAD evaluation");return
	if document.data.get("analysis",{}).get("backend","")=="calculix" or document.data.parts.any(func(p):return p.has("mesh_settings")):
		if external_mesh_thread!=null or solve_thread!=null:report("An operation is already running");return
		var smallest=INF
		for part in document.data.parts:
			for value in part.dimensions: smallest=minf(smallest,value)
		native_solver=preload("res://core/cae/calculix_workbench.gd").new()
		var snapshot=document.data.duplicate(true)
		var size=(0.1 if document.data.parts.size()==1 and document.data.parts[0].kind=="CAD" else smallest)/maxf(1,divisions.value)
		external_mesh_signature=JSON.stringify([document.data.parts,document.data.get("analysis",{}),divisions.value],"",true,true)
		external_mesh_started=Time.get_ticks_msec()
		external_mesh_thread=Thread.new()
		var code=external_mesh_thread.start(func():return native_solver.generate_mesh(snapshot,size))
		if code!=OK:external_mesh_thread=null;report("Cannot start Gmsh worker");return
		set_process(true);report("Gmsh queued");return
	var error: String=document.generate_mesh(int(divisions.value))
	if not error.is_empty(): report(error)
	else: show_mesh_quality()
func show_mesh_quality() -> void:
	if document.data.mesh.is_empty(): report("Generate an analysis mesh first"); return
	var mesh: Dictionary=document.data.mesh
	var quality: Dictionary=mesh.get("quality",{})
	if quality.is_empty(): report("%d nodes В· %d base cells В· quality report unavailable" % [mesh.nodes.size(),mesh.elements.size()]); return
	report("%d nodes В· %d base cells В· min Jacobian %s mВі В· inverted %d В· degenerate %d" % [mesh.nodes.size(),mesh.elements.size(),Visuals.number(quality.get("minimum_jacobian",0)),quality.get("inverted_elements",0),quality.get("degenerate_elements",0)])
func select_result_field(field: String) -> void:
	if not results_current(): report("Solve the current revision first"); return
	if field=="temperature" and not document.data.results.has("temperature"): report("No thermal result in this study"); return
	if field!="temperature" and document.data.results.has("temperature"): report("This study contains thermal fields"); return
	result_field=field
	inspection_mode=""
	quality_metric=""
	mesh_pick_mode=""
	show_results=true
	render_model()
	show_result_inspector()
	var elemental=field=="von_mises" or field.begins_with("stress_") or field.begins_with("strain_")
	var units="1, derived engineering strain" if field.begins_with("strain_") else "Pa" if elemental else "K" if field=="temperature" else "m"
	var association=", 4-IP tensor mean" if elemental and document.data.results.get("element_type")=="C3D10" else ", element integration point" if elemental else ""
	report("Showing actual "+field+" ("+units+association+")")
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
func thermal_values() -> Array:
	var r: Dictionary=document.data.results
	return r.history[thermal_frame] if thermal_frame>=0 and thermal_frame<r.get("history",[]).size() else r.temperature
func render_temperature() -> void:
	var r: Dictionary=document.data.results
	var key := str(result_identity.generation)
	if thermal_display_key!=key:
		thermal_display.prepare(r);thermal_display_key=key
	if thermal_field in ["radiative_heat_flux","surface_emissivity"]:
		var surface_values: Array=r.get(thermal_field,[])
		if thermal_field=="radiative_heat_flux" and thermal_frame>=0:
			if thermal_frame>=r.get("radiative_heat_flux_history",[]).size():report("Historical radiation unavailable; solve again");return
			surface_values=r.radiative_heat_flux_history[thermal_frame]
		if surface_values.is_empty(): report("No radiation fields in this result");return
		var active_values:=[]
		for i in surface_values.size():
			if r.surface_emissivity[i]>0:active_values.append(surface_values[i])
		if active_values.is_empty():report("No enabled radiating faces");return
		var lower: float=active_values.min();var upper: float=active_values.max()
		if is_finite(thermal_low) and is_finite(thermal_high) and thermal_high>thermal_low:lower=thermal_low;upper=thermal_high
		add_inspection_mesh(thermal_display.radiation_surface(r,thermal_field,lower,upper,surface_values),Color.WHITE)
		return
	var temperatures: Array=thermal_values()
	var values: Array=temperatures
	var is_flux := thermal_field=="heat_flux"
	if is_flux:
		values=[]
		for q in thermal_flux_values(): values.append(Vector3(q[0],q[1],q[2]).length())
	if values.is_empty(): report("Historical heat flux unavailable in this saved result; solve again");return
	var lo: float=values.min();var hi: float=values.max()
	if fixed_thermal_scale and not is_flux:
		for frame in r.get("history",[]): lo=minf(lo,frame.min());hi=maxf(hi,frame.max())
	if is_finite(thermal_low) and is_finite(thermal_high) and thermal_high>thermal_low: lo=thermal_low;hi=thermal_high
	var instance:=add_inspection_mesh(thermal_display.surface(r,values,lo,hi,"viridis" if is_flux else thermal_palette,is_flux,contour_bands,str(thermal_frame)+thermal_field+thermal_palette+str(lo)+str(hi)+str(contour_bands)),Color.WHITE)
	var material_key:=thermal_field+thermal_palette+str(lo)+str(hi)+str(contour_bands)
	var material: ShaderMaterial=thermal_display.material_cache.get(material_key)
	if material==null:
		material=ShaderMaterial.new();material.shader=preload("res://shaders/cae_scalar.gdshader")
		var gradient:=Gradient.new();var palette:= "viridis" if is_flux else thermal_palette
		gradient.set_color(0,Visuals.color(0,0,1,palette));gradient.set_color(1,Visuals.color(1,0,1,palette))
		for i in range(1,32):gradient.add_point(i/32.0,Visuals.color(i/32.0,0,1,palette))
		var texture:=GradientTexture1D.new();texture.gradient=gradient;texture.width=512
		material.set_shader_parameter("color_map",texture);material.set_shader_parameter("lower",lo);material.set_shader_parameter("upper",lo if hi-lo<maxf(absf(lo),absf(hi))*1e-6 else hi);material.set_shader_parameter("bands",contour_bands)
		if thermal_display.material_cache.size()>=16:thermal_display.material_cache.erase(thermal_display.material_cache.keys()[0])
		thermal_display.material_cache[material_key]=material
	instance.material_override=material
	post_timings.thermal=thermal_display.timings.duplicate(true)
	update_result_legend("Conductive flux (element)" if is_flux else "Temperature (nodal)","W/m^2" if is_flux else "K",lo,hi,"viridis" if is_flux else thermal_palette,"t="+str(r.times[thermal_frame])+" s" if thermal_frame>=0 else "final state")
	if show_flux_arrows and not thermal_flux_values().is_empty(): add_inspection_mesh(thermal_display.arrows(r,thermal_flux_values(),flux_stride,flux_scale,normalize_flux),Color("f1e8c8"))
	if thermal_isolines>0 and not is_flux: add_inspection_mesh(thermal_display.isolines(r,values,lo,hi,thermal_isolines),Color("c4ccd3"))
	if not is_flux:
		for id in [temperatures.find(temperatures.min()),temperatures.find(temperatures.max())]:
			var marker := Label3D.new(); marker.text=Visuals.number(temperatures[id]-(273.15 if celsius else 0))+ (" C" if celsius else " K")
			marker.no_depth_test=true;marker.position=thermal_display.point(r,id);marker.billboard=BaseMaterial3D.BILLBOARD_ENABLED;marker.font_size=22;marker.pixel_size=0.0005
			cad.overlay_root.add_child(marker)
func thermal_flux_values() -> Array:
	var r: Dictionary=document.data.results
	if thermal_frame>=0 and thermal_frame<r.get("heat_flux_history",[]).size(): return r.heat_flux_history[thermal_frame]
	if thermal_frame>=0 and not r.get("history",[]).is_empty(): return []
	return r.heat_flux

func inspect_thermal_results() -> void:
	if not results_current(): label(properties,"Thermal result is outdated"); return
	var thermal_panel_root := properties
	var r: Dictionary=document.data.results
	label(properties,"TEMPERATURE / HEAT FLUX")
	if not r.get("warnings",[]).is_empty(): label(properties,"Material review: " + str(r.warnings))
	label(properties,"Energy imbalance: "+Visuals.number(r.energy_balance_W)+" W; residual "+Visuals.number(r.relative_residual))
	properties=fold_section(thermal_panel_root,"Display settings",false)
	var palette_select:=OptionButton.new()
	for name in ["temperature","viridis","cividis","diverging"]:palette_select.add_item(name)
	palette_select.select(["temperature","viridis","cividis","diverging"].find(thermal_palette));properties.add_child(palette_select)
	palette_select.item_selected.connect(func(i):thermal_palette=palette_select.get_item_text(i);redraw_thermal();show_result_inspector())
	button(properties,"Kelvin / Celsius",func(): celsius=not celsius;redraw_thermal();show_result_inspector())
	button(properties,"Temperature / heat-flux magnitude",func(): thermal_field="heat_flux" if thermal_field=="temperature" else "temperature";redraw_thermal())
	button(properties,"Heat-flux arrows",func(): show_flux_arrows=not show_flux_arrows;redraw_thermal())
	button(properties,"Normalize arrows",func(): normalize_flux=not normalize_flux;redraw_thermal())
	var density:=field("Arrow stride",flux_stride,1,10000,1)
	density.value_changed.connect(func(v): flux_stride=int(v);redraw_thermal())
	var scale:=field("Arrow maximum length (m)",flux_scale,0.00001,1000,0.001)
	scale.value_changed.connect(func(v): flux_scale=v;redraw_thermal())
	var isolines:=field("Temperature isolines",thermal_isolines,0,20,1)
	isolines.value_changed.connect(func(v): thermal_isolines=int(v);redraw_thermal())
	button(properties,"Fixed / per-frame range",func(): fixed_thermal_scale=not fixed_thermal_scale;redraw_thermal())
	var minimum:=field("Display minimum",0 if not is_finite(thermal_low) else thermal_low,-1e12,1e12,0.1)
	var maximum:=field("Display maximum",1000 if not is_finite(thermal_high) else thermal_high,-1e12,1e12,0.1)
	button(properties,"Apply physical color range",func():
		if maximum.value<=minimum.value:report("Maximum must exceed minimum");return
		var shift:=273.15 if celsius and thermal_field=="temperature" else 0.0
		thermal_low=minimum.value+shift;thermal_high=maximum.value+shift;redraw_thermal();show_result_inspector())
	button(properties,"Automatic range",func():thermal_low=NAN;thermal_high=NAN;redraw_thermal();show_result_inspector())
	label(properties,"Temperature range uses display K/C; flux uses W/m^2. Stored solver values stay SI.")
	properties=fold_section(thermal_panel_root,"Numerical legend",true)
	var temperatures: Array=thermal_values()
	var shift:=273.15 if celsius else 0.0
	var range_low: float=temperatures.min();var range_high: float=temperatures.max()
	if fixed_thermal_scale:
		for frame in r.get("history",[]):range_low=minf(range_low,frame.min());range_high=maxf(range_high,frame.max())
	if is_finite(thermal_low) and is_finite(thermal_high):range_low=thermal_low;range_high=thermal_high
	if thermal_field=="radiative_heat_flux" and not r.get("radiative_heat_flux",[]).is_empty():
		var radiation_values:=[]
		for i in r.radiative_heat_flux.size():
			if r.surface_emissivity[i]>0:radiation_values.append(r.radiative_heat_flux[i])
		if not radiation_values.is_empty():numerical_legend(properties,"Radiative flux (outward positive)",radiation_values.min(),radiation_values.max(),"W/m^2","temperature")
	elif thermal_field=="heat_flux":
		var magnitudes:=[]
		for q in thermal_flux_values():magnitudes.append(Vector3(q[0],q[1],q[2]).length())
		if not magnitudes.is_empty():numerical_legend(properties,"Conductive flux magnitude, element-centered",magnitudes.min(),magnitudes.max(),"W/m^2","viridis")
	elif thermal_field=="surface_emissivity" and not r.get("surface_emissivity",[]).is_empty():numerical_legend(properties,"Surface emissivity",r.surface_emissivity.min(),r.surface_emissivity.max(),"1","temperature")
	else:numerical_legend(properties,"Nodal temperature; linear face interpolation",range_low-shift,range_high-shift,"C" if celsius else "K",thermal_palette)
	label(properties,"Radiative flux: gray diffuse surface integration, outward positive. Conductive flux is a separate field." if thermal_field=="radiative_heat_flux" else "Heat flux: element-centered -k grad(T), W/m^2. No averaging across materials.")
	properties=fold_section(thermal_panel_root,"Radiation / heat balance",false)
	if r.has("radiative_heat_flux"):
		button(properties,"Radiative heat flux",func(): thermal_field="radiative_heat_flux";redraw_thermal())
		button(properties,"Surface emissivity",func(): thermal_field="surface_emissivity";redraw_thermal())
		label(properties,"Heat balance (W)\nApplied: "+Visuals.number(r.heat_input_W)+"\nConvection out: "+Visuals.number(r.convection_loss_W)+"\nRadiation out: "+Visuals.number(r.radiation_loss_W)+"\nStorage: "+Visuals.number(r.storage_rate_W))
		label(properties,"Radiation groups (W): "+str(r.radiation_group_power_W)+"\nNewton iterations: "+str(r.nonlinear_iterations))
		if not r.radiative_heat_flux.is_empty():numerical_legend(properties,"Radiative heat flux (outward positive)",r.radiative_heat_flux.min(),r.radiative_heat_flux.max(),"W/m^2","temperature")
	properties=fold_section(thermal_panel_root,"Probes / time history",true)
	var node:=field("Probe node",0,0,r.nodes.size()-1,1)
	var element:=field("Probe element",0,0,r.heat_flux.size()-1,1)
	var gradient_readout:=label(properties,"")
	var show_gradient:=func(_v=0):
		if r.has("temperature_gradient"):gradient_readout.text="Final grad(T), K/m: "+str(r.temperature_gradient[int(element.value)])
	element.value_changed.connect(show_gradient);show_gradient.call()
	var value:=label(properties,"")
	var update:=func(_v=0): value.text="Temperature: %s K\nHeat flux: %s W/mВІ" % [thermal_values()[int(node.value)]-(273.15 if celsius else 0),thermal_flux_values()[int(element.value)] if not thermal_flux_values().is_empty() else "Unavailable for historical frame"]
	node.value_changed.connect(update)
	element.value_changed.connect(update)
	update.call()
	if not r.get("history",[]).is_empty():
		button(properties,"Play / pause",toggle_thermal_playback)
		var speed:=field("Playback speed",playback_speed,0.1,20,0.1)
		speed.value_changed.connect(func(v):playback_speed=v)
		var graph=preload("res://ui/cae/probe_history.gd").new();graph.custom_minimum_size=Vector2(180,70);graph.times=r.times
		for frame in r.history:graph.values.append(frame[int(node.value)]-(273.15 if celsius else 0))
		label(properties,"Probe history: temperature ("+("C" if celsius else "K")+") vs time (s); stored states, no time interpolation")
		label(properties,"Time: "+Visuals.number(r.times[0])+" to "+Visuals.number(r.times[-1])+" s")
		properties.add_child(graph)
		node.value_changed.connect(func(v):
			graph.values=[]
			for frame in r.history:graph.values.append(frame[int(v)]-(273.15 if celsius else 0))
			graph.queue_redraw())
		var step:=field("History frame",r.history.size()-1,0,r.history.size()-1,1)
		var temperature_label:=label(properties,"")
		step.value_changed.connect(func(index):
			thermal_frame=int(index)
			var values: Array=r.history[thermal_frame]
			temperature_label.text="t=%s s; T(probe)=%s K; blue %s K в†’ red %s K. Flux uses the selected computed frame." % [r.times[thermal_frame],values[int(node.value)],values.min(),values.max()]
			render_model())
	properties=thermal_panel_root


func inspection_data() -> Dictionary:
	# Thermal solving subdivides HEX8 mesher cells into TET4. Inspect solver connectivity.
	var mesh: Dictionary=document.data.mesh
	if results_current() and document.data.results.has("elements"):
		var result: Dictionary=document.data.results
		var actual: Dictionary=mesh.duplicate(false)
		actual.nodes=result.nodes
		actual.elements=result.elements
		actual.formulation="TET10" if not result.elements.is_empty() and result.elements[0].size()==10 else "TET4" if not result.elements.is_empty() and result.elements[0].size()==4 else "HEX8"
		var regions: Array=[]
		var source: Array=mesh.get("material_regions",[])
		var subdivisions: int=result.elements.size()/maxi(1,mesh.elements.size())
		for region in source:
			for i in subdivisions: regions.append(region)
		actual.material_regions=regions
		return actual
	return mesh

func prepare_mesh_inspection() -> bool:
	var key := str(document.data.revision) + ":" + str(document.data.mesh.get("divisions",0)) + ":" + str(document.data.mesh.get("nodes",[]).size()) + ":" + str(results_current())
	key += ":" + str(section_fraction)
	if key!=inspection_mesh_key:
		if document.data.mesh.elements.size()>128:
			if preparation_key!=key:
				for job in preparation_jobs: job.cancel()
				preparation_generation+=1
				var job=preload("res://core/cae/mesh_prepare_job.gd").new()
				preparation_key=key
				if not inspection_mesh_key.is_empty() and inspection_mesh_key.substr(0,inspection_mesh_key.rfind(":"))==key.substr(0,key.rfind(":")):
					job.reuse={"metrics":mesh_inspection.metrics,"connectivity":mesh_inspection.connectivity,"statistics":mesh_inspection.statistics,"records":mesh_inspection.full_records,"bvh":mesh_inspection.full_bvh}
				job.metric=quality_metric if not quality_metric.is_empty() else "jacobian"
				job.palette=color_palette
				job.start(inspection_data(),preparation_generation,section_fraction,true)
				preparation_jobs.append(job)
				set_process(true)
			return false
		mesh_inspection.prepare(inspection_data())
		inspection_mesh_key=key
		mesh_inspection.section(section_fraction)
		reset_mesh_selection()
	return true

func set_mesh_display(metric: String) -> void:
	if metric in ["","edges"]:
		set_inspection_mode("solid" if metric.is_empty() else "combined")
	else:
		quality_metric=metric
		set_inspection_mode("quality")

func inspect_mesh_click(screen: Vector2) -> void:
	if document.data.mesh.is_empty(): return
	if not prepare_mesh_inspection(): return
	var hit: Dictionary=mesh_inspection.pick(camera,screen,mesh_pick_mode=="node",inspection_mode=="invalid")
	if hit.is_empty(): return
	if mesh_pick_mode=="node" and hit.node_distance>maxf(14.0,cad.size.y*0.018): return
	var picked_mesh: Dictionary=inspection_data()
	var owners: Array=picked_mesh.get("material_regions",[])
	if owners.size()>hit.element:
		for i in document.data.parts.size():
			if document.data.parts[i].id==str(owners[hit.element]):
				selected=i
				_syncing=true
				if i<tree_items.size(): tree_items[i].select(0)
				_syncing=false
	highlight_mesh_entity(hit)
	if show_results:show_result_inspector()
	else:inspection_controls()
	var inspector_root := properties
	var details := VBoxContainer.new()
	properties.add_child(details)
	properties.move_child(details,0)
	properties=details
	var mesh: Dictionary=mesh_inspection.data
	var cell: Array=mesh.elements[hit.element]
	label(properties,"Element %d В· %s (zero-based IDs)" % [hit.element,"TET10" if cell.size()==10 else "TET4" if cell.size()==4 else "HEX8"])
	label(properties,"Connectivity: " + str(cell))
	if mesh_pick_mode=="node":
		label(properties,"Connected elements: " + str(mesh_inspection.connectivity[hit.node]))
		var node_regions := {}
		for element in mesh_inspection.connectivity[hit.node]:
			if element<mesh.get("material_regions",[]).size(): node_regions[str(mesh.material_regions[element])]=true
		label(properties,"Associated material regions: " + str(node_regions.keys()))
		if results_current() and document.data.results.has("temperature"): label(properties,"Temperature: "+Visuals.number(thermal_values()[hit.node]-(273.15 if celsius else 0))+(" C" if celsius else " K"))
		var p: Vector3=mesh_inspection.point(hit.node)
		label(properties,"Node %d\nCoordinates (m): %s, %s, %s" % [hit.node,Visuals.number(p.x),Visuals.number(p.y),Visuals.number(p.z)])
	if results_current():
		var r: Dictionary=document.data.results
		if r.has("displacement"):
			var id: int=hit.node
			label(properties,"Stored solver node %d: u (m) = %s" % [id,str(r.displacement[id])])
			var p: Array=r.nodes[id];var u: Array=r.displacement[id]
			label(properties,"Original (m): "+str(p)+"; displayed (m): "+str([p[0]+deformation_scale*u[0],p[1]+deformation_scale*u[1],p[2]+deformation_scale*u[2]]))
			label(properties,"Stored element stress (Pa): "+str(r.stress[hit.element])+"; von Mises (Pa): "+str(r.von_mises[hit.element]))
			if r.get("element_type")=="C3D10":
				label(properties,"Displayed tensor is the arithmetic mean of four IP tensors; von Mises is evaluated from that mean.")
				for ip in 4:label(properties,"IP %d stress (Pa), xx yy zz xy xz yz: %s" % [ip+1,str(r.stress_integration_points[hit.element][ip])])
				label(properties,"Engineering strain from elastic compliance (shear gamma): "+str(r.strain[hit.element]))
		if r.has("heat_flux"):
			var q: Array=thermal_flux_values()[hit.element]
			label(properties,"Stored element flux (W/m^2): "+str(q)+"; magnitude: "+str(Vector3(q[0],q[1],q[2]).length()))
	var region: String=str(mesh.get("material_regions",[])[hit.element]) if mesh.get("material_regions",[]).size()>hit.element else "Unavailable"
	label(properties,"Body / material region: " + region)
	for part in document.data.parts:
		if str(part.id)==region: label(properties,"Material: " + str(part.get("material",{}).get("name","Unspecified")))
	var groups: Array=[]
	for body in mesh.get("regions",{}):
		for group in mesh.regions[body]:
			var contains := true
			for id in ([hit.node] if mesh_pick_mode=="node" else hit.face):
				if not mesh.regions[body][group].has(id): contains=false
			if contains: groups.append(str(body)+" / "+str(group))
	label(properties,"Boundary groups: " + (", ".join(groups) if not groups.is_empty() else "None"))
	var q: Dictionary=mesh_inspection.metrics[hit.element]
	for key in ["jacobian","jacobian_max","scaled_jacobian","volume","edge_ratio","mean_ratio","distortion"]:
		label(properties,"%s: %s%s" % [key,Visuals.number(q[key])," m^3" if key in ["jacobian","jacobian_max","volume"] else ""])
	label(properties,"Inverted: %s В· Degenerate: %s" % [q.inverted,q.degenerate])
	properties=inspector_root

func set_inspection_mode(mode: String) -> void:
	if document.data.mesh.is_empty(): report("Generate an analysis mesh first"); return
	inspection_mode=mode
	show_results=false
	mesh_pick_mode="node" if mode=="nodes" else "element"
	if quality_metric.is_empty(): quality_metric="jacobian"
	overlay_key=[]
	render_model()
	inspection_controls()
	cad.invalidate()

func add_inspection_mesh(mesh: Mesh, color: Color, points := false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh=mesh
	var material := StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=color
	material.vertex_color_use_as_albedo=true
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material.use_point_size=points
	material.point_size=7.0 if points else 1.0

	instance.material_override=material
	cad.overlay_root.add_child(instance)
	return instance

func render_inspection() -> void:
	if inspection_mode in ["solid","combined","elements","nodes"]:
		add_inspection_mesh(mesh_inspection.geometry("solid"),Color("536d86"))
	if inspection_mode in ["wireframe","combined","elements"]:
		add_inspection_mesh(mesh_inspection.geometry("edges"),Color("c2a36b"))
	if inspection_mode=="nodes": add_inspection_mesh(mesh_inspection.geometry("nodes"),Color("80d7ff"),true)
	if inspection_mode in ["quality","invalid"]:
		add_inspection_mesh(mesh_inspection.contour(quality_metric,inspection_mode=="invalid",color_palette,contour_low,contour_high,contour_bands).mesh,Color.WHITE)

func reset_mesh_selection() -> void:
	if is_instance_valid(selection_highlight): selection_highlight.queue_free()
	selection_highlight=null

func highlight_mesh_entity(hit: Dictionary) -> void:
	var highlight_start:=Time.get_ticks_usec()
	reset_mesh_selection()
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_POINTS if mesh_pick_mode=="node" else Mesh.PRIMITIVE_LINES)
	if mesh_pick_mode=="node": mesh.surface_add_vertex(mesh_inspection.point(hit.node))
	else:
		var cell: Array=mesh_inspection.data.elements[hit.element]
		var edges: Array=[[0,1],[1,2],[2,0],[0,3],[1,3],[2,3]] if cell.size()==4 else [[0,1],[1,2],[2,3],[3,0],[4,5],[5,6],[6,7],[7,4],[0,4],[1,5],[2,6],[3,7]]
		if cell.size()==10:edges=[[0,4],[4,1],[1,5],[5,2],[2,6],[6,0],[0,7],[7,3],[1,8],[8,3],[2,9],[9,3]]
		for edge in edges:
			if not mesh_inspection.point(cell[edge[0]]).is_finite() or not mesh_inspection.point(cell[edge[1]]).is_finite(): continue
			for corner in edge: mesh.surface_add_vertex(mesh_inspection.point(cell[corner]))
	mesh.surface_end()
	selection_highlight=add_inspection_mesh(mesh,Color("00ffff"),mesh_pick_mode=="node")
	selection_highlight.material_override.no_depth_test=true
	selection_highlight.set_meta("element",hit.element)
	mesh_inspection.timings.highlight_ms=(Time.get_ticks_usec()-highlight_start)/1000.0
	cad.invalidate()

func inspection_controls() -> void:
	if document.data.mesh.is_empty(): return
	if not prepare_mesh_inspection(): return
	clear_inspector()
	var panel_root := properties
	label(properties,"MESH INSPECTION",true)
	properties=fold_section(panel_root,"Display settings",true)
	var modes := OptionButton.new()
	var names := ["solid","wireframe","combined","nodes","elements","quality","invalid"]
	for name in names: modes.add_item(name.capitalize())
	modes.select(maxi(0,names.find(inspection_mode)))
	properties.add_child(modes)
	modes.item_selected.connect(func(i): set_inspection_mode(names[i]))
	var metrics := OptionButton.new()
	var keys := ["jacobian","scaled_jacobian","volume","edge_ratio","mean_ratio","distortion"]
	if document.data.mesh.get("formulation")=="TET10":keys=["quadratic_quality","jacobian","volume","edge_ratio","mean_ratio"]
	for key in keys: metrics.add_item(mesh_inspection.metric_label(key))
	metrics.select(maxi(0,keys.find(quality_metric)))
	properties.add_child(metrics)
	metrics.item_selected.connect(func(i): quality_metric=keys[i]; set_inspection_mode("quality"))
	var picking := OptionButton.new()
	for title in ["Element selection","Node selection"]: picking.add_item(title)
	picking.select(1 if mesh_pick_mode=="node" else 0)
	properties.add_child(picking)
	picking.item_selected.connect(func(i): mesh_pick_mode="node" if i==1 else "element")
	properties=fold_section(panel_root,"Advanced display / section",false)
	var palettes := OptionButton.new()
	for name in ["viridis","diverging","temperature","cividis"]: palettes.add_item(name)
	palettes.select(["viridis","diverging","temperature","cividis"].find(color_palette))
	properties.add_child(palettes)
	palettes.item_selected.connect(func(i): color_palette=palettes.get_item_text(i); overlay_key=[];render_model();inspection_controls())
	var manual_low := field("Color minimum",0 if not is_finite(contour_low) else contour_low,-1e30,1e30,0.001)
	var manual_high := field("Color maximum",1 if not is_finite(contour_high) else contour_high,-1e30,1e30,0.001)
	button(properties,"Apply color bounds",func():
		if manual_high.value<=manual_low.value: report("Color maximum must exceed minimum"); return
		contour_low=manual_low.value;contour_high=manual_high.value;overlay_key=[];render_model();inspection_controls())
	button(properties,"Automatic color bounds",func(): contour_low=NAN;contour_high=NAN;overlay_key=[];render_model();inspection_controls())
	var bands := field("Contour bands (0 = smooth)",contour_bands,0,32,1)
	bands.value_changed.connect(func(value): contour_bands=int(value);overlay_key=[];render_model())
	button(properties,"Toggle grid",func(): cad.grid.visible=not cad.grid.visible;cad.invalidate())
	var opacity := field("Grid opacity",cad.grid_opacity,0,1,0.05)
	opacity.value_changed.connect(func(value): cad.grid_opacity=value;cad.grid.material_override.set_shader_parameter("opacity",value);cad.invalidate())
	var cut := field("Section X (cell centers, 1 = full)",section_fraction,0,1,0.05)
	cut.value_changed.connect(func(value):
		section_fraction=value
		if mesh_inspection.data.elements.size()<=128: mesh_inspection.section(value)
		reset_mesh_selection()
		overlay_key=[]
		render_model()
		cad.invalidate())
	button(properties,"Reset selection",reset_mesh_selection)
	button(properties,"Focus selected element",func():
		if not is_instance_valid(selection_highlight): return
		var center := Vector3.ZERO
		var cell: Array=mesh_inspection.data.elements[selection_highlight.get_meta("element")]
		for id in cell: center+=mesh_inspection.point(id)
		cad.target=center/cell.size()
		var bounds := AABB(mesh_inspection.point(cell[0]),Vector3.ZERO)
		for id in cell: bounds=bounds.expand(mesh_inspection.point(id))
		cad.distance=maxf(bounds.size.length()*2.0,0.00001)
		cad.update_camera())
	button(properties,"Toggle edges",func(): set_inspection_mode("solid" if inspection_mode=="combined" else "combined"))
	button(properties,"Show nodes",func(): set_inspection_mode("nodes"))
	properties=fold_section(panel_root,"Mesh statistics",true)
	var stats: Dictionary=mesh_inspection.statistics
	label(properties,"Nodes %d | Elements %d\nHEX8 %d | TET4 %d\nInverted %d | Degenerate %d\nInvalid %d | Warning %d" % [mesh_inspection.data.nodes.size(),mesh_inspection.data.elements.size(),stats.hex,stats.tet,stats.inverted,stats.degenerate,stats.invalid,stats.warning])
	properties=fold_section(panel_root,"Quality legend",true)
	var contour: Dictionary=mesh_inspection.contour(quality_metric if not quality_metric.is_empty() else "jacobian",false,color_palette,contour_low,contour_high,contour_bands)
	label(properties,mesh_inspection.metric_label(quality_metric))
	var summary: Dictionary=mesh_inspection.quality_summary(quality_metric)
	if summary.count>0:
		label(properties,"Min %s | Max %s\nMean %s | Median %s\n5 equal-width bins (low to high): %s\nFinite %d | Missing %d" % [Visuals.number(summary.min),Visuals.number(summary.max),Visuals.number(summary.mean),Visuals.number(summary.median),str(summary.bins),summary.count,summary.missing])
	label(properties,"Warnings: edge ratio > 5 OR legacy scaled Jacobian < 0.2.\nMean ratio has no pass/fail threshold. TET4 only; HEX8 is missing.\nTET4 legacy Jacobian depends on node order; higher is better.")
	if contour.finite_count==0: label(properties,"No finite metric values; numerical bounds unavailable")
	var gradient := Gradient.new()
	gradient.set_color(0,Visuals.color(0,0,1,color_palette)); gradient.set_color(1,Visuals.color(1,0,1,color_palette))
	for i in range(1,8): gradient.add_point(i/8.0,Visuals.color(i/8.0,0,1,color_palette))
	var texture := GradientTexture1D.new(); texture.gradient=gradient
	var bar := TextureRect.new(); bar.texture=texture; bar.custom_minimum_size=Vector2(180,16)
	properties.add_child(bar)
	for i in 3: label(properties,"%d%%   %s" % [i*50,Visuals.number(lerpf(contour.min,contour.max,i/2.0))])
	label(properties,"Signed det J differs from scaled Jacobian.\nMagenta: nonfinite / inverted\nYellow: degenerate; orange: warning\nSection exposes original cell faces.")
	properties=panel_root

func poll_mesh_preparation() -> void:
	for job in preparation_jobs.duplicate():
		if not job.pump_snapshot():
			if job.generation==preparation_generation:report(job.status())
			continue
		if not job.thread.is_started(): preparation_jobs.erase(job);continue
		if job.thread.is_alive():
			if job.generation==preparation_generation: report("Preparing mesh: "+job.status())
			continue
		var prepared=job.thread.wait_to_finish()
		preparation_jobs.erase(job)
		if prepared!=null and job.generation==preparation_generation:
			mesh_inspection=prepared
			inspection_mesh_key=preparation_key
			overlay_key=[]
			render_model()
			if not inspection_mode.is_empty(): inspection_controls()
			cad.invalidate()
			if pending_worst_element:inspect_worst_mesh_element()
	if preparation_jobs.is_empty() and solve_thread==null and external_mesh_thread==null and cad_preview_thread==null and cad_geometry_thread==null: set_process(false)

func redraw_thermal() -> void:
	overlay_key=[];render_model();cad.invalidate()
func toggle_thermal_playback() -> void:
	if playback==null:
		playback=Timer.new();playback.one_shot=true;add_child(playback)
		playback.timeout.connect(func():
			if not results_current() or not show_results: return
			thermal_frame=(thermal_frame+1)%document.data.results.history.size()
			redraw_thermal()
			var times: Array=document.data.results.times
			var delta: float=times[thermal_frame+1]-times[thermal_frame] if thermal_frame+1<times.size() else times[1]-times[0]
			playback.start(maxf(0.01,delta/playback_speed)))
	if playback.is_stopped(): playback.start(0.01)
	else: playback.stop()

func numerical_legend(parent: VBoxContainer,title: String,lo: float,hi: float,units: String,palette: String) -> void:
	label(parent,title+" ("+units+")",true)
	var gradient:=Gradient.new();gradient.set_color(0,Visuals.color(0,0,1,palette));gradient.set_color(1,Visuals.color(1,0,1,palette))
	for i in range(1,8):gradient.add_point(i/8.0,Visuals.color(i/8.0,0,1,palette))
	var texture:=GradientTexture1D.new();texture.gradient=gradient
	var bar:=TextureRect.new();bar.texture=texture;bar.custom_minimum_size=Vector2(180,14);parent.add_child(bar)
	label(parent,"Color map: "+palette+"; clamped endpoints; missing = magenta")
	for i in 5:
		var value := lerpf(lo,hi,i/4.0)
		var tick := label(parent,Visuals.number(value)+" "+units)
		tick.tooltip_text=JSON.stringify(value)

func fold_section(parent: VBoxContainer,title: String,expanded: bool) -> VBoxContainer:
	var toggle:=CheckButton.new();toggle.text=title;toggle.button_pressed=expanded;parent.add_child(toggle)
	var content:=VBoxContainer.new();content.visible=expanded;content.add_theme_constant_override("separation",4);parent.add_child(content)
	toggle.toggled.connect(func(value):content.visible=value)
	return content

func open_extreme_mode() -> void:
	clear_inspector()
	label(properties,"EXTREME CPU",true)
	var manager=preload("res://core/cae/extreme_jobs.gd").new()
	var backends:=OptionButton.new();var cpu_available:=FileAccess.file_exists("res://bin/unicore_solver.exe");backends.add_item("Native CPU - available" if cpu_available else "Native CPU - build required");backends.set_item_disabled(0,not cpu_available)
	for title in ["NVIDIA CUDA - future","AMD ROCm - future","Vulkan Compute - future"]:backends.add_item(title);backends.set_item_disabled(backends.item_count-1,true)
	properties.add_child(backends)
	var execution:=OptionButton.new()
	for title in ["Normal monitoring","Minimal rendering","Headless (safe to close GUI)"]:execution.add_item(title)
	properties.add_child(execution)
	var resources: Dictionary=manager.resources()
	label(properties,"Logical processors: "+str(OS.get_processor_count())+" | Physical cores: "+str(resources.get("physical_cores","unknown"))+"\nAvailable memory: "+str(int(resources.get("available_memory_bytes",0))/1048576)+" MiB")
	if not document.data.mesh.is_empty():label(properties,"Initial memory screening estimate: "+str((document.data.mesh.nodes.size()*1024+document.data.mesh.elements.size()*4096)/1048576)+" MiB")
	var threads:=field("Threads",document.data.get("analysis",{}).get("extreme_solver",{}).get("threads",mini(2,int(resources.get("max_threads",OS.get_processor_count())))),1,int(resources.get("max_threads",OS.get_processor_count())),1)
	var memory:=field("Memory budget (MiB)",maxi(128,int(resources.get("available_memory_bytes",2147483648))/2097152),128,maxi(128,int(resources.get("available_memory_bytes",2147483648)*0.8/1048576)),1)
	var presets:=OptionButton.new()
	for title in ["Balanced","High Performance","Maximum CPU","Custom"]:presets.add_item(title)
	presets.select(3);properties.add_child(presets);threads.editable=true
	presets.item_selected.connect(func(index):
		threads.editable=index==3
		if index==0:threads.value=1
		elif index==1:threads.value=mini(2,int(resources.get("max_threads",OS.get_processor_count())))
		elif index==2:threads.value=int(resources.get("max_threads",OS.get_processor_count())))
	var automatic_memory:=CheckButton.new();automatic_memory.text="Automatic memory budget";automatic_memory.button_pressed=false;properties.add_child(automatic_memory);memory.editable=true
	if document.data.get("analysis",{}).get("extreme_solver",{}).has("memory_mb"): memory.value=document.data.analysis.extreme_solver.memory_mb
	automatic_memory.toggled.connect(func(enabled):
		memory.editable=not enabled
		if enabled:memory.value=maxi(128,int(resources.get("available_memory_bytes",2147483648))/2097152))
	button(properties,"Start independent job",func():
		if execution.selected>0:
			if playback!=null:playback.stop()
			cad.set_active(false)
			for job in preparation_jobs:job.cancel()
		var path: String=manager.launch(document,int(threads.value),int(memory.value))
		last_extreme_directory=path
		report(manager.last_error if path.is_empty() else "Independent solver started: "+path)
		open_extreme_mode())
	button(properties,"Refresh persistent jobs",open_extreme_mode)
	for name in manager.jobs():
		var directory: String="user://extreme_jobs/"+name
		var state: Dictionary=manager.status(directory)
		var monitor_label:=label(properties,extreme_status_text(name,state))
		if state.get("state","") in ["Queued","Validating","Running"]:
			var timer:=Timer.new();timer.wait_time=1.0;properties.add_child(timer)
			timer.timeout.connect(func():monitor_label.text=extreme_status_text(name,manager.status(directory)))
			timer.start()
		if FileAccess.file_exists(directory+"/checkpoint.ucstate") and state is Dictionary and state.get("state","") in ["Failed","Cancelled","Interrupted","Restartable"]:
			button(properties,"Restart thermal state",func():report("Restart launched" if manager.restart(directory,int(threads.value),int(memory.value)) else "Restart could not be launched"))
		if state.get("state","") in ["Queued","Validating","Running"]:
			button(properties,"Cancel job",func():
				if manager.status(directory).get("state","") not in ["Queued","Validating","Running"]:return
				var file:=FileAccess.open(directory+"/cancel.request",FileAccess.WRITE);file.store_string("cancel"))
		if state.get("state","") in ["Queued","Validating","Running"]:
			properties.get_child(properties.get_child_count()-1).set_meta("job_directory",directory)
		button(properties,"Open completed results",func():
			var data: Dictionary=manager.load_result(directory,document.data)
			if data.is_empty():report(manager.last_error);return
			document.data=data;inspection_mode="";quality_metric="";mesh_pick_mode="";thermal_frame=-1;thermal_field="temperature";result_field="temperature" if data.results.has("temperature") else "displacement";show_results=true;
			if playback!=null:playback.stop()
			cad.set_active(true);document.changed.emit();overlay_key=[];render_model();show_result_inspector())
		properties.get_child(properties.get_child_count()-1).set_meta("job_directory",directory)
		properties.get_child(properties.get_child_count()-1).tooltip_text=directory
		button(properties,"View logs / diagnostics",func():OS.shell_open(ProjectSettings.globalize_path(directory+("/error.log" if FileAccess.file_exists(directory+"/error.log") else "/status.json"))))
		button(properties,"Open job files",func():OS.shell_open(ProjectSettings.globalize_path(directory)))
	button(properties,"Return to CAE",func():cad.set_active(true);inspect())

func extreme_status_text(name: String,state: Dictionary) -> String:
	var lines:=PackedStringArray([name,str(state.get("state","Unknown"))])
	if state.has("phase_name"):lines.append(str(state.phase_name))
	if state.has("elapsed_s"):lines.append("Elapsed "+Visuals.number(state.elapsed_s)+" s")
	if state.has("linear_iteration"):lines.append("Linear iteration "+str(state.linear_iteration))
	elif state.has("iterations"):lines.append("Iterations "+str(state.iterations))
	if state.has("linear_residual"):lines.append("Linear residual "+Visuals.number(state.linear_residual))
	elif state.has("relative_residual"):lines.append("Residual "+Visuals.number(state.relative_residual))
	if state.has("memory_bytes"):lines.append("Memory "+Visuals.number(state.memory_bytes/1048576.0)+" MiB")
	elif state.has("peak_memory_bytes"):lines.append("Peak memory "+Visuals.number(state.peak_memory_bytes/1048576.0)+" MiB")
	if state.has("error"):lines.append(str(state.error))
	return "\n".join(lines)

# Stage 2 UI adapters. All actions dispatch through existing document/solver handlers.
var icon_cache: Dictionary = {}
func command_icon(category: String) -> Texture2D:
	if icon_cache.has(category): return icon_cache[category]
	var paths: Dictionary = {
		"Geometry":[[3,6,10,2],[10,2,17,6],[17,6,17,14],[17,14,10,18],[10,18,3,14],[3,14,3,6],[3,6,10,10],[10,10,17,6],[10,10,10,18]],
		"Mesh":[[3,3,17,3],[17,3,17,17],[17,17,3,17],[3,17,3,3],[3,8,17,8],[3,12,17,12],[8,3,8,17],[12,3,12,17]],
		"Results":[[3,3,3,17],[3,17,18,17],[6,13,10,8],[10,8,13,11],[13,11,17,4]],
		"Simulation":[[7,3,17,10],[17,10,7,17],[7,17,7,3]],
		"Materials":[[3,6,10,2],[10,2,17,6],[17,6,10,10],[10,10,3,6],[3,10,10,14],[10,14,17,10],[3,14,10,18],[10,18,17,14]],
		"Inspection":[[3,3,12,3],[12,3,12,12],[12,12,3,12],[3,12,3,3],[12,12,18,18]],
		"Loads & Constraints":[[10,2,10,13],[6,9,10,13],[10,13,14,9],[3,17,17,17]],
		"Home":[[3,9,10,3],[10,3,17,9],[5,8,5,17],[5,17,15,17],[15,17,15,8]]}
	var img := Image.create(20,20,false,Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	for segment in paths.get(category,paths.Home):
		var start := Vector2(segment[0],segment[1])
		var finish := Vector2(segment[2],segment[3])
		var steps := int(maxf(absf(finish.x-start.x),absf(finish.y-start.y)))
		for i in steps+1:
			var point := start.lerp(finish,float(i)/maxi(steps,1))
			img.set_pixel(roundi(point.x),roundi(point.y),Color("9abdcf"))
	icon_cache[category]=ImageTexture.create_from_image(img)
	return icon_cache[category]

func build_ribbon(layout: VBoxContainer) -> void:
	tool_registry.register("Simulation","Solver configuration",open_solver_configuration)
	tool_registry.register("Mesh","Mesh workspace",open_mesh_workspace)
	tool_registry.register("Home","Workflow check",workflow_check)
	tool_registry.register("Loads & Constraints","Face force",func(): run_command("ApplyLoad",{"face":face.get_item_text(face.selected),"force":current_force()}),func(): return "Select a structural box/cylinder body" if selected<0 or document.data.parts[selected].kind not in ["Box","Cylinder","Sphere","Pipe","CAD"] or document.data.get("analysis",{}).get("type","static_structural")!="static_structural" else "")
	tool_registry.register("Inspection","Pick nodes",func(): activate_mesh_pick("node"),func(): return "Generate a solver mesh first" if document.data.mesh.is_empty() else "")
	tool_registry.register("Inspection","Pick elements",func(): activate_mesh_pick("element"),func(): return "Generate a solver mesh first" if document.data.mesh.is_empty() else "")
	tool_registry.register("Loads & Constraints","Boundary conditions",open_analysis_editor)
	tool_registry.register("Loads & Constraints","Fixed face",func(): run_command("ApplySupport",{"face":face.get_item_text(face.selected)}),func(): return "Select a structural box/cylinder body" if selected<0 or document.data.parts[selected].kind not in ["Box","Cylinder","Sphere","Pipe","CAD"] or document.data.get("analysis",{}).get("type","static_structural")!="static_structural" else "")
	ribbon_tabs = HBoxContainer.new()
	layout.add_child(ribbon_tabs)
	var group := ButtonGroup.new()
	for title in ["Home","Geometry","Materials","Mesh","Loads & Constraints","Simulation","Results","Inspection"]:
		var tab := Button.new()
		tab.text=title
		tab.toggle_mode=true
		tab.button_group=group
		tab.button_pressed=title==active_ribbon
		tab.tooltip_text=title+" tools"
		tab.pressed.connect(func(): active_ribbon=title; populate_ribbon())
		ribbon_tabs.add_child(tab)
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	ribbon_tools=HBoxContainer.new()
	ribbon_tools.add_theme_constant_override("separation",12)
	scroll.add_child(ribbon_tools)
	populate_ribbon()

func populate_ribbon() -> void:
	for tab in ribbon_tabs.get_children(): tab.set_pressed_no_signal(tab.text==active_ribbon)
	for child in ribbon_tools.get_children(): ribbon_tools.remove_child(child); child.queue_free()
	ribbon_buttons.clear()
	var groups: Dictionary = {
		"Home":{"Project":["New","Open...","Save as..."],"History":["Undo","Redo"],"Workspace":["Fit all","Focus engineering command","Workflow check"]},
		"Geometry":{"Primitives":["Box","Cylinder","Sphere","Pipe"],"CAD features":["Boolean CAD...","Edit CAD features..."],"Edit body":["Duplicate","Delete"],"Camera":["Fit selection"]},
		"Materials":{"Assignment":["Library / custom materials"]},
		"Mesh":{"Volume mesh":["Mesh workspace","Generate box volume mesh","Mesh quality"],"Display":["Solid mesh","Wireframe","Nodes","Elements"]},
		"Loads & Constraints":{"Conditions":["Boundary conditions","Fixed face","Face force"]},
		"Simulation":{"Analysis":["Study / boundary setup...","Solver configuration","Validate"],"Execution":["Solve","Cancel","Configure / jobs"]},
		"Results":{"Fields":["Displacement","Von Mises stress","Temperature"],"Evaluate":["Inspect result probes","Export JSON"]},
		"Inspection":{"Selection":["Pick nodes","Pick elements"],"Mesh display":["Solid + wireframe","Quality","Invalid elements","Controls"],"View":["Orthographic / perspective","Reset view"]}}
	for group_name in groups[active_ribbon]:
		var column := VBoxContainer.new()
		var row := HBoxContainer.new()
		column.add_child(row)
		ribbon_tools.add_child(column)
		for title in groups[active_ribbon][group_name]:
			for tool in tool_registry.tools:
				if tool.title!=title: continue
				var control := Button.new()
				control.text={"Generate box volume mesh":"Generate mesh","Library / custom materials":"Material library","Study / boundary setup...":"Analysis settings","Inspect result probes":"Probes / fields","Configure / jobs":"Extreme CPU","Orthographic / perspective":"Projection","Focus engineering command":"AI command"}.get(title,title)
				control.icon=command_icon(active_ribbon)
				control.custom_minimum_size.y=32
				control.pressed.connect(func():
					var error: String=tool_registry.execute(tool.id)
					if not error.is_empty(): report(error)
					update_ribbon_availability())
				row.add_child(control)
				ribbon_buttons.append({"node":control,"tool":tool})
		var caption := label(column,group_name)
		caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_color_override("font_color",Color("8e9eae"))
		ribbon_tools.add_child(VSeparator.new())
	update_ribbon_availability()

func update_ribbon_availability() -> void:
	for binding in ribbon_buttons:
		var reason: String=tool_registry.reason(binding.tool)
		binding.node.disabled=not reason.is_empty()
		binding.node.tooltip_text=binding.tool.category+" / "+binding.tool.title+"\n"+(reason if not reason.is_empty() else "Available"+ (" В· "+binding.tool.shortcut if not binding.tool.shortcut.is_empty() else ""))

func explorer_item(parent: TreeItem, title: String, key: String, category: String, metadata = null) -> TreeItem:
	var item := tree.create_item(parent)
	item.set_text(0,title)
	item.set_tooltip_text(0,title)
	item.set_meta("key",key)
	item.set_metadata(0,metadata)
	item.set_icon(0,command_icon(category))
	item.collapsed=tree_state.get(key,false)
	return item

var explorer_signature := ""
func rebuild_explorer() -> void:
	var structure: Array=[]
	for part in document.data.parts:
		structure.append([part.id,part.name,part.get("visible",true),part.get("analysis_enabled",true),part.material.get("name","Unassigned"),part.get("support",""),part.get("load_face",""),Conditions.entries(part)])
	var signature := JSON.stringify([structure,document.data.mesh.get("nodes",[]).size(),document.data.mesh.get("elements",[]).size(),document.data.get("analysis",{}),document.data.results.is_empty(),results_current()])
	if signature==explorer_signature and tree.get_root()!=null:
		tree.get_root().set_text(0,"Project В· r%d" % document.data.revision)
		for i in tree_items.size():
			if i==selected: tree_items[i].select(0)
		return
	explorer_signature=signature
	tree.clear()
	tree_items.clear()
	var root := explorer_item(null,"Project В· r%d" % document.data.revision,"project","Home","project")
	var geometry := explorer_item(root,"Geometry","geometry","Geometry","geometry")
	var materials := explorer_item(root,"Materials","materials","Materials","materials")
	for i in document.data.parts.size():
		var part: Dictionary=document.data.parts[i]
		var item := explorer_item(geometry,part.name+(" (hidden)" if not part.get("visible",true) else "")+(" (excluded)" if not part.get("analysis_enabled",true) else ""),part.id,"Geometry",i)
		item.set_tooltip_text(0,"Instance: "+str(part.get("instance_uuid",part.id))+"\nDefinition: "+str(part.get("definition_uuid","legacy"))+"\nAnalysis: "+("enabled" if part.get("analysis_enabled",true) else "excluded"))
		tree_items.append(item)
		if part.has("cad_model"):
			for feature in part.cad_model.nodes:
				var title=str(feature.get("name",feature.id))+" / "+str(feature.type)
				if feature.type in ["Union","Cut","Intersect"]:title+=" (base: "+feature.base+", tool: "+feature.tool+")"
				explorer_item(item,title,"cad_"+feature.id,"Geometry",i)
		if i==selected: item.select(0)
		explorer_item(materials,str(part.material.get("name","Unassigned"))+" в†’ "+part.name,"material"+part.id,"Materials",i)
	var mesh: Dictionary=document.data.mesh
	explorer_item(root,"Mesh В· %d nodes / %d cells" % [mesh.get("nodes",[]).size(),mesh.get("elements",[]).size()],"mesh","Mesh","mesh")
	var analysis := explorer_item(root,"Analysis В· "+document.data.get("analysis",{}).get("type","static_structural").replace("_"," "),"analysis","Simulation","analysis")
	var conditions := explorer_item(analysis,"Loads & constraints","conditions","Loads & Constraints","analysis")
	for i in document.data.parts.size():
		var part: Dictionary=document.data.parts[i]
		for entry in Conditions.entries(part):
			var metadata := {"body":i,"key":entry.key}
			explorer_item(conditions,part.name+" В· "+entry.title+" В· "+entry.target,"condition"+part.id+entry.key,"Loads & Constraints",metadata)

	explorer_item(analysis,"Solver / boundary settingsвЂ¦","settings","Simulation","analysis")
	explorer_item(root,"Results"+(" В· outdated" if not document.data.results.is_empty() and not results_current() else " В· available" if not document.data.results.is_empty() else " В· no solution"),"results","Results","results")

func inspect_category(category: String) -> void:
	clear_inspector()
	match category:
		"materials":
			label(properties,"MATERIAL ASSIGNMENTS")
			for part in document.data.parts: label(properties,part.name+": "+str(part.material.get("name","Unassigned")))
			label(properties,"Select a body to edit its material.")
		"mesh":
			open_mesh_workspace()
			return

		"analysis":
			label(properties,"ANALYSIS")
			label(properties,document.data.get("analysis",{}).get("type","static_structural"))
			button(properties,"Analysis / boundary settings",open_analysis_editor)
		"results": show_result_inspector()
		_: label(properties,"Select a body in Geometry or the viewport. Use the task tabs to create and inspect your model.")

func property_section(parent: VBoxContainer, title: String, expanded: bool) -> VBoxContainer:
	var toggle := Button.new()
	toggle.text=title
	toggle.alignment=HORIZONTAL_ALIGNMENT_LEFT
	toggle.toggle_mode=true
	toggle.button_pressed=section_state.get(title,expanded)
	toggle.tooltip_text="Expand / collapse "+title
	parent.add_child(toggle)
	var content := VBoxContainer.new()
	content.visible=toggle.button_pressed
	parent.add_child(content)
	toggle.toggled.connect(func(value): content.visible=value; section_state[title]=value)
	return content

func confirm_delete() -> void:
	if selected<0: return
	var body_id: String=document.data.parts[selected].id
	var confirm := ConfirmationDialog.new()
	confirm.dialog_text="Delete "+document.data.parts[selected].name+"? The mesh and results will be invalidated. Undo can restore the document."
	add_child(confirm)
	confirm.confirmed.connect(func():
		if selected>=0 and document.data.parts[selected].id==body_id: run_command("Delete")
		confirm.queue_free())
	confirm.canceled.connect(confirm.queue_free)
	confirm.popup_centered()

func tree_context_action(id: int) -> void:
	match id:
		0: cad.fit(selected)
		1: run_command("Duplicate")
		2: run_command("SetVisibility", {"visible":not document.data.parts[selected].get("visible",true)})
		3: confirm_delete()

func open_mesh_workspace() -> void:
	if selected>=0 and (document.data.parts[selected].kind=="CAD" or document.data.get("analysis",{}).get("backend")=="calculix" or document.data.parts[selected].has("mesh_settings")):
		open_gmsh_workspace();return
	clear_inspector()
	label(properties,"MESH / VOLUME")
	label(properties,"Boxes: existing mesher. Cylinders: bounded polygonal TET4, Extreme CPU backend; Top / Bottom / Lateral. Sphere: single-body spherified-cube TET4, OuterSurface / PositiveY / NegativeY. Pipe: annular TET4, InnerWall / OuterWall / InletEnd / OutletEnd; single-body only. Mixed meshing unavailable.")
	var settings: Dictionary=document.data.get("analysis",{}).duplicate(true)
	var element := OptionButton.new()
	for title in ["TET4 В· box split / cylinder volume","HEX8 В· structural full integration"]: element.add_item(title)
	element.select(1 if settings.get("element","TET4")=="HEX8" else 0)
	var thermal: bool=settings.get("type","static_structural")!="static_structural" or document.data.parts.any(func(part): return part.kind in ["Cylinder","Sphere","Pipe"])
	element.set_item_disabled(1,thermal)
	if thermal: element.select(0)
	properties.add_child(element)
	var density := field("Density",divisions.value,1,4 if document.data.parts.any(func(part): return part.kind=="Sphere") else 8 if document.data.parts.any(func(part): return part.kind in ["Cylinder","Pipe"]) else 16,1)
	button(properties,"Generate supported mesh",func():
		settings["type"]=settings.get("type","static_structural")
		settings["element"]="HEX8" if element.selected==1 else "TET4"
		var requested_density: int=int(density.value)
		var error: String=document.execute("SetAnalysis",{"analysis":settings})
		if not error.is_empty(): report(error); return
		divisions.value=requested_density
		generate_analysis_mesh()
		open_mesh_workspace())
	var mesh: Dictionary=document.data.mesh
	label(properties,"%d nodes В· %d %s cells" % [mesh.get("nodes",[]).size(),mesh.get("elements",[]).size(),mesh.get("formulation","base HEX8")])
	if mesh.get("geometry_backend","")=="polygonal_cylinder_v1":
		label(properties,"Actual TET4 volume mesh; polygonal approximation of the circle. Density d uses 8d circumferential sectors, d radial rings and d axial layers. Extreme CPU is the validated solve backend.")
	else:
		label(properties,"The structured mesher stores base HEX8 cells. TET4 analyses use the native six-tet split. Before solving, inspection IDs refer to base cells. Current results supply actual solver connectivity and IDs. Display triangles are not solver elements.")
	for mode in ["wireframe","combined","nodes","elements","quality","invalid"]:
		button(properties,mode.capitalize(),func(): set_inspection_mode(mode))
	button(properties,"Inspect nodes",func(): activate_mesh_pick("node"))
	button(properties,"Inspect elements",func(): activate_mesh_pick("element"))
	button(properties,"Detailed quality / section controls",inspection_controls)

func open_gmsh_settings(local: bool=false):
	if selected<0:report("Select an analysis body first");return
	var panel=preload("res://ui/cae/gmsh_mesh_panel.gd").new();add_child(panel);panel.configure(self,local);panel.popup_centered()
func open_gmsh_workspace():
	clear_inspector();label(properties,"GMSH / "+str(document.data.mesh.get("formulation","TET4 / TET10"))+" ENGINEERING MESH",true)
	label(properties,"SI mesh sizes; genuine OCCT geometry. Mesh current: "+str(preload("res://core/cae/mesh_config.gd").current(document.data)))
	button(properties,"Global Gmsh settings...",func():open_gmsh_settings(false))
	button(properties,"Local CAD face refinement...",func():open_gmsh_settings(true))
	button(properties,"Generate / regenerate Gmsh",generate_analysis_mesh)
	button(properties,"Cancel owned mesh job",func():
		if native_solver!=null:native_solver.cancel())
	var mesh=document.data.mesh;var q=mesh.get("quality",{})
	label(properties,"%d nodes / %d %s / %s display triangles" % [mesh.get("nodes",[]).size(),mesh.get("elements",[]).size(),mesh.get("formulation","TET4"),str(q.get("exterior_triangles","unknown"))])
	for key in ["cad_volume","mesh_volume","absolute_volume_difference","relative_volume_difference","minimum_mean_ratio","minimum_volume","maximum_volume","edge_min","edge_mean","edge_max","maximum_edge_ratio","inverted_elements","degenerate_elements"]:label(properties,key+": "+str(q.get(key,"unmeshed")))
	label(properties,"Volumes m3; edges m; shape/ratio and relative error dimensionless")
	label(properties,("Quadratic-score" if mesh.get("formulation")=="TET10" else "Mean-ratio")+" bins [0,.1) ... [.9,1]: "+str(q.get("quality_histogram",[])))
	label(properties,"Corners: "+str(mesh.get("corner_nodes","all"))+" / midsides: "+str(mesh.get("midside_nodes",0)))
	label(properties,"Quadratic score: "+str(q.get("minimum_quadratic_quality","n/a"))+"; detJ upper: "+str(q.get("maximum_jacobian","n/a")))
	button(properties,"Quality contour",func():quality_metric="quadratic_quality" if mesh.get("formulation")=="TET10" else "mean_ratio";set_inspection_mode("quality"))
	button(properties,"Locate worst element",inspect_worst_mesh_element)
	for mode in ["combined","wireframe","elements","invalid"]:button(properties,mode.capitalize(),func():set_inspection_mode(mode))
	button(properties,"Element selection",func():activate_mesh_pick("element"))
var pending_worst_element=false
func inspect_worst_mesh_element():
	if document.data.mesh.is_empty():return
	if not prepare_mesh_inspection():pending_worst_element=true;return
	pending_worst_element=false
	var q=document.data.mesh.get("quality",{});var id=int(q.get("worst_element",0));var cell=mesh_inspection.data.elements[id]
	mesh_pick_mode="element";highlight_mesh_entity({"element":id,"face":[cell[0],cell[1],cell[2]]})
	clear_inspector();label(properties,"WORST "+("TET10" if cell.size()==10 else "TET4")+" / zero-based element "+str(id),true);label(properties,"Node IDs: "+str(cell))
	var metric=mesh_inspection.metrics[id]
	for key in ["jacobian","volume","mean_ratio","edge_ratio"]:label(properties,key+": "+str(metric[key]))
	if cell.size()==10:label(properties,"Curved detJ upper: "+str(metric.jacobian_max)+" / certified quadratic quality: "+str(metric.quadratic_quality)+"; mean ratio above is corner-only")
	if cell.size()==10:label(properties,"Four integration-point detJ min/max (m3): "+str(metric.gauss_jacobian_min)+" / "+str(metric.gauss_jacobian_max))
	label(properties,"det J and volume: m3; mean ratio and edge ratio: dimensionless")
	cad.target=mesh_inspection.point(cell[0]);cad.update_camera();cad.invalidate()

func activate_node_pick() -> void:
	activate_mesh_pick("node")

func activate_element_pick() -> void:
	activate_mesh_pick("element")

func activate_mesh_pick(mode: String) -> void:
	if show_results and results_current() and document.data.results.has("displacement"):
		deformation_scale=0.0
		render_model()
	mesh_pick_mode=mode
	if not (show_results and results_current()):set_inspection_mode("nodes" if mode=="node" else "elements")
	mesh_pick_mode=mode
	report("Pick a solver "+mode+" on original geometry; IDs and stored values appear in the inspector")

func workflow_check() -> void:
	clear_inspector()
	label(properties,"ENGINEERING WORKFLOW")
	label(properties,"Geometry в†’ Materials в†’ Mesh в†’ Conditions в†’ Solver в†’ Results")
	var errors: PackedStringArray=document.validate()
	label(properties,"Model validation: ready" if errors.is_empty() else "\n".join(errors))
	label(properties,"Mesh: missing" if document.data.mesh.is_empty() else "Mesh: generated")
	label(properties,"Results: current" if results_current() else "Results: missing or outdated")
	button(properties,"Materials",open_material_library)
	button(properties,"Mesh workspace",open_mesh_workspace)
	button(properties,"Analysis / conditions",open_analysis_editor)
	button(properties,"Extreme CPU / restart / import",open_extreme_mode)
	report("Model validation ready" if errors.is_empty() else "Workflow needs attention: "+"; ".join(errors))

func inspect_condition(metadata: Dictionary) -> void:
	var previous := tree.get_selected()
	select_body(int(metadata.body))
	if previous!=null and previous.get_metadata(0) is Dictionary and previous.get_metadata(0)==metadata:
		_syncing=true
		previous.select(0)
		_syncing=false
	var found: Dictionary={}
	for entry in Conditions.entries(document.data.parts[selected]):
		if entry.key==metadata.key: found=entry
	if found.is_empty(): return
	clear_inspector()
	label(properties,found.title.to_upper())
	label(properties,"Target: "+document.data.parts[selected].name+" / "+found.target+"\nActive in model В· SI units")
	var inputs: Array=[]
	for i in found.labels.size():
		var precise: bool=found.command in ["ApplyDisplacement","ApplySphereExpansion"]
		var input:=field(found.labels[i],found.values[i],-1 if precise else -1e12,1 if precise else 1e12,0.000000001 if precise else 0.001)
		if precise:input.allow_greater=true;input.allow_lesser=true
		inputs.append(input)
	var body_id: String=document.data.parts[selected].id
	button(properties,"Apply values",func():
		if selected<0 or document.data.parts[selected].id!=body_id: report("Reselect the condition target"); return
		var values: Array=[]
		for input in inputs: values.append(input.value)
		var args: Dictionary=Conditions.edited_args(found,values)
		args.index=selected
		var error: String=document.execute(found.command,args)
		report("Condition updated" if error.is_empty() else error)
		inspect_condition(metadata))
	button(properties,"Delete condition (undo available)",func():
		if selected>=0 and document.data.parts[selected].id==body_id: run_command("RemoveCondition",{"key":found.key}))
	if found.target in Document.surface_names(document.data.parts[selected]):
		face.select(Document.surface_names(document.data.parts[selected]).find(found.target))
		selection_mode.select(1)
		show_selected_face()
		button(properties,"Show / hide target marker",func():
			condition_marker_visible=not condition_marker_visible
			if is_instance_valid(face_highlight): face_highlight.visible=condition_marker_visible
			cad.invalidate())
	label(properties,"Visibility affects only the target marker. It does not deactivate the numerical condition. Region labels are local to this primitive; edit another target through Analysis / conditions.")

func show_selected_face() -> void:
	if is_instance_valid(face_highlight): face_highlight.queue_free()
	if selected>=0 and document.data.parts[selected].kind in ["Cylinder","Sphere","Pipe","CAD"]:
		show_cylinder_region()
		return
	if selected<0 or document.data.parts[selected].kind not in ["Box","Cylinder","Sphere","Pipe","CAD"] or selection_mode.selected!=1: return
	var name: String=face.get_item_text(face.selected)
	var axis: int=["X","Y","Z"].find(name[0])
	var part: Dictionary=document.data.parts[selected]
	var corners: Array=[]
	for pair in [[-1,-1],[1,-1],[1,1],[-1,1]]:
		var point := Vector3.ZERO
		point[axis]=float(part.dimensions[axis])*0.501*(1 if name.ends_with("+") else -1)
		point[(axis+1)%3]=float(part.dimensions[(axis+1)%3])*0.501*pair[0]
		point[(axis+2)%3]=float(part.dimensions[(axis+2)%3])*0.501*pair[1]
		corners.append(cad.meshes[selected].transform*point)
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in 4:
		mesh.surface_add_vertex(corners[i]); mesh.surface_add_vertex(corners[(i+1)%4])
	mesh.surface_end()
	face_highlight=MeshInstance3D.new()
	face_highlight.mesh=mesh
	face_highlight.material_override=cad.line_material(Color("68d6e1"))
	face_highlight.visible=condition_marker_visible
	cad.scene_root.add_child(face_highlight)
	cad.invalidate()

func open_solver_configuration() -> void:
	clear_inspector()
	label(properties,"SOLVER CONFIGURATION")
	label(properties,"Normal: existing native PCG / Jacobi defaults. Advanced settings below apply only to independent Extreme CPU jobs. No GPU backend.")
	button(properties,"Analysis type / time integration",open_analysis_editor)
	var options: Dictionary=document.data.get("analysis",{}).get("extreme_solver",{})
	var method := OptionButton.new()
	for title in ["Jacobi","Block Jacobi В· structural only","IC(0) В· explicit fallback diagnostics"]: method.add_item(title)
	var keys := ["jacobi","block-jacobi","ic0"]
	method.select(maxi(0,keys.find(options.get("preconditioner","jacobi"))))
	properties.add_child(method)
	label(properties,"Block Jacobi thermal requests use the native documented fallback. Defaults are not universally sufficient for high-contrast flux accuracy; check field convergence.")
	var relative := field("Relative tolerance",options.get("relative_tolerance",1e-10),0,1,1e-13)
	var absolute := field("Absolute tolerance",options.get("absolute_tolerance",1e-10),0,1,1e-13)
	var iterations := field("Max iterations",options.get("max_iterations",20000),1,2147483647,1)
	var threads := field("CPU threads",options.get("threads",mini(2,OS.get_processor_count())),1,OS.get_processor_count(),1)
	var memory := field("Memory В· MiB",options.get("memory_mb",512),1,1048576,1)
	button(properties,"Save Extreme configuration",func():
		var settings: Dictionary=document.data.get("analysis",{}).duplicate(true)
		settings["type"]=settings.get("type","static_structural")
		settings.extreme_solver={"preconditioner":keys[method.selected],"relative_tolerance":relative.value,"absolute_tolerance":absolute.value,"max_iterations":int(iterations.value),"threads":int(threads.value),"memory_mb":int(memory.value)}
		var error: String=document.execute("SetAnalysis",{"analysis":settings})
		report("Extreme configuration saved; regenerate mesh before launch" if error.is_empty() else error)
		open_solver_configuration())
	button(properties,"Extreme jobs / resources / restart / import",open_extreme_mode)
	label(properties,"Resource controls in Extreme CPU may override saved threads/memory for a launch. Restart reuses the job snapshot's solver settings. Checkpoint/restart is transient thermal physical-state restart only; it is not a Krylov iteration restart.")

func show_cylinder_region() -> void:
	var part: Dictionary=document.data.parts[selected]
	var source: Dictionary=cad_display_source()
	var regions: Dictionary=source.get("surface_regions",{}).get(part.id,{})
	var triangles: Array=regions.get(face.get_item_text(face.selected),[])
	if triangles.is_empty(): return
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for triangle in triangles:
		for edge in [[0,1],[1,2],[2,0]]:
			for corner in edge:
				var point: Array=source.nodes[triangle[corner]]
				mesh.surface_add_vertex(Vector3(point[0],point[1],point[2]))
	mesh.surface_end()
	face_highlight=MeshInstance3D.new()
	face_highlight.mesh=mesh
	face_highlight.material_override=cad.line_material(Color("68d6e1"))
	face_highlight.material_override.no_depth_test=true
	face_highlight.visible=condition_marker_visible
	cad.scene_root.add_child(face_highlight)
	cad.invalidate()


var pending_face_review_uuid=""
func completed(result: Dictionary) -> void:
	if not result.get("ok",false):report(str(result.get("error","Native face review failed")));return
	for i in document.data.parts.size():
		if document.data.parts[i].get("instance_uuid")==pending_face_review_uuid:
			report(document.execute("RefreshCADFaces",{"index":i,"metadata":result.get("metadata",{})}))
			select_body(i)
			return
	report("Face review instance no longer exists")
