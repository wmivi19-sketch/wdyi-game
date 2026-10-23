shader_type spatial;
varying vec3 p;
void vertex(){p=VERTEX;}
void fragment(){
 float plank=floor((p.x+2.0)/0.4);
 float seam=1.0-smoothstep(0.008,0.025,abs(fract((p.x+2.0)/0.4)-0.5)*0.4);
 float grain=sin(p.y*17.0+sin(p.y*2.4+plank)*2.0+p.x*180.0);
 float variation=0.8+0.17*sin(plank*5.7);
 ALBEDO=vec3(0.24,0.125,0.049)*variation*(0.93+grain*0.07)*(1.0-seam*0.5);
 ROUGHNESS=0.88;
}
