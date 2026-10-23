shader_type spatial;
render_mode cull_disabled;
uniform vec4 brick_color : source_color=vec4(0.53,0.29,0.19,1.0);
uniform bool stone=false;
varying vec3 p;
varying vec3 n;
float hash(vec2 v){vec3 q=fract(vec3(v.xyx)*0.1031);q+=dot(q,q.yzx+33.33);return fract((q.x+q.y)*q.z);}
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;n=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 vec2 face=abs(n.x)>abs(n.z)?p.zy:p.xy;
 vec2 cell=stone?vec2(0.62,0.31):vec2(0.38,0.18);
 // 64 discrete texels per metre keep chips and highlights pixel aligned.
 face=floor(face*64.0)/64.0;
 float row=floor(face.y/cell.y);
 face.x+=mod(row,2.0)*cell.x*0.5;
 vec2 id=floor(face/cell), uv=fract(face/cell);
 vec2 edge=min(uv,1.0-uv)*cell;
 float mortar=1.0-step(0.014,min(edge.x,edge.y));
 float tone=floor(hash(id)*5.0)/5.0;
 vec3 brick=brick_color.rgb*(0.75+tone*0.4);
 float grain=hash(floor(face*64.0));
 float chip=step(0.94,grain)*step(min(edge.x,edge.y),0.045);
 float top=step(uv.y,0.16)*(1.0-mortar);
 float bottom=step(0.8,uv.y)*(1.0-mortar);
 brick*=0.94+floor(grain*3.0)*0.035+top*0.11-bottom*0.12;
 brick=mix(brick,brick_color.rgb*0.55,chip*0.5);
 float soot=0.04+0.06*(0.5+0.5*sin(face.x*0.7))*smoothstep(3.0,12.0,p.y);
 ALBEDO=mix(brick,vec3(0.20,0.185,0.15),mortar*0.8)*(1.0-soot);
 ROUGHNESS=0.92;
 AO=1.0-mortar*0.18-bottom*0.05;
}
