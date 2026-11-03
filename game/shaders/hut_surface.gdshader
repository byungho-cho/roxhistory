shader_type canvas_item;
varying vec4 tint;
void vertex() { tint=COLOR; }
// Preserve alpha and detail; gently match the softer painted terrain palette.
void fragment() {
	vec4 c=texture(TEXTURE,UV)*tint;
	float l=dot(c.rgb,vec3(0.299,0.587,0.114));
	c.rgb=mix(vec3(l),c.rgb,0.90);
	c.rgb=(c.rgb-vec3(0.5))*0.96+vec3(0.49);
	COLOR=c;
}
