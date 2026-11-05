shader_type canvas_item;
void fragment(){
	vec2 world=vec2(1200.0,675.0)+(UV-vec2(.5))*1350.0/.7;
	vec2 uv=world/vec2(2400.0,1350.0);
	uv=vec2(1.0)-abs(mod(uv,vec2(2.0))-vec2(1.0));
	COLOR=texture(TEXTURE,uv);
}
