extends AcceptDialog
var workspace
var status: Label
func configure(w,part: Dictionary):
	workspace=w;title="Native OCCT geometry validation";size=Vector2i(600,340)
	status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status.custom_minimum_size=Vector2(560,280);add_child(status)
	status.text="Running BRepCheck_Analyzer and physical/topological checks..."
	var request={"action":"validate","part":part.duplicate(true)} if part.has("cad_base64") else {"action":"validate_model","model":preload("res://core/cae/cad_model.gd").from_part(part)}
	if not w.start_cad_geometry(request,self):status.text="Wait for the active geometry operation"
	confirmed.connect(queue_free)
	canceled.connect(func():workspace.cancel_cad_geometry();queue_free())
func completed(result: Dictionary):
	if not result.get("ok",false):status.text=str(result.get("error","Native validation failed"));return
	var v=result.validation
	status.text="%s\nSolids: %s   Faces: %s\nVolume: %s m³\nSurface area: %s m²\nCentroid: %s m\nMaximum tolerance: %s m\nClosed shells: %s\nProblems: %s\n\nValidity does not guarantee meshing success or exclude every self-intersection." % [str(v.status),str(v.solid_count),str(v.face_count),str(v.volume),str(v.area),str(v.centroid),str(v.maximum_tolerance_m),str(v.closed_shells),str(v.diagnostics)]
