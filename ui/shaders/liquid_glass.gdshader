shader_type canvas_item;

// UniCORE Design System — True Refractive Liquid Glass 3.0 Shader
// Физическая оптическая симуляция «Жидкого стекла» (Detroit Liquid Glass):
// - 3D линзообразный скос (Curved Bevel) по контуру с градиентом SDF
// - Оптическое преломление (Snell's Refraction) фона SCREEN_UV
// - Спектральная хроматическая дисперсия (RGB Prism Aberration)
// - Френелевское краевое свечение (Fresnel Edge Glow)
// - Направленный зеркальный блик (Specular Lens Sheen)
// - Матовое размытие фона (Backdrop Mipmap LOD Blur)
// - Субпиксельное сглаживание и PRNG micro-dithering

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// Base Tint & Physical Optics
uniform vec4 glass_tint : source_color = vec4(0.04, 0.07, 0.12, 0.72);
uniform float blur_amount : hint_range(0.0, 5.0) = 2.0;
uniform float chromatic_dispersion : hint_range(0.0, 0.05) = 0.012;
uniform float refraction_strength : hint_range(0.0, 0.1) = 0.028;
uniform float bevel_width : hint_range(2.0, 48.0) = 16.0;

// Rim & Lighting
uniform vec4 rim_color : source_color = vec4(0.0, 0.85, 1.0, 0.55);
uniform float rim_thickness : hint_range(0.5, 4.0) = 1.0;
uniform float rim_boost : hint_range(0.0, 3.0) = 1.3;
uniform float specular_intensity : hint_range(0.0, 2.0) = 0.65;
uniform float fresnel_power : hint_range(1.0, 8.0) = 2.8;

// Surface Details & Geometry
uniform float noise_intensity : hint_range(0.0, 0.1) = 0.015;
uniform float sheen_intensity : hint_range(0.0, 1.0) = 0.2;
uniform float corner_radius : hint_range(0.0, 64.0) = 8.0;

// Procedural hash for micro-grain anti-banding dithering
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
	// 1. Вычисление физических пиксельных координат
	vec2 pixel_size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 half_size = pixel_size * 0.5;
	vec2 pos_centered = (UV - vec2(0.5)) * pixel_size;
	
	// 2. Расчет SDF для скругленного прямоугольника
	float dist = sd_rounded_box(pos_centered, half_size, corner_radius);
	
	// Субпиксельная маска контура сглаживания
	float aa_width = fwidth(dist);
	float shape_mask = 1.0 - smoothstep(0.0, max(aa_width, 0.001), dist);
	
	if (shape_mask <= 0.001) {
		discard;
	}

	// 3. Вычисление 2D градиента SDF (нормаль к контуру панели)
	vec2 eps = vec2(1.0, 0.0);
	float d_x = sd_rounded_box(pos_centered + eps.xy, half_size, corner_radius) - dist;
	float d_y = sd_rounded_box(pos_centered + eps.yx, half_size, corner_radius) - dist;
	vec2 grad = normalize(vec2(d_x, d_y) + vec2(0.00001));

	// 4. Оптический профиль жидкого выпуклого скоса (Liquid Lens Profile)
	// depth — расстояние внутрь формы от внешнего края
	float depth = max(-dist, 0.0);
	float effective_bevel = min(bevel_width, min(half_size.x, half_size.y));
	float t = clamp(depth / max(effective_bevel, 1.0), 0.0, 1.0);
	
	// Куполообразный профиль линзы (четверть волны синуса)
	// t = 0.0 (край): максимальный наклон; t = 1.0 (центр): плоская поверхность
	float lens_slope = cos(t * 1.5707963);
	
	// 3D нормаль поверхности жидкого стекла
	vec3 normal = normalize(vec3(grad * lens_slope * 2.2, mix(0.4, 1.0, t)));

	// 5. Оптическое преломление (Optical Refraction) со спектральным разделением (Chromatic Aberration)
	vec2 refract_offset = normal.xy * refraction_strength * lens_slope;
	
	// Дисперсия: красный смещается сильнее, синий — слабее
	vec2 r_offset = refract_offset * (1.0 + chromatic_dispersion * 15.0);
	vec2 g_offset = refract_offset;
	vec2 b_offset = refract_offset * (1.0 - chromatic_dispersion * 15.0);

	// Центр панели: матовый блюр; на оптическом скосе (линзе): более четкое преломление
	float sample_lod = mix(blur_amount * 0.35, blur_amount, smoothstep(0.0, 0.8, t));
	
	float bg_r = textureLod(screen_texture, SCREEN_UV + r_offset, sample_lod).r;
	float bg_g = textureLod(screen_texture, SCREEN_UV + g_offset, sample_lod).g;
	float bg_b = textureLod(screen_texture, SCREEN_UV + b_offset, sample_lod).b;
	vec3 refracted_backdrop = vec3(bg_r, bg_g, bg_b);

	// 6. Микрозернистый дизеринг против 8-битного бандинга градиентов
	float grain = (hash(SCREEN_UV * 1200.0 + fract(TIME * 0.02)) - 0.5) * noise_intensity;
	refracted_backdrop += vec3(grain);

	// 7. Смешивание тинта стекла с преломленным фоном
	vec3 glass_color = mix(refracted_backdrop, glass_tint.rgb, glass_tint.a);

	// 8. Физический расчет освещения (Lighting & Specular Reflections)
	// Источник света сверху-слева спереди
	vec3 light_dir = normalize(vec3(-0.35, -0.65, 0.67));
	vec3 view_dir = vec3(0.0, 0.0, 1.0);
	vec3 half_vector = normalize(light_dir + view_dir);
	
	// Зеркальный блик на линзе (Specular highlight)
	float spec_term = pow(max(dot(normal, half_vector), 0.0), 28.0);
	float specular = spec_term * specular_intensity;

	// Эффект Френеля на скошенных краях (Fresnel rim)
	float fresnel = pow(1.0 - max(normal.z, 0.0), fresnel_power);
	
	// 9. Волосковый 1px контур (Hairline) и верхний анизотропный отблеск
	float rim_mask = smoothstep(0.0, -rim_thickness, dist);
	float hairline_edge = 1.0 - rim_mask;
	float top_sheen = smoothstep(0.75, 0.05, UV.y) * sheen_intensity;

	// Композитинг итогового цвета
	glass_color += vec3(top_sheen + specular);
	glass_color = mix(glass_color, rim_color.rgb * rim_boost, max(hairline_edge, fresnel * 0.75) * rim_color.a);

	COLOR = vec4(glass_color, shape_mask);
}
