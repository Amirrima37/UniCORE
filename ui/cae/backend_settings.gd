extends AcceptDialog
## Read-only status panel; no source checkout is advertised as a solver.
func _ready():
	title = "Solver dependencies"
	var box := VBoxContainer.new()
	add_child(box)
	for backend in preload("res://core/cae/backend_registry.gd").new().discover():
		var label := Label.new()
		label.text = "%s: %s\n%s\n%s" % [backend.label, backend.status, backend.executable, backend.diagnostic]
		box.add_child(label)
	var note := Label.new()
	var calc=preload("res://core/cae/calculix_backend.gd").new().dependency_status()
	note.text = "CalculiX %s: %s\n%s\n%s" % [calc.version,calc.status,calc.executable,calc.diagnostic]
	box.add_child(note)
