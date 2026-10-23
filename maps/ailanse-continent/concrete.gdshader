shader_type spatial;
uniform vec4 base_color : source_color = vec4(0.28,0.30,0.30,1);
uniform bool paving = false;
varying vec3 world;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;}
void fragment(){
 vec2 p=world.xz;
 p=floor(p*64.0)/64.0;
 float n=noise(p*0.38)*0.65+noise(p*1.7)*0.35;
 float wet=smoothstep(0.40,0.68,n);
 float grain=hash(floor(p*65.0));
 vec3 tint=paving?vec3(0.49,0.40,0.28):vec3(0.22,0.265,0.285);
 vec3 c=tint*(0.92+0.14*grain)*(1.0-wet*0.14);
 vec2 cell=paving?vec2(0.85,0.55):vec2(7.0,4.0);
 vec2 q=p;
 if(paving){q.x+=mod(floor(p.y/cell.y),2.0)*cell.x*0.5;}
 vec2 f=fract(q/cell);vec2 edge=min(f,1.0-f)*cell;
 c*=0.93+0.14*hash(floor(q/cell));
 float joint=1.0-smoothstep(0.008,0.025,min(edge.x,edge.y));
 ALBEDO=c*(1.0-joint*(paving?0.48:0.16));
 ROUGHNESS=paving?mix(0.76,0.33,wet):mix(0.56,0.17,wet);
 SPECULAR=0.62;
}
