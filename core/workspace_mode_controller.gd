extends Node
## Single owner of mode visibility, sandbox processing and input restoration.
signal mode_changed(mode: int)
enum Mode { AI_SANDBOX, CAE_WORKBENCH }
var current: int = Mode.AI_SANDBOX
var workspace: Control
var sandbox_roots: Array[Node] = []
var saved: Array = []
var saved_mouse := Input.MOUSE_MODE_VISIBLE
var saved_focus: WeakRef
var bus: Node
var saved_modal_open := false

func setup(cae: Control, roots: Array[Node], event_bus: Node = null) -> void:
	workspace = cae
	sandbox_roots = roots
	bus = event_bus
	workspace.back_requested.connect(func(): set_mode(Mode.AI_SANDBOX))
	workspace.set_active(false)

func set_mode(mode: int) -> void:
	if mode == current or mode not in [Mode.AI_SANDBOX, Mode.CAE_WORKBENCH]: return
	var focus := get_viewport().gui_get_focus_owner()
	if mode == Mode.CAE_WORKBENCH:
		saved_mouse = Input.mouse_mode
		saved_focus = weakref(focus) if focus != null else null
		if focus: focus.release_focus()
		saved.clear()
		saved_modal_open = false
		for node in sandbox_roots:
			if not is_instance_valid(node) or not node is Control: continue
			if node.name == "WelcomeScreen" and node.visible: saved_modal_open = true
			for property in node.get_property_list():
				if property.name == "is_open" and node.get("is_open"): saved_modal_open = true
		if bus: bus.emit("modal_opened", {"source": "cae_mode"})
		for node in sandbox_roots:
			if not is_instance_valid(node): continue
			var visible_before = node.visible if node is CanvasItem or node is Node3D else null
			saved.append({"node": weakref(node), "process": node.process_mode, "visible": visible_before})
			node.process_mode = Node.PROCESS_MODE_DISABLED
			if visible_before != null: node.hide()
		current = mode
		workspace.set_active(true)
		if DisplayServer.has_feature(DisplayServer.FEATURE_MOUSE): Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		workspace.dismiss_dialogs()
		workspace.set_active(false)
		if focus: focus.release_focus()
		for state in saved:
			var node = state.node.get_ref()
			if not is_instance_valid(node): continue
			node.process_mode = state.process
			if state.visible != null: node.visible = state.visible
		saved.clear()
		current = mode
		if bus: bus.emit("modal_closed", {"source": "cae_mode"})
		if bus and saved_modal_open: bus.emit("modal_opened", {"source": "restored_sandbox_dialog"})
		if DisplayServer.has_feature(DisplayServer.FEATURE_MOUSE): Input.mouse_mode = saved_mouse
		if saved_focus != null:
			var previous = saved_focus.get_ref()
			if is_instance_valid(previous) and previous.is_visible_in_tree(): previous.grab_focus()
	mode_changed.emit(current)

func _input(event: InputEvent) -> void:
	if current != Mode.CAE_WORKBENCH: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if not workspace.dismiss_dialogs(): set_mode(Mode.AI_SANDBOX)
		get_viewport().set_input_as_handled()
