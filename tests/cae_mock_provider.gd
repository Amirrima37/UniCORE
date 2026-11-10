extends "res://agent/providers/base_llm_provider.gd"
var next_response := ""
var last_system := ""
var last_user := ""
var sends := 0
func send_prompt(system: String,user: String,_key: String) -> void:
	last_system=system
	last_user=user
	sends+=1
	if not next_response.is_empty(): call_deferred("emit_signal","response_received",next_response)

