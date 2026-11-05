shader_type canvas_item;
void fragment(){
 vec2 local_uv=(UV*vec2(1774.0,887.0)-vec2(340.0,109.0))/vec2(1094.0,679.0);
 vec2 p=local_uv*2.0-1.0;
 float diamond=abs(p.x)+abs(p.y);
 float irregular=sin(UV.x*89.0)*sin(UV.y*73.0)*0.012;
 COLOR=texture(TEXTURE,UV);
 COLOR.a*=1.0-smoothstep(0.79+irregular,0.96+irregular,diamond);
}
