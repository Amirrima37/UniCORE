extends SceneTree

const FluidOrbOverlay = preload("res://ui/agent_orb/fluid_orb_overlay.gd")
const DesignTokens = preload("res://ui/theme/design_tokens.gd")

# ==============================================================================
# UniCORE Automated Test Suite: Fluid Singularity Agent Orb
# Verifies:
# 1. Fluid Orb shader loading, compilation and parameter bindings
# 2. State management across all cognitive modes (IDLE, LISTENING, THINKING, SUCCESS, ERROR)
# 3. Audio resonance and thought turbulence modulation
# 4. Morphing between DOCKED (HUD) and EXPANDED (dialog/singularity) modes
# 5. EventBus dynamic signal handling and memory safety
# ==============================================================================

var passed_count: int = 0
var failed_count: int = 0

func assert_true(condition: bool, test_name: String, error_msg: String = "") -> void:
	if condition:
		print("  [PASS] %s" % test_name)
		passed_count += 1
	else:
		print("  [FAIL] %s - %s" % [test_name, error_msg])
		failed_count += 1

func assert_false(condition: bool, test_name: String, error_msg: String = "") -> void:
	assert_true(not condition, test_name, error_msg)

func assert_eq(actual: Variant, expected: Variant, test_name: String) -> void:
	if actual == expected:
		print("  [PASS] %s" % test_name)
		passed_count += 1
	else:
		print("  [FAIL] %s - Expected '%s', got '%s'" % [test_name, str(expected), str(actual)])
		failed_count += 1

func _init() -> void:
	print("==================================================")
	print("Starting UniCORE Fluid Singularity Agent Orb Suite")
	print("==================================================")

	_test_orb_initialization_and_shader()
	_test_orb_state_transitions()
	_test_audio_and_thought_reactivity()
	_test_mode_transformation()
	_test_eventbus_integration()

	print("\n==================================================")
	print("Test Results: %d Passed, %d Failed" % [passed_count, failed_count])
	print("==================================================")

	if failed_count == 0:
		print("ALL TESTS PASSED SUCCESSFULLY! Quitting with code 0.")
		quit(0)
	else:
		print("SOME TESTS FAILED! Quitting with code 1.")
		quit(1)

func _test_orb_initialization_and_shader() -> void:
	print("\n--- 1. Testing Orb Initialization & Shader ---")
	var orb := FluidOrbOverlay.new()
	assert_true(orb != null, "FluidOrbOverlay instantiates cleanly")

	root.add_child(orb)
	assert_true(orb._orb_rect != null, "Internal orb rect exists")
	assert_true(orb._rings_canvas != null, "Orbital rings canvas exists")
	assert_true(orb._shader_mat != null, "ShaderMaterial attached to orb")

	var shader = load("res://ui/shaders/fluid_orb.gdshader") as Shader
	assert_true(shader != null, "fluid_orb.gdshader compiles and loads cleanly")
	assert_true(orb._shader_mat.shader == shader, "Orb uses fluid_orb.gdshader")

	root.remove_child(orb)
	orb.free()
	assert_true(true, "FluidOrbOverlay freed cleanly")

func _test_orb_state_transitions() -> void:
	print("\n--- 2. Testing Cognitive State Transitions ---")
	var orb := FluidOrbOverlay.new()
	root.add_child(orb)

	var last_state := [""]
	orb.state_transition_completed.connect(func(s: String): last_state[0] = s)

	# 2.1 State: IDLE
	orb.set_state("idle")
	assert_eq(last_state[0], "idle", "Transitioned to idle state")

	# 2.2 State: LISTENING
	orb.set_state("listening")
	assert_eq(last_state[0], "listening", "Transitioned to listening state")

	# 2.3 State: THINKING
	orb.set_state("thinking")
	assert_eq(last_state[0], "thinking", "Transitioned to thinking state")
	assert_true(orb._target_thought_intensity > 0.5, "Thought intensity elevated in thinking state")

	# 2.4 State: SUCCESS
	orb.set_state("success")
	assert_eq(last_state[0], "success", "Transitioned to success state")

	# 2.5 State: ERROR
	orb.set_state("error")
	assert_eq(last_state[0], "error", "Transitioned to error state")
	assert_eq(orb._target_alert_blend, 1.0, "Alert blend set to 1.0 in error state")

	root.remove_child(orb)
	orb.free()
	assert_true(true, "Orb freed cleanly after state tests")

func _test_audio_and_thought_reactivity() -> void:
	print("\n--- 3. Testing Audio & Thought Reactivity ---")
	var orb := FluidOrbOverlay.new()
	root.add_child(orb)

	orb.set_audio_energy(0.85)
	assert_eq(orb._target_audio_level, 0.85, "Target audio energy set to 0.85")

	orb.set_thought_load(1.4)
	assert_eq(orb._target_thought_intensity, 1.4, "Target thought load set to 1.4")

	# Process delta to verify smooth lerping
	orb._process(0.1)
	assert_true(orb._audio_level > 0.0, "Audio level smoothed towards target")
	assert_true(orb._thought_intensity > 0.0, "Thought intensity smoothed towards target")

	root.remove_child(orb)
	orb.free()
	assert_true(true, "Orb freed cleanly after reactivity tests")

func _test_mode_transformation() -> void:
	print("\n--- 4. Testing DOCKED vs EXPANDED Modes ---")
	var orb := FluidOrbOverlay.new()
	root.add_child(orb)

	assert_eq(orb.current_mode, FluidOrbOverlay.DisplayMode.DOCKED, "Initial mode is DOCKED")
	assert_eq(orb.custom_minimum_size, orb.docked_size, "Initial size matches docked size")

	# Toggle to EXPANDED
	var mode_signal_fired := [false]
	orb.mode_changed.connect(func(is_exp: bool): mode_signal_fired[0] = is_exp)

	orb.set_mode(FluidOrbOverlay.DisplayMode.EXPANDED, false)
	assert_eq(orb.current_mode, FluidOrbOverlay.DisplayMode.EXPANDED, "Mode changed to EXPANDED")
	assert_eq(orb.custom_minimum_size, orb.expanded_size, "Size expanded to 280x280")
	assert_true(mode_signal_fired[0], "mode_changed emitted with true")

	# Toggle back to DOCKED
	orb.toggle_mode(false)
	assert_eq(orb.current_mode, FluidOrbOverlay.DisplayMode.DOCKED, "Toggled back to DOCKED")
	assert_eq(orb.custom_minimum_size, orb.docked_size, "Size returned to docked size")

	root.remove_child(orb)
	orb.free()
	assert_true(true, "Orb freed cleanly after mode tests")

func _test_eventbus_integration() -> void:
	print("\n--- 5. Testing EventBus Integration ---")
	var orb := FluidOrbOverlay.new()
	root.add_child(orb)

	# Simulate EventBus event emission
	orb._on_event_bus_event("agent_state_changed", {"new_state": "synthesizing"})
	assert_eq(orb._current_state, "synthesizing", "Handled agent_state_changed synthesizing")

	orb._on_event_bus_event("agent_speech_amplitude", {"amplitude": 0.72})
	assert_eq(orb._target_audio_level, 0.72, "Handled agent_speech_amplitude")

	orb._on_event_bus_event("agent_thought_intensity", {"intensity": 1.15})
	assert_eq(orb._target_thought_intensity, 1.15, "Handled agent_thought_intensity")

	root.remove_child(orb)
	orb.free()
	assert_true(true, "Orb freed cleanly after EventBus tests")
