shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D color_map : filter_linear, repeat_disable;
uniform float lower = 0.0;
uniform float upper = 1.0;
uniform int bands = 0;
void fragment(){
 float t=upper>lower ? clamp((UV.x-lower)/(upper-lower),0.0,1.0) : 0.5;
 if(bands>1){t=round(t*float(bands-1))/float(bands-1);}
 ALBEDO=texture(color_map,vec2(t,0.5)).rgb;
 if(UV.y>0.0){ALBEDO=vec3(1.0,0.0,1.0);}
}
