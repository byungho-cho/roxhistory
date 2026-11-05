shader_type canvas_item;
void fragment(){
	vec2 p=vec2(-4800.0,-5325.0)+UV*12000.0;
	vec2 uv=1.0-abs(mod(p/900.0,2.0)-1.0);
	COLOR=texture(TEXTURE,uv);
}
