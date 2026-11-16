extends SceneTree
func _initialize():call_deferred("run")
func run():
	var baseline=Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var w=load("res://ui/cae/cae_workspace.gd").new();root.add_child(w);w.set_active(true)
	assert(w.document.open_project(OS.get_environment("UNICORE_E_GUI_SOURCE")+"/gui-restored.json").is_empty())
	while w.cad_preview_thread!=null:await process_frame
	for i in 40:
		w.inspector_id="";w.select_body(i%2)
		await process_frame
	w.queue_free();w=null
	for i in 20:await process_frame
	var count=Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	assert(count==baseline,"Inspector must release unattached topology controls")
	print("INSPECTOR_LIFECYCLE_PASS ",baseline," -> ",count);quit()
