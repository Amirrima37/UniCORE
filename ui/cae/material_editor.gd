extends ConfirmationDialog
signal material_chosen(material: Dictionary)
var library=preload("res://core/cae/material_library.gd").new()
var search: LineEdit
var list: ItemList
var editor: TextEdit
var info: Label
var visible_records: Array=[]
var analysis: String="static_structural"
var file_dialog: FileDialog
func _ready() -> void:
	title="Engineering materials · SI units"
	size=Vector2i(680,600)
	get_ok_button().text="Assign to body"
	var layout:=VBoxContainer.new()
	add_child(layout)
	search=LineEdit.new()
	search.placeholder_text="Search name or category"
	layout.add_child(search)
	list=ItemList.new()
	list.custom_minimum_size.y=110
	layout.add_child(list)
	editor=TextEdit.new()
	editor.custom_minimum_size=Vector2(500,250)
	editor.size_flags_vertical=Control.SIZE_EXPAND_FILL
	layout.add_child(editor)
	var row:=HBoxContainer.new()
	layout.add_child(row)
	for action in ["New","Duplicate","Save custom","Import","Export"]:
		var button:=Button.new()
		button.text=action
		row.add_child(button)
		button.pressed.connect(func(): handle_action(action))
	info=Label.new()
	info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(info)
	search.text_changed.connect(func(_text): populate())
	list.item_selected.connect(func(index): editor.text=JSON.stringify(visible_records[index],"\t",true,true); update_status())
	editor.text_changed.connect(update_status)
	confirmed.connect(func():
		var material=JSON.parse_string(editor.text)
		if material is Dictionary and library.validate(material).valid_definition: material_chosen.emit(material))
	populate()
	update_status()
func populate() -> void:
	list.clear()
	visible_records.clear()
	for record in library.records:
		if not search.text.is_empty() and search.text.to_lower() not in (record.name+" "+record.get("category","")).to_lower(): continue
		visible_records.append(record)
		list.add_item(record.name)
func update_status() -> void:
	if editor.text.strip_edges().is_empty():
		info.text="Select a library record or create a custom definition. Unspecified properties stay null."
		get_ok_button().disabled=true
		return
	var material=JSON.parse_string(editor.text)
	if not material is Dictionary:
		info.text="Enter a material JSON object. Null means unspecified."
		get_ok_button().disabled=true
		return
	var definition: Dictionary=library.validate(material)
	var ready: Dictionary=library.validate(material,analysis)
	get_ok_button().disabled=not definition.valid_definition
	info.text="Required for %s: missing %s; errors %s. Sources and property units are in the record." % [analysis,ready.missing,ready.errors]
func handle_action(action: String) -> void:
	match action:
		"New": editor.text=JSON.stringify({"definition_version":1,"id":"custom","name":"Custom material","model":"isotropic_linear_elastic","units":"SI","E":null,"nu":null,"density":null,"k":null,"cp":null,"sources":[],"assumptions":["User supplied; add traceable sources and valid ranges"]},"\t")
		"Duplicate":
			var material=JSON.parse_string(editor.text)
			if material is Dictionary:
				material.name+=" copy"
				material.id="custom"
				editor.text=JSON.stringify(material,"\t",true,true)
		"Save custom":
			var material=JSON.parse_string(editor.text)
			if material is Dictionary:
				var error: String=library.persist_custom(material)
				populate()
				info.text="Saved custom material" if error.is_empty() else error
		"Import","Export":
			if file_dialog!=null: file_dialog.queue_free()
			file_dialog=FileDialog.new()
			file_dialog.access=FileDialog.ACCESS_FILESYSTEM
			file_dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE if action=="Import" else FileDialog.FILE_MODE_SAVE_FILE
			file_dialog.filters=PackedStringArray(["*.json ; Engineering material JSON"])
			add_child(file_dialog)
			file_dialog.file_selected.connect(func(path):
				if action=="Import": editor.text=FileAccess.get_file_as_string(path); update_status()
				else:
					var file:=FileAccess.open(path,FileAccess.WRITE)
					if file!=null: file.store_string(editor.text))
			file_dialog.popup_centered_ratio(.65)
	update_status()
