shader_type canvas_item;
render_mode unshaded, blend_add;
uniform float phase = 0.0;
uniform float arrival = 0.0;
varying vec4 inherited_tint;
void vertex(){ inherited_tint = COLOR; }
void fragment(){
 float h=(.90-UV.y)/.83;
 float vertical=smoothstep(0.0,.06,h)*(1.0-smoothstep(.66,1.0,h));
 float curtain=0.0;
 for(int i=0;i<5;i++){
  float fi=float(i);
  float center=.15+fi*.175+sin(h*4.2-phase*.42+fi*1.7)*.035;
  float d=abs(UV.x-center);
  float soft=exp(-d*d/0.00085);
  float core=exp(-d*d/0.000075);
  float reach=1.0-smoothstep(.68+.05*sin(fi),.96+.03*sin(fi),h);
  curtain+=(soft*.13+core*.22)*reach*(.8+.2*sin(phase*.8+fi));
 }
 float ribbon_x=.5+.38*sin(h*5.6-phase*.36);
 float ribbon_d=abs(UV.x-ribbon_x);
 float ribbon=exp(-ribbon_d*ribbon_d/.000055)*.30;
 vec2 q=(UV-vec2(.5,.90))/vec2(.405,.073);
 float ring_d=abs(length(q)-1.0);
 float ring=exp(-ring_d*ring_d/.018)*.36;
 float haze=exp(-ring_d*ring_d/.15)*.07;
 float light=(curtain+ribbon)*vertical+ring+haze;
 light*=1.0+arrival*.45;
 vec3 gold=mix(vec3(1.0,.56,.09),vec3(1.0,.91,.54),clamp(h,0.0,1.0));
 COLOR=vec4(gold,clamp(light,0.0,.78))*inherited_tint;
}
