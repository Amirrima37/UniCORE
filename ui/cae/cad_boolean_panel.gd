extends AcceptDialog
## Modal feature editor shares the existing document, viewport and undo history.
var workspace
var base_picker: OptionButton
var tool_picker: OptionButton
var operation: OptionButton
var feature_picker: OptionButton
var quality: SpinBox
var message: Label
var edit_model={}
var pending={}
var replace_ids=[]
var controls={}
var dependencies={}
var expected=""
var editing=false
var loaded_feature=-1
func configure(w, edit: bool=false):
	workspace=w;editing=edit;title="Edit CAD features" if edit else "OCCT Boolean CAD"
	size=Vector2i(740,520)
	var box=VBoxContainer.new();add_child(box)
	var text=Label.new();text.text="Exact B-Rep operation in metres. Preview, inspect, then confirm. Face changes require review.";box.add_child(text)
	base_picker=OptionButton.new();tool_picker=OptionButton.new();operation=OptionButton.new()
	for p in w.document.data.parts:base_picker.add_item(p.name);tool_picker.add_item(p.name)
	base_picker.select(maxi(0,w.selected));tool_picker.select(1 if w.document.data.parts.size()>1 else 0)
	for name in ["Union","Cut","Intersect"]:operation.add_item(name)
	for pair in [["Base",base_picker],["Tool",tool_picker],["Operation",operation]]:
		var row=HBoxContainer.new();var label=Label.new();label.text=pair[0];row.add_child(label);row.add_child(pair[1]);box.add_child(row)
	if edit:
		if w.selected<0:return
		edit_model=preload("res://core/cae/cad_model.gd").from_part(w.document.data.parts[w.selected])
		base_picker.disabled=true;tool_picker.disabled=true;operation.disabled=true
		feature_picker=OptionButton.new()
		for n in edit_model.nodes:feature_picker.add_item(n.get("name",n.id)+" / "+n.type)
		box.add_child(feature_picker)
		for key in ["base","tool"]:
			var picker=OptionButton.new()
			for n in edit_model.nodes:picker.add_item(n.get("name",n.id))
			box.add_child(picker);dependencies[key]=picker
		var scroll=ScrollContainer.new();scroll.custom_minimum_size.y=200;box.add_child(scroll)
		var transform_fields=VBoxContainer.new();scroll.add_child(transform_fields)
		for key in ["dimensions","position","rotation","scale","axis_direction","axis_point","axis_angle","inner_diameter"]:
			var row=HBoxContainer.new();var label=Label.new();label.text=key+ (" (degrees)" if key in ["rotation","axis_angle"] else " (factor; negative mirrors)" if key=="scale" else " (direction)" if key=="axis_direction" else " (m)");label.custom_minimum_size.x=205;row.add_child(label);controls[key]=[]
			for axis in (1 if key in ["inner_diameter","axis_angle"] else 3):
				var spin=SpinBox.new();spin.min_value=-1e4;spin.max_value=1e4;spin.step=0.001;spin.custom_minimum_size.x=135;row.add_child(spin);controls[key].append(spin)
			transform_fields.add_child(row)
		feature_picker.item_selected.connect(func(_i):load_feature());load_feature()
	quality=SpinBox.new();quality.min_value=8;quality.max_value=60;quality.value=20;quality.prefix="Preview quality ";box.add_child(quality)
	var preview=Button.new();preview.text="Preview exact OCCT result";preview.pressed.connect(start_preview);box.add_child(preview)
	var cancel_job=Button.new();cancel_job.text="Cancel geometry operation";cancel_job.pressed.connect(func():workspace.cancel_cad_geometry());box.add_child(cancel_job)
	message=Label.new();message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(message)
	for picker in [base_picker,tool_picker,operation]:picker.item_selected.connect(func(_i):invalidate_preview())
	for key in controls:
		for spin in controls[key]:spin.value_changed.connect(func(_value):invalidate_preview())
	for key in dependencies:dependencies[key].item_selected.connect(func(_i):invalidate_preview())
	quality.value_changed.connect(func(_value):invalidate_preview())
	get_ok_button().text="Confirm CAD result";get_ok_button().disabled=true
	confirmed.connect(commit)
	canceled.connect(func():workspace.cancel_cad_geometry();workspace.render_model();queue_free())
