extends SceneTree

func _init() -> void:
	print("\n=== [TEST] INTERACTIVE TIME BAR VERIFICATION ===")
	_run()

func _run() -> void:
	var counters: Array[int] = [0, 0] # [passed, failed]

	var assert_fn := func(cond: bool, test_name: String) -> void:
		if cond:
			counters[0] += 1
			print("  [PASS] %s" % test_name)
		else:
			counters[1] += 1
			print("  [FAIL] %s" % test_name)

	# 1. Instantiate EventBus and SimulationTimeController
	var EventBusScript = load("res://core/event_bus.gd")
	var eb = EventBusScript.new()
	root.add_child(eb)

	var TimeControllerScript = load("res://core/physics/simulation_time_controller.gd")
	var time_ctrl = TimeControllerScript.new()
	root.add_child(time_ctrl)
	time_ctrl.setup(eb)

	# 2. Instantiate PhysicsTimeBar
	var TimeBarScene = load("res://ui/physics/physics_time_bar.tscn")
	var time_bar = TimeBarScene.instantiate()
	root.add_child(time_bar)
	await process_frame
	time_bar.setup(eb)

	# Test 1: Setup and initial state
	assert_fn.call(time_ctrl.is_paused == false, "TimeController starts running (is_paused == false)")
	assert_fn.call(is_equal_approx(time_ctrl.time_scale, 1.0), "TimeController starts with scale 1.0")
	assert_fn.call(time_bar.btn_play_pause.text == "⏸ ПАУЗА", "Button shows '⏸ ПАУЗА' initially")

	# Test 2: Clicking BtnPlayPause to pause
	time_bar.btn_play_pause.set_pressed(true)
	assert_fn.call(time_ctrl.is_paused == true, "Clicking BtnPlayPause pauses TimeController (is_paused == true)")
	assert_fn.call(time_bar.btn_play_pause.text == "▶ ПУСК", "Button updates text to '▶ ПУСК'")

	# Test 3: Clicking BtnPlayPause to resume
	time_bar.btn_play_pause.set_pressed(false)
	assert_fn.call(time_ctrl.is_paused == false, "Clicking BtnPlayPause resumes TimeController (is_paused == false)")
	assert_fn.call(time_bar.btn_play_pause.text == "⏸ ПАУЗА", "Button updates text back to '⏸ ПАУЗА'")

	# Test 4: External pause command reflects in TimeBar UI
	time_ctrl.set_paused(true)
	assert_fn.call(time_bar.btn_play_pause.button_pressed == true, "External set_paused(true) toggles button pressed state")
	assert_fn.call(time_bar.btn_play_pause.text == "▶ ПУСК", "External set_paused(true) updates button text to '▶ ПУСК'")

	# Test 5: Step button advances sim_time by fixed_delta
	var t0: float = time_ctrl.sim_time
	time_bar.btn_step.emit_signal("pressed")
	assert_fn.call(is_equal_approx(time_ctrl.sim_time, t0 + time_ctrl.fixed_delta), "BtnStep advances sim_time by fixed_delta (0.01s)")

	# Test 6: Preset scale buttons (0.1x, 10x, 100x)
	time_bar.btn_scale_10.emit_signal("pressed")
	assert_fn.call(is_equal_approx(time_ctrl.time_scale, 10.0), "BtnScale10 sets time_scale to 10.0")

	time_bar.btn_scale_01.emit_signal("pressed")
	assert_fn.call(is_equal_approx(time_ctrl.time_scale, 0.1), "BtnScale01 sets time_scale to 0.1")

	time_bar.btn_scale_100.emit_signal("pressed")
	assert_fn.call(is_equal_approx(time_ctrl.time_scale, 100.0), "BtnScale100 sets time_scale to 100.0")

	time_bar.btn_scale_1.emit_signal("pressed")
	assert_fn.call(is_equal_approx(time_ctrl.time_scale, 1.0), "BtnScale1 sets time_scale back to 1.0")

	# Test 7: Slider time scale interaction
	time_bar.slider_time_scale.value = 5.0
	assert_fn.call(is_equal_approx(time_ctrl.time_scale, 5.0), "Slider change sets time_scale to 5.0")

	# Test 8: External time scale change reflects in TimeBar
	time_ctrl.set_time_scale(2.5)
	assert_fn.call(is_equal_approx(time_bar.slider_time_scale.value, 2.5), "External set_time_scale(2.5) updates TimeBar slider")

	# Test 9: Telemetry tick updates sim_time label
	eb.publish("physics_time_tick", {"delta": 0.01, "sim_time": 12.345})
	assert_fn.call(time_bar.label_sim_time.text == "t = 12.345 s", "Telemetry tick updates label to 't = 12.345 s'")

	# Cleanup
	time_bar.queue_free()
	time_ctrl.queue_free()
	eb.queue_free()

	print("\nInteractive Time Bar summary: passed=%d, failed=%d" % [counters[0], counters[1]])
	quit(counters[1])
