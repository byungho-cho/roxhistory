shader_type canvas_item;
void fragment(){
	vec4 source=texture(TEXTURE,UV);
	vec2 edge=min(UV,1.0-UV);
	source.a*=smoothstep(0.0,.045,min(edge.x,edge.y));
	COLOR=source;
}
