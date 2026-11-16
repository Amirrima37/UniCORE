extends RefCounted
## Visibility is exclusively presentation. Analysis selects solely by this flag.
static func signature(data: Dictionary) -> Array:
	var result=[]
	for p in data.parts:result.append([p.get("instance_uuid",p.id),p.get("analysis_enabled",true)])
	return result
static func error(data: Dictionary) -> String:
	var count=0
	for p in data.parts:
		if not p.get("analysis_enabled",true) is bool:return "Analysis participation must be boolean"
		if p.get("analysis_enabled",true):count+=1
	return "Enable at least one instance for analysis" if count==0 else ""
static func view(data: Dictionary) -> Dictionary:
	var result=data.duplicate(false)
	result.parts=data.parts.filter(func(p):return p.get("analysis_enabled",true))
	result._participation_resolved=true
	result._analysis_participation=signature(data)
	return result
