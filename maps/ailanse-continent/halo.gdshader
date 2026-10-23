shader_type spatial;
render_mode unshaded,blend_add,depth_draw_never,cull_disabled;
uniform vec4 tint : source_color = vec4(1.0,0.52,0.13,1);
uniform float strength = 0.25;
void fragment(){float r=length((UV-0.5)*2.0);float a=pow(max(0.0,1.0-r),3.0);ALBEDO=tint.rgb;ALPHA=a*strength;}
