extends SceneTree
func _initialize():
	var editor=load("res://ui/cae/analysis_editor.gd").new()
	editor.surface_names=["OuterSurface","PositiveY","NegativeY"]
	root.add_child.call_deferred(editor)
	await process_frame
	print("Sphere dialog ready; boundary entries=",editor.boundary.item_count)
	editor.boundary.select(5);editor.refresh_fields()
	assert(editor.captions[0].text.contains("strain"))
	editor.numbers[0].value=0.001
	assert(absf(editor.numbers[0].value-0.001)<1e-12)
	editor.boundary.select(1);editor.refresh_fields()
	assert(editor.numbers[0].max_value==1e12)
	var entry={"command":"ApplySphereExpansion","args":{"strain":0.001}}
	assert(load("res://core/cae/condition_catalog.gd").edited_args(entry,[0.002]).strain==0.002)
	editor.queue_free();await process_frame
	print("Sphere dialog expansion fields and condition editing PASS")
	quit()
