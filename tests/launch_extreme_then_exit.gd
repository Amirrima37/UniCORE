extends SceneTree
func _initialize():
	var directory:=ProjectSettings.globalize_path("res://.tools/lifetime-large")
	var pid:=OS.create_process(ProjectSettings.globalize_path("res://bin/unicore_solver.exe"),PackedStringArray(["--job",directory+"/model.ucjob","--output",directory,"--threads","2","--memory-mb","2048"]))
	assert(pid>0)
	var file:=FileAccess.open("res://docs/extreme-mode/lifetime-job.txt",FileAccess.WRITE);file.store_string(directory);file.close();quit()
