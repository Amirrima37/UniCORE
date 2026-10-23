shader_type canvas_item;

// UniCORE Design System — Mathematical Void Grid Canvas Shader
// Procedural laboratory coordinate space:
// - Orthogonal 1px hairline grid with anti-aliasing via fwidth()
// - Intersection coordinate crosshairs (+)
// - Radial vignette receding into deep obsidian void
// - Subtle pulsating energy waves driven by agent activity

uniform vec4 bg_color : source_color = vec4(0.024, 0.027, 0.035, 1.0);     // Void deep #060709
uniform vec4 grid_color : source_color = vec4(0.0, 0.9, 1.0, 0.06);        // Optical Cyan hairline
uniform vec4 crosshair_color : source_color = vec4(0.0, 0.9, 1.0, 0.18);   // Coordinate crosshairs
uniform float cell_size : hint_range(16.0, 128.0) = 32.0;
uniform float line_thickness : hint_range(0.5, 3.0) = 1.0;
uniform float crosshair_size : hint_range(2.0, 16.0) = 4.0;
uniform float vignette_falloff : hint_range(0.5, 3.0) = 1.4;
uniform float energy_wave_intensity : hint_range(0.0, 1.0) = 0.08;
uniform float energy_wave_speed : hint_range(0.1, 5.0) = 0.5;

void fragment() {
	vec2 pixel_pos = UV / TEXTURE_PIXEL_SIZE;
	
	// 1. Orthogonal coordinate grid using fract
	vec2 grid_uv = fract(pixel_pos / cell_size);
	vec2 dist_to_line = abs(grid_uv - vec2(0.5)) * cell_size;
	vec2 line_axis = min(dist_to_line, cell_size - dist_to_line);
	
	// Hairline anti-aliasing with fwidth
	vec2 fw = fwidth(pixel_pos);
	vec2 line_factor = 1.0 - smoothstep(vec2(0.0), fw * line_thickness, line_axis);
	float grid_mask = max(line_factor.x, line_factor.y);

	// 2. Intersection coordinate crosshairs (+)
	vec2 cross_dist = min(line_axis, vec2(crosshair_size));
	float cross_mask = 0.0;
	if (line_axis.x < line_thickness && line_axis.y < crosshair_size) {
		cross_mask = 1.0;
	}
	if (line_axis.y < line_thickness && line_axis.x < crosshair_size) {
		cross_mask = 1.0;
	}

	// 3. Radial distance & cinematic vignette
	vec2 centered_uv = UV - vec2(0.5);
	float radial_dist = length(centered_uv);
	float vignette = 1.0 - smoothstep(0.1, vignette_falloff * 0.7, radial_dist);

	// 4. Subtle procedural energy pulse
	float wave = sin(radial_dist * 12.0 - TIME * energy_wave_speed) * 0.5 + 0.5;
	float dynamic_pulse = wave * energy_wave_intensity * vignette;

	// Composite grid and crosshairs with vignette
	vec3 col = bg_color.rgb;
	col = mix(col, grid_color.rgb, grid_mask * grid_color.a * vignette + dynamic_pulse);
	col = mix(col, crosshair_color.rgb, cross_mask * crosshair_color.a * vignette);

	COLOR = vec4(col, 1.0);
}
