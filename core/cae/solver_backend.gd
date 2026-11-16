extends RefCounted
## Versioned orchestration contract. Adapters must reject unsupported mappings.
func capabilities() -> Dictionary:
	return {"schema":1,"id":"","analyses":[],"elements":[]}
func dependency_status() -> Dictionary:
	return {"status":"missing_dependency","diagnostic":"Adapter not configured"}
func validate_model(_model: Dictionary) -> Array:
	return ["Backend export is not implemented"]
func prepare_job(_model: Dictionary, _directory: String) -> Dictionary:
	return {"error":"Backend export is not implemented"}
func execute_job(_job: Dictionary) -> Dictionary:
	return {"error":"Backend execution is not implemented"}
func progress(_job: Dictionary) -> Dictionary:
	return {"state":"unavailable"}
func cancel_job(_job: Dictionary) -> String:
	return "No owned process"
func import_results(_job: Dictionary) -> Dictionary:
	return {"error":"Backend result import is not implemented"}
