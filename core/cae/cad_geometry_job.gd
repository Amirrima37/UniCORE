extends RefCounted
var directory=""
var cancelled=false
var timeout_seconds=45.0
func cancel():
	cancelled=true
	if not directory.is_empty():
		var f=FileAccess.open(directory+"/cancel",FileAccess.WRITE)
		if f:f.close()
func evaluate(request: Dictionary) -> Dictionary:
	directory="user://cad_geometry/"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())+"_"+Crypto.new().generate_random_bytes(8).hex_encode()
	if DirAccess.make_dir_recursive_absolute(directory)!=OK:return {"ok":false,"error":"Cannot create owned CAD job"}
	var f=FileAccess.open(directory+"/request.json",FileAccess.WRITE)
	if f==null:return {"ok":false,"error":"Cannot write CAD request"}
	f.store_string(JSON.stringify(request,"",true,true));f.close()
	if cancelled:cancel()
	var python=OS.get_environment("UNICORE_PYTHON")
	if python.is_empty():python=OS.get_environment("LOCALAPPDATA")+"/Python/pythoncore-3.14-64/python.exe"
	var output=[]
	var code=OS.execute(python,PackedStringArray([ProjectSettings.globalize_path("res://scripts/engines/run_owned_geometry.py"),ProjectSettings.globalize_path(directory),str(timeout_seconds),str(OS.get_process_id())]),output,true)
	var receipt=JSON.parse_string(FileAccess.get_file_as_string(directory+"/receipt.json"))
	if cancelled or code!=0 or not receipt is Dictionary or receipt.get("state")!="completed":return {"ok":false,"error":"CAD operation cancelled/failed/timed out: "+str(receipt)+". Logs: "+ProjectSettings.globalize_path(directory)}
	var source=FileAccess.open(directory+"/result.json",FileAccess.READ)
	if source==null or source.get_length()>96*1024*1024:return {"ok":false,"error":"CAD result missing or exceeds 96 MiB"}
	source.close()
	var result=JSON.parse_string(FileAccess.get_file_as_string(directory+"/result.json"))
	return result if result is Dictionary else {"ok":false,"error":"Malformed CAD result"}
