extends ConfirmationDialog
var registry: RefCounted
var query: LineEdit
var list: ItemList
var matches: Array = []
var roadmap := false

func _ready() -> void:
	title = "UniCORE tools and capability roadmap"
	size = Vector2i(700, 460)
	get_ok_button().text = "Run selected tool"
	var layout := VBoxContainer.new()
	add_child(layout)
	query = LineEdit.new()
	query.placeholder_text = "Search tools by name or category"
	layout.add_child(query)
	var toggle := CheckButton.new()
	toggle.text = "Future capability roadmap (unavailable)"
	layout.add_child(toggle)
	list = ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(list)
	query.text_changed.connect(func(_value): rebuild())
	toggle.toggled.connect(func(value): roadmap=value; rebuild())
	list.item_selected.connect(func(index): get_ok_button().disabled = roadmap or not registry.reason(matches[index]).is_empty())
	list.item_activated.connect(func(_index): activate())
	confirmed.connect(activate)
	rebuild()

func rebuild() -> void:
	list.clear()
	matches.clear()
	get_ok_button().disabled = true
	if roadmap:
		var domains = JSON.parse_string(FileAccess.get_file_as_string("res://core/cae/capability_roadmap.json"))
		for domain in domains:
			for capability in domain.capabilities:
				var text: String = domain.workspace + " / " + capability
				if not query.text.is_empty() and not query.text.to_lower() in text.to_lower(): continue
				list.add_item("[Planned] " + text)
				list.set_item_tooltip(list.item_count-1, "Unavailable. Domain reference only; no solver or proprietary implementation is supplied.")
		return
	matches = registry.search(query.text)
	for tool in matches:
		var reason: String = registry.reason(tool)
		list.add_item(tool.category + " / " + tool.title + ("  ["+tool.shortcut+"]" if not tool.shortcut.is_empty() else "") + (" — unavailable" if not reason.is_empty() else ""))
		list.set_item_tooltip(list.item_count-1, reason if not reason.is_empty() else "Available tool; uses the existing workbench handler")

func activate() -> void:
	if roadmap or list.get_selected_items().is_empty(): return
	var tool: Dictionary = matches[list.get_selected_items()[0]]
	if not registry.reason(tool).is_empty(): return
	registry.execute(tool.id)
	hide()
