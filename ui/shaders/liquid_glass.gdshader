shader_type canvas_item;

// UniCORE Design System — Optical Quartz / Liquid Glass 2.0 Shader
// Physical simulation of frosted optical quartz glass with:
// - Backdrop blur via mipmap LOD sampling
// - Chromatic dispersion (RGB lens offset)
// - 1px hairline edge light & specular sheen
// - Micro-grain dithering against 8-bit color banding
// - Procedural rounded box mask with sub-pixel antialiasing

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// Base Tint & Refraction
uniform vec4 glass_tint : source_color = vec4(0.04, 0.07, 0.12, 0.72);
uniform float blur_amount : hint_range(0.0, 5.0) = 2.5;
uniform float chromatic_dispersion : hint_range(0.0, 0.02) = 0.0035;

// Rim & Edge Lighting
uniform vec4 rim_color : source_color = vec4(0.0, 0.85, 1.0, 0.45);
uniform float rim_thickness : hint_range(0.5, 4.0) = 1.0;
uniform float rim_boost : hint_range(0.0, 3.0) = 1.2;

// Optical Surface Features
uniform float noise_intensity : hint_range(0.0, 0.1) = 0.02;
uniform float sheen_intensity : hint_range(0.0, 1.0) = 0.15;
uniform float corner_radius : hint_range(0.0, 32.0) = 4.0;

// High-speed procedural PRNG for micro-grain dithering
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// 2D Signed Distance Field for antialiased rounded rectangle
float sd_rounded_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

void fragment() {
	// 1. Calculate pixel dimensions based on texture/rect size
	vec2 pixel_size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 half_size = pixel_size * 0.5;
	vec2 pos_centered = (UV - vec2(0.5)) * pixel_size;
	
	// 2. Evaluate Signed Distance Field
	float dist = sd_rounded_box(pos_centered, half_size, corner_radius);
	
	// Sub-pixel antialiasing mask
	float aa_width = fwidth(dist);
	float shape_mask = 1.0 - smoothstep(0.0, max(aa_width, 0.001), dist);
	
	// Discard pixels outside the rounded shape
	if (shape_mask <= 0.001) {
		discard;
	}

	// 3. Screen space optical chromatic dispersion
	vec2 screen_center_offset = (SCREEN_UV - vec2(0.5));
	vec2 dispersion_dir = normalize(screen_center_offset + vec2(0.0001));
	float dispersion_dist = length(screen_center_offset) * chromatic_dispersion;
	vec2 r_offset = dispersion_dir * dispersion_dist;
	vec2 b_offset = -dispersion_dir * dispersion_dist;

	// Backdrop sampling with LOD blur and chromatic shift
	float bg_r = textureLod(screen_texture, SCREEN_UV + r_offset, blur_amount).r;
	float bg_g = textureLod(screen_texture, SCREEN_UV, blur_amount).g;
	float bg_b = textureLod(screen_texture, SCREEN_UV + b_offset, blur_amount).b;
	vec3 blurred_backdrop = vec3(bg_r, bg_g, bg_b);

	// 4. Subtle micro-grain noise to eliminate color banding on dark glass
	float grain = (hash(SCREEN_UV * 1000.0 + fract(TIME * 0.01)) - 0.5) * noise_intensity;
	blurred_backdrop += vec3(grain);

	// 5. Blend glass tint with blurred background
	vec3 glass_color = mix(blurred_backdrop, glass_tint.rgb, glass_tint.a);

	// 6. Hairline 1px Rim Light and Top Sheen
	// Edge detection using SDF distance
	float rim_mask = smoothstep(0.0, -rim_thickness, dist);
	float edge_factor = 1.0 - rim_mask; // 1.0 at outer edge, drops inside
	
	// Top-to-bottom anisotropic sheen (light incident from top)
	float top_sheen = smoothstep(0.8, 0.0, UV.y) * sheen_intensity;
	glass_color += vec3(top_sheen);

	// Edge rim highlight with tint
	vec3 final_rgb = mix(glass_color, rim_color.rgb * rim_boost, edge_factor * rim_color.a);

	// Final alpha compositing
	COLOR = vec4(final_rgb, shape_mask);
}
