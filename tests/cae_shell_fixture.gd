extends "res://core/space_viewport.gd"
func _setup_network_layer() -> void:
	pass
func _setup_llm_provider() -> void:
	var provider=preload("res://tests/cae_mock_provider.gd").new()
	agent_brain.add_child(provider)
	agent_brain.setup(event_bus,module_manager,provider)
	agent_brain.api_key="test"
