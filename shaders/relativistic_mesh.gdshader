shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// ==============================================================================
// Uniforms & Configuration
// ==============================================================================
uniform sampler2D main_texture : source_color, filter_linear_mipmap;
uniform vec4 albedo_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy : hint_range(0.0, 16.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.4;
uniform float metallic : hint_range(0.0, 1.0) = 0.1;

uniform float speed_of_light : hint_range(0.1, 1000.0) = 50.0;
uniform bool enable_lorentz_contraction = true;
uniform bool enable_doppler = true;
uniform float beaming_power : hint_range(0.0, 6.0) = 3.0;

// Uniform velocity fallback for standalone MeshInstance3D
uniform vec3 object_velocity = vec3(0.0);
uniform bool use_instance_custom_velocity = true;

// Varyings passed to fragment stage
varying float v_doppler_factor;
varying vec4 v_instance_color;

// ==============================================================================
// Color Space Transformation Helpers
// ==============================================================================
vec3 rgb_to_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// ==============================================================================
// Vertex Stage: Lorentz Contraction & Line-of-Sight Doppler
// ==============================================================================
void vertex() {
	v_instance_color = COLOR;
	
	// 1. Resolve Velocity Vector (MultiMesh INSTANCE_CUSTOM or Uniform)
	vec3 vel = object_velocity;
	if (use_instance_custom_velocity && length(INSTANCE_CUSTOM.xyz) > 0.0) {
		vel = INSTANCE_CUSTOM.xyz;
	}
	
	float c_sim = max(speed_of_light, 0.1);
	float v_len = length(vel);
	vec3 beta = vel / c_sim;
	float beta_sq = dot(beta, beta);
	
	if (beta_sq > 0.0001) {
		beta_sq = min(beta_sq, 0.999);
		float gamma = 1.0 / sqrt(1.0 - beta_sq);
		vec3 u_hat = vel / v_len; // Velocity unit vector
		
		// 2. Vertex-Level Lorentz Contraction
		// Delta r' = (1/gamma)*(Delta r . u_hat)*u_hat + (Delta r - (Delta r . u_hat)*u_hat)
		vec4 center_world = MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0);
		vec4 vertex_world = MODEL_MATRIX * vec4(VERTEX, 1.0);
		vec3 delta_r = vertex_world.xyz - center_world.xyz;
		
		if (enable_lorentz_contraction) {
			float proj = dot(delta_r, u_hat);
			vec3 r_parallel = proj * u_hat;
			vec3 r_perp = delta_r - r_parallel;
			vec3 contracted_delta_r = (r_parallel / gamma) + r_perp;
			
			vertex_world.xyz = center_world.xyz + contracted_delta_r;
			VERTEX = (inverse(MODEL_MATRIX) * vertex_world).xyz;
			
			// 3. Normal Vector Tensor Transformation
			// Flattening space tilts surface normals outward: n' = normalize(gamma*(n.u)*u + (n - (n.u)*u))
			mat3 model_rot_scale = mat3(MODEL_MATRIX);
			vec3 norm_world = normalize(model_rot_scale * NORMAL);
			float norm_proj = dot(norm_world, u_hat);
			vec3 norm_parallel = norm_proj * u_hat;
			vec3 norm_perp = norm_world - norm_parallel;
			vec3 contracted_norm = normalize(norm_parallel * gamma + norm_perp);
			NORMAL = normalize(inverse(model_rot_scale) * contracted_norm);
		}
		
		// 4. Line-of-Sight Relativistic Doppler Factor
		// k_hat points from vertex to observer camera
		vec3 k_hat = normalize(CAMERA_POSITION_WORLD - vertex_world.xyz);
		float beta_dot_k = dot(beta, k_hat);
		// D = 1 / (gamma * (1 - beta . k_hat))
		v_doppler_factor = 1.0 / (gamma * (1.0 - clamp(beta_dot_k, -0.999, 0.999)));
	} else {
		v_doppler_factor = 1.0;
	}
}

// ==============================================================================
// Fragment Stage: Chromatic Shift & Radiative Searchlight Beaming
// ==============================================================================
void fragment() {
	vec4 tex_col = texture(main_texture, UV);
	vec3 base_rgb = tex_col.rgb * v_instance_color.rgb * albedo_tint.rgb;
	
	if (enable_doppler && abs(v_doppler_factor - 1.0) > 0.005) {
		// Chromatic Frequency Shift via HSV
		vec3 hsv = rgb_to_hsv(base_rgb);
		if (v_doppler_factor > 1.0) {
			// Blueshift: D > 1 -> shifts toward cyan/blue/violet (+0.66)
			float shift = clamp((v_doppler_factor - 1.0) * 0.4, 0.0, 0.6);
			hsv.x = mod(hsv.x + shift, 1.0);
			hsv.y = clamp(hsv.y + (v_doppler_factor - 1.0) * 0.25, 0.0, 1.0);
		} else {
			// Redshift: D < 1 -> shifts toward red/IR (-0.66)
			float shift = clamp((1.0 - v_doppler_factor) * 0.5, 0.0, 0.6);
			hsv.x = mod(hsv.x - shift + 1.0, 1.0);
			hsv.z *= clamp(v_doppler_factor * 1.25, 0.05, 1.0);
		}
		base_rgb = hsv_to_rgb(hsv);
		
		// Radiative Beaming (Searchlight effect): I = I0 * D^power
		float beaming = pow(clamp(v_doppler_factor, 0.1, 4.0), beaming_power);
		base_rgb *= beaming;
	}
	
	ALBEDO = base_rgb;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	
	if (emission_energy > 0.0) {
		EMISSION = emission_color.rgb * emission_energy * base_rgb;
	}
}
