shader_type spatial;
render_mode diffuse_burley, cull_disabled;
uniform vec4 base_color : source_color = vec4(0.38,0.19,0.12,1.0);
uniform bool slate = false;
varying vec3 world;
varying vec3 wn;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; wn=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 vec2 p=abs(wn.z)>abs(wn.x)?world.xy:world.zy;
 if(slate){p=vec2(world.x,world.z+world.y*0.4);}
 vec2 cell=slate?vec2(0.48,0.32):vec2(0.42,0.19);
 float row=floor(p.y/cell.y);
 p.x+=mod(row,2.0)*cell.x*0.5;
 vec2 f=fract(p/cell);
 vec2 edge=min(f,1.0-f)*cell;
 float mortar=1.0-smoothstep(0.006,0.017,min(edge.x,edge.y));
 float grain=hash(floor(world.xz*70.0)+floor(world.y*60.0));
 float variation=0.78+0.32*hash(floor(p/cell));
 vec3 face=base_color.rgb*variation*(0.94+grain*0.12);
 ALBEDO=mix(face,base_color.rgb*0.53,mortar*0.75);
 ROUGHNESS=slate?0.65:0.9;
 AO=1.0-mortar*0.18;
}
