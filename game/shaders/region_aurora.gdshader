shader_type canvas_item;
// Alpha-composited amber stays golden over the bright green map.
render_mode unshaded, blend_mix;
uniform float phase = 0.0;
uniform float arrival = 0.0;
varying vec4 inherited_tint;
void vertex(){ inherited_tint = COLOR; }
void fragment(){
 float h=(.90-UV.y)/.83;
 float vertical=smoothstep(-.015,.035,h)*(1.0-smoothstep(.72,1.02,h));
 float body=exp(-pow(abs(UV.x-.5)/.285,4.0))*.26*vertical;
 float glow=0.0;
 float core=0.0;
 for(int i=0;i<5;i++){
  float fi=float(i);
  float center=.23+fi*.135+sin(h*3.0-phase*.32+fi*1.9)*.014;
  float d=abs(UV.x-center);
  float reach=1.0-smoothstep(.53+.07*sin(fi*2.1),.94+.07*sin(fi*2.1),h);
  float strength=.80+.20*sin(phase*.75+fi*1.6);
  glow+=exp(-d*d/.0022)*.52*reach*strength;
  core+=exp(-d*d/.00010)*.95*reach*strength;
 }
 float ribbon_x=.5+.285*sin(h*6.8-phase*.42);
 float ribbon_d=abs(UV.x-ribbon_x);
 glow+=exp(-ribbon_d*ribbon_d/.0020)*.44;
 core+=exp(-ribbon_d*ribbon_d/.00007)*.95;
 glow*=vertical;core*=vertical;
 vec2 q=(UV-vec2(.5,.90))/vec2(.315,.054);
 float ring_d=abs(length(q)-1.0);
 float ring=exp(-ring_d*ring_d/.008);
 float halo=exp(-ring_d*ring_d/.22)*.60+exp(-ring_d*ring_d/.65)*.22;
 float sparks=0.0;
 for(int i=0;i<9;i++){
  float fi=float(i);
  float progress=fract(phase*(.13+.012*sin(fi))+fi*.173);
  vec2 p=vec2(.19+fract(fi*.381)*.62,.88-progress*.72);
  p.x+=sin(progress*5.0+fi)*.025;
  vec2 d=(UV-p)*vec2(180.0,220.0);
  sparks+=exp(-dot(d,d)/2.2)*sin(progress*3.14159265)*.95;
  glow+=exp(-dot(d,d)/28.0)*sin(progress*3.14159265)*.13;
 }
 float bright=clamp(core+ring+sparks,0.0,1.0);
 float opacity=clamp(body+glow+halo+bright,0.0,.98)*(1.0+arrival*.12);
 vec3 color=mix(vec3(1.0,.64,.075),vec3(1.0,.98,.72),bright);
 opacity*=smoothstep(0.0,.025,SCREEN_UV.y);
 COLOR=vec4(color,clamp(opacity,0.0,.98))*inherited_tint;
}
