shader_type canvas_item;
// Preserve the composed Figma button; clip only its rectangular export backing.
void fragment() {
	vec4 ink=texture(TEXTURE,UV)*COLOR;
	ink.a*=1.0-smoothstep(0.485,0.5,length(UV-vec2(0.5)));
	COLOR=ink;
}
