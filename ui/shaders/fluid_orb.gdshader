shader_type canvas_item;

// UniCORE Design System — Fluid Singularity Agent Orb Shader
// Физико-математическая симуляция живого квантового ядра Агента:
// - Аналитическое пересечение луча со сферой (Ray-Sphere Projection)
// - Внутреннее гироидное плазменное течение (Gyroid Fluid Flow)
// - Реактивное акустическое возмущение (Acoustic audio wave resonance)
// - Горячая внутренняя сингулярность (Singularity Core Luminescence)
// - Хроматический дисперсионный ореол Френеля (Prismatic Rim Dispersion)
// - Квантовая корона и микро-турбулентность

// Цветовые константы (управляются через DesignTokens)
uniform vec4 primary_color : source_color = vec4(0.0, 0.9, 1.0, 1.0);     // Prism Cyan #00E5FF
uniform vec4 secondary_color : source_color = vec4(0.12, 0.58, 1.0, 1.0);  // Electric Blue #1F94FF
uniform vec4 core_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);        // Incandescent White #FFFFFF
uniform vec4 alert_color : source_color = vec4(1.0, 0.22, 0.28, 1.0);     // Crimson Valve #FF3847

// Динамические параметры состояния Агента
uniform float fluid_speed : hint_range(0.1, 8.0) = 1.2;
uniform float turbulence_intensity : hint_range(0.0, 2.0) = 0.45;
uniform float audio_level : hint_range(0.0, 1.0) = 0.0;                   // Реакция на голос/речь
uniform float thought_intensity : hint_range(0.0, 2.0) = 0.0;             // Интенсивность размышлений / синтеза
uniform float alert_blend : hint_range(0.0, 1.0) = 0.0;                   // Степень стресса / ошибки
uniform float sphere_radius : hint_range(0.2, 0.5) = 0.38;
uniform float fresnel_power : hint_range(0.5, 6.0) = 2.4;
uniform float corona_intensity : hint_range(0.0, 2.0) = 0.85;

// Матрица 3D-вращения вокруг оси Y
mat3 rotate_y(float angle) {
	float s = sin(angle);
	float c = cos(angle);
	return mat3(
		vec3(c, 0.0, -s),
		vec3(0.0, 1.0, 0.0),
		vec3(s, 0.0, c)
	);
}

// Матрица 3D-вращения вокруг оси X
mat3 rotate_x(float angle) {
	float s = sin(angle);
	float c = cos(angle);
	return mat3(
		vec3(1.0, 0.0, 0.0),
		vec3(0.0, c, s),
		vec3(0.0, -s, c)
	);
}

// 3D Гироидная функция для симуляции квантовой плазмы
float gyroid(vec3 p, float scale) {
	vec3 q = p * scale;
	return dot(sin(q), cos(q.yzx));
}

// Дробное броуновское движение (FBM) на базе гироидов
float fluid_fbm(vec3 p) {
	float f = 0.0;
	f += 0.5000 * gyroid(p, 4.0);
	f += 0.2500 * gyroid(p * 2.0 + vec3(1.4), 8.0);
	f += 0.1250 * gyroid(p * 4.0 + vec3(3.2), 16.0);
	return f;
}

void fragment() {
	// 1. Нормализация координат в диапазон [-1.0, 1.0] с центром в (0,0)
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float dist_sq = dot(p, p);
	float dist = sqrt(dist_sq);

	// Эффективный радиус сферы с учетом звуковой вибрации
	float dynamic_radius = sphere_radius + sin(dist * 24.0 - TIME * 4.0) * audio_level * 0.025;
	float r_sq = dynamic_radius * dynamic_radius;

	// Смешивание базового цвета с цветом тревоги
	vec3 cur_primary = mix(primary_color.rgb, alert_color.rgb, alert_blend);
	vec3 cur_secondary = mix(secondary_color.rgb, alert_color.rgb, alert_blend * 0.7);

	vec3 final_color = vec3(0.0);
	float final_alpha = 0.0;

	// Скорость времени с учетом интенсивности мыслительных процессов
	float effective_time = TIME * fluid_speed * (1.0 + thought_intensity * 1.5);

	// =========================================================================
	// ВНУТРЕННИЙ ОБЪЕМ СФЕРЫ (INSIDE SPHERE VOLUME)
	// =========================================================================
	if (dist_sq < r_sq) {
		// Аналитическое вычисление координаты Z и нормали сферы
		float z = sqrt(r_sq - dist_sq);
		vec3 normal = normalize(vec3(p.x, p.y, z));
		
		// 3D-вращение плазменного объема
		mat3 rot = rotate_y(effective_time * 0.5) * rotate_x(effective_time * 0.3);
		vec3 rotated_pos = rot * normal;

		// Вычисление квантовой турбулентности плазмы
		float turb = fluid_fbm(rotated_pos + vec3(0.0, effective_time * 0.2, 0.0));
		float audio_ripple = sin(normal.y * 30.0 + effective_time * 8.0) * audio_level * 0.4;
		turb += audio_ripple;

		// Свечение Френеля (Prismatic Rim)
		float view_dot = max(dot(normal, vec3(0.0, 0.0, 1.0)), 0.0);
		float fresnel = pow(1.0 - view_dot, fresnel_power);

		// Хроматическое расщепление на кромке сферы
		vec3 rim_dispersion;
		rim_dispersion.r = pow(1.0 - view_dot, fresnel_power * 0.85);
		rim_dispersion.g = fresnel;
		rim_dispersion.b = pow(1.0 - view_dot, fresnel_power * 1.15);

		// Горячая сингулярность в самом центре сферы (Singularity Core)
		float core_dist = dist / dynamic_radius;
		float core_glow = exp(-core_dist * (4.5 - thought_intensity * 1.5));
		float core_pulse = (sin(effective_time * 3.0) * 0.5 + 0.5) * 0.35 + 0.65;
		core_glow *= core_pulse * (1.0 + audio_level * 1.2);

		// Композитинг слоев объема
		vec3 plasma_layer = mix(cur_secondary, cur_primary, turb * 0.5 + 0.5);
		plasma_layer *= (1.0 + thought_intensity * 0.8);

		vec3 rim_layer = rim_dispersion * cur_primary * (1.5 + audio_level * 0.8);
		vec3 core_layer = core_color.rgb * core_glow;

		final_color = plasma_layer + rim_layer + core_layer;
		
		// Смягчение краев сферы
		float edge_aa = smoothstep(dynamic_radius, dynamic_radius - 0.015, dist);
		final_alpha = clamp(edge_aa * (0.85 + fresnel * 0.15), 0.0, 1.0);
	}

	// =========================================================================
	// ВНЕШНЯЯ КВАНТОВАЯ КОРОНА И ОРЕОЛ (CORONA & PHOTONIC BLEED)
	// =========================================================================
	float corona_dist = max(dist - dynamic_radius, 0.0);
	float corona = exp(-corona_dist * (12.0 - thought_intensity * 4.0));
	corona *= (corona_intensity + audio_level * 0.6);

	// Пульсация внешних световых лучей
	float angle = atan(p.y, p.x);
	float rays = sin(angle * 8.0 + effective_time * 2.0) * 0.5 + 0.5;
	corona += rays * exp(-corona_dist * 20.0) * (0.2 + thought_intensity * 0.4);

	vec3 corona_rgb = cur_primary * corona;
	final_color += corona_rgb;
	final_alpha = max(final_alpha, clamp(corona * 0.75, 0.0, 1.0));

	COLOR = vec4(final_color, final_alpha);
}
