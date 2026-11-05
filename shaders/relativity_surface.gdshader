shader_type spatial;
render_mode cull_back, unshaded;

## UniCORE Relativistic Surface Shader
## Implements vertex-level Lorentz Contraction along the velocity vector,
## relativistic Doppler frequency/color shifting, and Relativistic Beaming (Searchlight effect).
## Based on MIT OpenRelativity & MinkowskiKart formulations.

uniform sampler2D main_texture : source_color;
uniform vec3 player_velocity = vec3(0.0, 0.0, 0.0); // Velocity vector in simulation units
uniform float speed_of_light = 1.0;                  // Configurable c_sim
uniform bool enable_lorentz_contraction = true;
uniform bool enable_doppler = true;
uniform float beaming_intensity = 3.0;               // I = I0 * D^3 for standard relativistic flux

varying float v_doppler_factor;
varying vec3 v_world_dir;

void vertex() {
	vec3 beta = player_velocity / max(speed_of_light, 0.0001);
	float beta_sq = dot(beta, beta);
	
	if (beta_sq > 0.0001 && beta_sq < 1.0) {
		float beta_mag = sqrt(beta_sq);
		vec3 beta_dir = beta / beta_mag;
		float gamma = 1.0 / sqrt(1.0 - beta_sq);
		
		// World vertex coordinates relative to camera
		vec4 world_v = MODEL_MATRIX * vec4(VERTEX, 1.0);
		vec3 r = world_v.xyz - CAMERA_POSITION_WORLD;
		
		if (enable_lorentz_contraction) {
			// Contract along beta direction: r' = r_parallel / gamma + r_perp
			float proj = dot(r, beta_dir);
			vec3 r_parallel = proj * beta_dir;
			vec3 r_perp = r - r_parallel;
			
			// Apparent contracted position in laboratory frame
			vec3 contracted_r = (r_parallel / gamma) + r_perp;
			world_v.xyz = CAMERA_POSITION_WORLD + contracted_r;
			VERTEX = (inverse(MODEL_MATRIX) * world_v).xyz;
		}
		
		// Direction from camera to vertex
		vec3 n = normalize(world_v.xyz - CAMERA_POSITION_WORLD);
		v_world_dir = n;
		
		// Relativistic Doppler Factor D = 1 / (gamma * (1 - beta . n))
		float cos_theta = dot(beta, n);
		v_doppler_factor = 1.0 / (gamma * (1.0 - cos_theta));
	} else {
		v_doppler_factor = 1.0;
		v_world_dir = vec3(0.0, 0.0, -1.0);
	}
}

// Spectral RGB wavelength shift approximation
vec3 apply_doppler_to_rgb(vec3 base_rgb, float D) {
	if (abs(D - 1.0) < 0.001) return base_rgb;
	
	// Blueshift: D > 1 (shifts red->green, green->blue, blue->ultraviolet/violet)
	// Redshift: D < 1 (shifts blue->green, green->red, red->infrared)
	vec3 shifted = vec3(0.0);
	if (D > 1.0) {
		float t = clamp(D - 1.0, 0.0, 2.0);
		shifted.r = mix(base_rgb.r, base_rgb.g * 0.3, clamp(t, 0.0, 1.0));
		shifted.g = mix(base_rgb.g, base_rgb.r * 0.7 + base_rgb.b * 0.3, clamp(t, 0.0, 1.0));
		shifted.b = mix(base_rgb.b, base_rgb.g * 0.8 + base_rgb.b * 1.5, clamp(t, 0.0, 1.0));
	} else {
		float t = clamp(1.0 - D, 0.0, 1.0);
		shifted.r = mix(base_rgb.r, base_rgb.r * 1.5 + base_rgb.g * 0.5, t);
		shifted.g = mix(base_rgb.g, base_rgb.b * 0.4 + base_rgb.g * 0.3, t);
		shifted.b = mix(base_rgb.b, 0.0, t);
	}
	return shifted;
}

void fragment() {
	vec4 base_color = texture(main_texture, UV);
	vec3 col = base_color.rgb;
	
	if (enable_doppler) {
		col = apply_doppler_to_rgb(col, v_doppler_factor);
		// Relativistic Searchlight Beaming Effect: I = I0 * D^3
		float beaming = pow(max(v_doppler_factor, 0.0), beaming_intensity);
		col *= beaming;
	}
	
	ALBEDO = col;
}
