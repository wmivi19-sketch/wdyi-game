shader_type spatial;
varying vec3 p;
float h(vec2 v){return fract(sin(dot(v,vec2(127.1,311.7)))*43758.5453);}
float n(vec2 v){vec2 i=floor(v),f=fract(v);f=f*f*(3.0-2.0*f);return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+vec2(1,1)),f.x),f.y);}
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;}
void fragment(){
 float large=0.5+0.2*sin(p.x*0.027+sin(p.z*0.041))+0.15*sin(p.z*0.037+p.x*0.014),small=n(p.xz*1.8),grain=h(floor(p.xz*30.0));
 vec3 grass=mix(vec3(0.115,0.155,0.075),vec3(0.235,0.26,0.13),large);
 float soil=smoothstep(0.7,0.95,0.5+0.3*sin(p.x*0.13+sin(p.z*0.12)));
 ALBEDO=mix(grass,vec3(0.23,0.215,0.14),soil*0.45)*(0.88+small*0.16+grain*0.08);
 ROUGHNESS=0.96;
}
