shader_type canvas_item;
uniform sampler2D mask_texture;
void fragment(){
 vec2 local_uv=(UV*vec2(1672.0,941.0)-vec2(612.0,281.0))/vec2(176.0,136.0);
 vec2 m=(local_uv*vec2(220.0,170.0)-vec2(27.475,18.18))/vec2(187.025,139.331);
 float inside=step(0.0,m.x)*step(0.0,m.y)*step(m.x,1.0)*step(m.y,1.0);
 COLOR.a*=texture(mask_texture,clamp(m,vec2(0.0),vec2(1.0))).a*inside;
}