func invalidate_preview():
	pending={};get_ok_button().disabled=true
	if message!=null:message.text="Parameters changed: preview again before confirming"
func load_feature():
	if loaded_feature>=0:store_feature(loaded_feature)
	loaded_feature=feature_picker.selected
	var n=edit_model.nodes[feature_picker.selected]
	var is_boolean=n.type in ["Union","Cut","Intersect"]
	operation.disabled=not is_boolean
	if is_boolean:operation.select(["Union","Cut","Intersect"].find(n.type))
	for key in dependencies:
		dependencies[key].disabled=not is_boolean
		for i in edit_model.nodes.size():
			if edit_model.nodes[i].id==n.get(key,""):dependencies[key].select(i)
	for key in controls:
		var defaults=[1,1,1] if key=="scale" else [0,0,0]
		if key=="axis_direction":defaults=[0,1,0]
		for axis in controls[key].size():
			controls[key][axis].value=float(n.get(key,0)) if key in ["inner_diameter","axis_angle"] else float(n.get(key,defaults)[axis])
			controls[key][axis].editable=(key not in ["dimensions","inner_diameter"] or n.type in ["Box","Cylinder","Sphere","Pipe"]) and (key!="inner_diameter" or n.type=="Pipe")
func store_feature(index: int):
	var n=edit_model.nodes[index]
	if n.type in ["Union","Cut","Intersect"]:
		n.type=operation.get_item_text(operation.selected)
		for key in dependencies:n[key]=edit_model.nodes[dependencies[key].selected].id
	for key in controls:
		if not controls[key][0].editable:continue
		if key in ["inner_diameter","axis_angle"]:n[key]=controls[key][0].value
		else:
			n[key]=[]
			for spin in controls[key]:n[key].append(spin.value)
func start_preview():
	if workspace.cad_geometry_thread!=null:message.text="Wait for or cancel the active CAD operation";return
	var model={};var base=workspace.document.data.parts[base_picker.selected]
	if editing:
		store_feature(feature_picker.selected)
		model=edit_model.duplicate(true);replace_ids=[base.id]
	else:
		if base_picker.selected==tool_picker.selected:message.text="Choose two distinct bodies";return
		var tool=workspace.document.data.parts[tool_picker.selected]
		model=preload("res://core/cae/cad_model.gd").boolean_model(base,tool,operation.get_item_text(operation.selected));replace_ids=[base.id,tool.id]
	if model.has("error"):message.text=model.error;return
	var error=preload("res://core/cae/cad_model.gd").validate(model)
	if not error.is_empty():message.text=error;return
	expected=workspace.model_signature();pending={};get_ok_button().disabled=true
	message.text="Computing OCCT B-Rep in an owned worker..."
	if not workspace.start_cad_geometry({"model":model,"part_id":base.id,"previous_faces":base.get("cad_face_descriptors",{}),"quality":int(quality.value)},self):message.text="Wait for the active CAD preview/mesh/solve operation, then preview again"
func completed(result: Dictionary):
	if workspace.model_signature()!=expected:message.text="Document changed: geometry preview discarded";return
	if not result.get("ok",false):message.text=result.get("error","CAD operation failed");return
	pending=result
	var candidate=workspace.document.data.parts[base_picker.selected].duplicate(true)
	for key in result.part:candidate[key]=result.part[key]
	workspace.cad.set_meta("cad_mesh",result.preview);workspace.cad.sync_model([candidate],0);workspace.cad.fit(0)
	message.text="Single solid: volume %s m3, %d faces. Face review: %s" % [str(candidate.cad_volume),candidate.cad_faces.size(),str(result.topology)]
	get_ok_button().disabled=false
func commit():
	if pending.is_empty() or workspace.model_signature()!=expected:workspace.report("CAD preview is stale; preview again");return
	workspace.cad_preview=pending.preview
	var error=workspace.document.execute("CommitCADFeature",{"part":pending.part,"replace_ids":replace_ids,"topology":pending.topology,"name":pending.part.cad_model.nodes[-1].get("name","CAD result")})
	workspace.selected=0;workspace.select_body(0);workspace.report(error if not error.is_empty() else "CAD feature committed; review boundary faces before remeshing")
	queue_free()
