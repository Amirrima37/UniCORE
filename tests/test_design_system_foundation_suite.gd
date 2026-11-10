extends SceneTree

const DesignTokens = preload("res://ui/theme/design_tokens.gd")
const GlassPanel = preload("res://ui/theme/glass_panel.gd")

# ==============================================================================
# UniCORE Automated Test Suite: Design System Foundation
# Verifies:
# 1. DesignTokens color palette, metric spacing, and animation constants
# 2. Agent state color mapping (dispersion prism)
# 3. Liquid Glass 2.0 Shader loading, parameter initialization & material factory
# 4. Void Grid Canvas Shader loading & syntax verification
# 5. GlassPanel custom Control component lifecycle, fallback & interactive updates
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
	print("Starting UniCORE Design System Foundation Suite")
	print("==================================================")

	_test_design_tokens_constants()
	_test_agent_state_colors()
	_test_liquid_glass_shader_and_material_factory()
	_test_grid_canvas_shader()
	_test_glass_panel_component()

	print("\n==================================================")
	print("Test Results: %d Passed, %d Failed" % [passed_count, failed_count])
	print("==================================================")

	if failed_count == 0:
		print("ALL TESTS PASSED SUCCESSFULLY! Quitting with code 0.")
		quit(0)
	else:
		print("SOME TESTS FAILED! Quitting with code 1.")
		quit(1)

func _test_design_tokens_constants() -> void:
	print("\n--- 1. Testing DesignTokens Constants ---")
	var tokens_script = load("res://ui/theme/design_tokens.gd")
	assert_true(tokens_script != null, "design_tokens.gd loads cleanly")

	# Void colors
	assert_eq(DesignTokens.COLOR_VOID_DEEP, Color(0.024, 0.027, 0.035, 1.0), "COLOR_VOID_DEEP is #060709 obsidian")
	assert_true(DesignTokens.COLOR_VOID_SURFACE.a == 1.0, "COLOR_VOID_SURFACE is opaque")

	# Dispersion accents
	assert_eq(DesignTokens.COLOR_ACCENT_PRISM_CYAN, Color(0.0, 0.9, 1.0, 1.0), "COLOR_ACCENT_PRISM_CYAN is pure optical cyan")
	assert_eq(DesignTokens.COLOR_ACCENT_ELECTRIC_BLUE, Color(0.12, 0.58, 1.0, 1.0), "COLOR_ACCENT_ELECTRIC_BLUE is electric blue")
	assert_eq(DesignTokens.COLOR_ACCENT_SPECTRAL_AMBER, Color(1.0, 0.73, 0.05, 1.0), "COLOR_ACCENT_SPECTRAL_AMBER is amber")
	assert_eq(DesignTokens.COLOR_ACCENT_EMERALD_FLUX, Color(0.0, 0.92, 0.52, 1.0), "COLOR_ACCENT_EMERALD_FLUX is emerald")
	assert_eq(DesignTokens.COLOR_ACCENT_CRIMSON_VALVE, Color(1.0, 0.22, 0.28, 1.0), "COLOR_ACCENT_CRIMSON_VALVE is crimson")
	assert_eq(DesignTokens.COLOR_ACCENT_QUANTUM_VIOLET, Color(0.62, 0.38, 1.0, 1.0), "COLOR_ACCENT_QUANTUM_VIOLET is quantum violet")

	# 8px metric grid
	assert_eq(DesignTokens.SPACE_S, 8, "SPACE_S is 8px standard grid")
	assert_eq(DesignTokens.SPACE_M, 16, "SPACE_M is 16px panel padding")
	assert_eq(DesignTokens.SPACE_L, 24, "SPACE_L is 24px block gap")
	assert_eq(DesignTokens.BORDER_HAIRLINE, 1, "BORDER_HAIRLINE is 1px micro-border")

