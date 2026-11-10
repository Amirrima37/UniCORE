shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// =============================================================================
// UniCORE Particle Field Glow Shader
// Milestone 3: Modular Physics Simulation Domains
// Visualizes particle kinetic energy/temperature gradient with incandescent glow
// and Fresnel rim radiance in the Detroit Liquid Glass visual aesthetic.
// =============================================================================

// Thermodynamic Spectral Colors
uniform vec4 cold_color : source_color = vec4(0.08, 0.45, 1.0, 1.0);     // Cold cyan-blue
uniform vec4 medium_color : source_color = vec4(1.0, 0.82, 0.12, 1.0);   // Thermal amber-yellow
uniform vec4 hot_color : source_color = vec4(1.0, 0.15, 0.05, 1.0);      // High-energy radiant red

// Lighting & Shading Uniforms
uniform float emission_intensity : hint_range(0.0, 10.0) = 2.5;
uniform float glow_falloff : hint_range(0.5, 8.0) = 2.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.25;
uniform float metallic : hint_range(0.0, 1.0) = 0.1;
uniform bool enable_billboard = false;

// Varying bridge between vertex instance data and fragment shader
varying vec4 v_custom_data;

void vertex() {
	// Bridge MultiMesh INSTANCE_CUSTOM to fragment stage
	v_custom_data = INSTANCE_CUSTOM;
	
	if (enable_billboard) {
		// Spherical billboard preserving model scaling
		mat4 billboard_matrix = VIEW_MATRIX * mat4(
			INV_VIEW_MATRIX[0],
			INV_VIEW_MATRIX[1],
			INV_VIEW_MATRIX[2],
			MODEL_MATRIX[3]
		);
		MODELVIEW_MATRIX = billboard_matrix;
	}
}

vec3 evaluate_temperature_ramp(float t) {
	float s = clamp(t, 0.0, 1.0);
	if (s < 0.5) {
		// Low to medium temperature transition (Cold Blue -> Warm Amber)
		return mix(cold_color.rgb, medium_color.rgb, s * 2.0);
	} else {
		// Medium to high temperature transition (Warm Amber -> Radiant Hot Red)
		return mix(medium_color.rgb, hot_color.rgb, (s - 0.5) * 2.0);
	}
}

void fragment() {
	// Extract normalized kinetic temperature/speed parameter t
	float t = 0.0;
	if (v_custom_data.a > 0.0) {
		// Reading normalized speed from INSTANCE_CUSTOM.r
		t = clamp(v_custom_data.r, 0.0, 1.0);
	} else if (COLOR.a > 0.0) {
		// Fallback to vertex COLOR.r attribute
		t = clamp(COLOR.r, 0.0, 1.0);
	}
	
	vec3 base_color = evaluate_temperature_ramp(t);
	
	// Fresnel rim glow calculation for Detroit Liquid Glass aesthetic
	float n_dot_v = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - n_dot_v, glow_falloff);
	
	ALBEDO = base_color * 0.75;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	
	// HDR Incandescent Glow: core emission + intense rim edge radiance
	EMISSION = base_color * emission_intensity * (0.8 + rim * 3.2);
}
