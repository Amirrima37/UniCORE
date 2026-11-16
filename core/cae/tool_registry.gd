extends RefCounted
## UI adapters register real handlers; planned domains never get executable handlers.
var tools: Array = []

func register(category: String, title: String, action: Callable, available: Callable = Callable(), shortcut: String = "", status: String = "implemented", icon: String = "command") -> String:
	assert(status in ["implemented", "experimental", "planned"])
	var id := category.to_snake_case() + "." + title.to_snake_case()
	assert(not tools.any(func(tool): return tool.id == id), "Duplicate tool: " + id)
	tools.append({"id":id,"category":category,"title":title,"action":action,"available":available,"shortcut":shortcut,"status":status,"icon":icon})
	return id

func reason(tool: Dictionary) -> String:
	if tool.status == "planned": return "Planned capability; unavailable"
	return str(tool.available.call()) if tool.available.is_valid() else ""

func execute(id: String) -> String:
	for tool in tools:
		if tool.id != id: continue
		var error := reason(tool)
		if not error.is_empty(): return error
		tool.action.call()
		return ""
	return "Unknown tool: " + id

func search(query: String) -> Array:
	var words := query.to_lower().split(" ", false)
	return tools.filter(func(tool):
		var haystack: String = (tool.category + " " + tool.title + " " + tool.shortcut).to_lower()
		for word in words:
			if not word in haystack: return false
		return true)
