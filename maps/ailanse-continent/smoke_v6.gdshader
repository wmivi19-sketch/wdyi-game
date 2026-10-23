shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform float opacity=0.15;
uniform float phase=0.0;
void fragment(){
 vec2 p=UV*2.0-1.0;
 float r=length(p);
 float edges=0.075*sin(p.x*12.0+phase+TIME*0.3)*sin(p.y*9.0-phase);
 float shape=1.0-smoothstep(0.35,0.97,r+edges);
 float wisps=0.85+0.15*sin(p.x*4.0+p.y*5.0+TIME*0.3+phase);
 ALBEDO=vec3(0.18,0.175,0.16);
 ALPHA=shape*wisps*opacity;
}
