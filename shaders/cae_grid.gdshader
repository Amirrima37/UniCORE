shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float opacity : hint_range(0.0,1.0) = 0.25;
uniform float fade_distance = 2.0;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){ALBEDO=COLOR.rgb;ALPHA=opacity*(1.0-smoothstep(fade_distance*0.3,fade_distance,length(world_position-CAMERA_POSITION_WORLD)));}
