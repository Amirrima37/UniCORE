extends RefCounted
var thread := Thread.new()
var mutex := Mutex.new()
var cancelled := false
var stage := "Queued"
var generation := 0
var source: Dictionary
var copy_index := 0
var copying := false
var snapshot: Dictionary
var reuse := {}
var metric := "jacobian"
var palette := "viridis"
var fraction := 1.0
func progress(value: String) -> bool:
	mutex.lock()
	stage=value
	var keep := not cancelled
	mutex.unlock()
	return keep
func cancel() -> void:
	mutex.lock(); cancelled=true; mutex.unlock()
func status() -> String:
	mutex.lock(); var value:=stage; mutex.unlock(); return value
func start(mesh: Dictionary, version: int, section: float, chunked := false) -> void:
	generation=version;fraction=section
	if not chunked:
		snapshot=mesh.duplicate(true);thread.start(run);return
	# Document revisions replace mesh arrays instead of mutating retained revisions.
	# Clone rows over bounded main-thread slices; workers receive only the completed copy.
	source=mesh.duplicate(false);snapshot=mesh.duplicate(false)
	snapshot.erase("nodes");snapshot.erase("elements");snapshot=snapshot.duplicate(true)
	snapshot.nodes=[];snapshot.elements=[];copying=true;stage="Snapshot"
func pump_snapshot() -> bool:
	if not copying:return true
	if not progress("Snapshot %d / %d" % [copy_index,source.nodes.size()+source.elements.size()]):copying=false;return true
	var deadline:=Time.get_ticks_usec()+2000
	var count: int=source.nodes.size()+source.elements.size()
	while copy_index<count and Time.get_ticks_usec()<deadline:
		if copy_index<source.nodes.size():snapshot.nodes.append(source.nodes[copy_index].duplicate())
		else:snapshot.elements.append(source.elements[copy_index-source.nodes.size()].duplicate())
		copy_index+=1
	if copy_index==count:
		copying=false;source={};thread.start(run)
	return not copying
func run():
	var prepared=load("res://core/cae/mesh_inspection.gd").new()
	if not prepared.prepare(snapshot,progress,reuse): return null
	if not progress("Section topology"): return null
	prepared.section(fraction,progress)
	for kind in ["solid","edges","nodes"]:
		if not progress("Buffers: "+kind): return null
		prepared.buffer_cache[kind]=prepared.geometry_arrays(kind)
	if not progress("Contour buffers"):return null
	prepared.contour_data(metric,false,palette)
	if not progress("Ready"): return null
	return prepared
