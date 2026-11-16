extends SceneTree
func _initialize():
	call_deferred("run_test")
func run_test():
	var bus=load("res://core/event_bus.gd").new()
	root.add_child(bus)
	var drawer=load("res://ui/analysis_drawer/analysis_drawer.tscn").instantiate()
	root.add_child(drawer)
	drawer.setup(bus)
	assert(bus.get_listener_count("interface_settings_changed")==1)
	bus.publish("interface_settings_changed",{})
	drawer.queue_free()
	await process_frame
	await process_frame
	assert(not is_instance_valid(drawer))
	# Exercise both cleanup entry points after the listener has been destroyed.
	bus.unsubscribe_all_for_target(self)
	bus.cleanup_invalid_listeners()
	assert(bus.get_listener_count("interface_settings_changed")==0)
	bus.publish("interface_settings_changed",{})
	bus.queue_free()
	print("AnalysisDrawer destroyed-owner listener pruning and publish PASS")
	quit(0)