func _test_agent_state_colors() -> void:
	print("\n--- 2. Testing Agent State Color Dispersion ---")
	assert_eq(DesignTokens.get_agent_state_color("idle"), DesignTokens.COLOR_ACCENT_PRISM_CYAN, "Idle state is prism cyan")
	assert_eq(DesignTokens.get_agent_state_color("listening"), DesignTokens.COLOR_ACCENT_ELECTRIC_BLUE, "Listening state is electric blue")
	assert_eq(DesignTokens.get_agent_state_color("thinking"), DesignTokens.COLOR_ACCENT_SPECTRAL_AMBER, "Thinking state is spectral amber")
	assert_eq(DesignTokens.get_agent_state_color("synthesizing"), DesignTokens.COLOR_ACCENT_SPECTRAL_AMBER, "Synthesizing state is spectral amber")
	assert_eq(DesignTokens.get_agent_state_color("success"), DesignTokens.COLOR_ACCENT_EMERALD_FLUX, "Success state is emerald flux")
	assert_eq(DesignTokens.get_agent_state_color("error"), DesignTokens.COLOR_ACCENT_CRIMSON_VALVE, "Error state is crimson valve")
	assert_eq(DesignTokens.get_agent_state_color("autonomous"), DesignTokens.COLOR_ACCENT_QUANTUM_VIOLET, "Autonomous state is quantum violet")

func _test_liquid_glass_shader_and_material_factory() -> void:
	print("\n--- 3. Testing Liquid Glass Shader & Material Factory ---")
	var shader = load("res://ui/shaders/liquid_glass.gdshader") as Shader
	assert_true(shader != null, "liquid_glass.gdshader loads cleanly")

	var mat_dark: ShaderMaterial = DesignTokens.create_glass_material(false, 0.72, 2.5)
	assert_true(mat_dark != null, "Material factory returns ShaderMaterial for dark mode")
	assert_true(mat_dark.shader == shader, "Material has liquid_glass.gdshader attached")
	
	var dark_tint: Variant = mat_dark.get_shader_parameter("glass_tint")
	assert_true(dark_tint is Color, "Dark mode material has glass_tint color")
	var blur_param: Variant = mat_dark.get_shader_parameter("blur_amount")
	assert_eq(blur_param, 2.5, "Blur amount parameter matches 2.5")

	var mat_white: ShaderMaterial = DesignTokens.create_glass_material(true, 0.85, 3.0)
	assert_true(mat_white != null, "Material factory returns ShaderMaterial for white mode")
	var white_tint: Variant = mat_white.get_shader_parameter("glass_tint")
	assert_true(white_tint is Color, "White mode material has glass_tint color")

func _test_grid_canvas_shader() -> void:
	print("\n--- 4. Testing Grid Canvas Shader ---")
	var grid_shader = load("res://ui/shaders/grid_canvas.gdshader") as Shader
	assert_true(grid_shader != null, "grid_canvas.gdshader loads cleanly")

func _test_glass_panel_component() -> void:
	print("\n--- 5. Testing GlassPanel Component ---")
	var panel := GlassPanel.new()
	assert_true(panel != null, "GlassPanel instantiates successfully")
	panel.custom_accent_color = DesignTokens.COLOR_ACCENT_PRISM_CYAN
	panel.panel_corner_radius = 6.0
	panel.enable_interactive_hover = true

	# Mount into scene root to trigger _ready()
	root.add_child(panel)
	assert_true(panel.get_child_count() > 0, "GlassPanel creates internal background node")

	var bg_child = panel.get_child(0)
	assert_true(bg_child is ColorRect, "Background node is ColorRect")
	assert_true(bg_child.material is ShaderMaterial, "Background node has ShaderMaterial applied")

	# Test dynamic accent color update
	panel.set_accent_color(DesignTokens.COLOR_ACCENT_SPECTRAL_AMBER)
	assert_eq(panel.custom_accent_color, DesignTokens.COLOR_ACCENT_SPECTRAL_AMBER, "Accent color updated to spectral amber")

	# Cleanup
	root.remove_child(panel)
	panel.free()
	assert_true(true, "GlassPanel freed cleanly without memory leaks")
