shader_type spatial;
render_mode cull_disabled;
varying vec3 local;
float hash(vec2 p){vec3 p3=fract(vec3(p.xyx)*0.1031);p3+=dot(p3,p3.yzx+33.33);return fract((p3.x+p3.y)*p3.z);}
void vertex(){local=VERTEX;}
void fragment(){
 vec2 p=vec2(local.x,local.z*1.18);
 float row=floor(p.y/0.29);
 p.x+=mod(row,2.0)*0.23;
 vec2 id=floor(p/vec2(0.46,0.29));
 vec2 f=fract(p/vec2(0.46,0.29));
 float seam=1.0-smoothstep(0.015,0.055,min(f.x,1.0-f.x));
 float lip=1.0-smoothstep(0.025,0.09,f.y);
 vec3 slate=mix(vec3(0.035,0.05,0.065),vec3(0.075,0.095,0.11),hash(id));
 ALBEDO=slate*(1.0-seam*0.45-lip*0.27);
 ROUGHNESS=0.86;
 SPECULAR=0.22;
 AO=1.0-max(seam,lip)*0.15;
}
