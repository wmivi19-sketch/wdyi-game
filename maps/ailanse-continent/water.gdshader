shader_type spatial;
varying vec3 p;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;}
void fragment(){
 float ripples=sin(p.x*3.5+p.z*1.2+TIME*1.0)*sin(p.z*4.0-TIME*1.4);
 float bands=sin(p.x*0.4+p.z*0.22-TIME*0.6);
 float shore=1.0-smoothstep(420.0,434.0,p.x);
 float foam=shore*pow(max(0.0,sin(p.x*2.6+sin(p.z*0.9)+TIME*0.5)),12.0);
 ALBEDO=mix(vec3(0.08,0.19,0.22),vec3(0.23,0.34,0.33),shore*0.65+bands*0.08);
 ALBEDO=mix(ALBEDO,vec3(0.59,0.61,0.49),foam*0.55);
 ROUGHNESS=0.24+shore*0.18;
 SPECULAR=0.65;
 NORMAL_MAP=normalize(vec3(ripples*0.05,sin(p.z*2.0+TIME)*0.04,1.0))*0.5+0.5;
 NORMAL_MAP_DEPTH=0.6;
}
