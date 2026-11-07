shader_type canvas_item;
// Move only the painted flame; rocks, fuel and the footprint stay fixed.
uniform float strength = 1.0;
void fragment() {
	vec4 original = texture(TEXTURE, UV);
	float region = smoothstep(0.31,0.39,UV.x)*(1.0-smoothstep(0.61,0.68,UV.x));
	region *= 1.0-smoothstep(0.48,0.57,UV.y);
	float fire_color = smoothstep(0.16,0.32,original.r-original.b)*smoothstep(0.25,0.55,original.r);
	float weight = region*fire_color;
	vec2 uv=UV;
	uv.x += sin(TIME*4.7-UV.y*19.0)*0.008*strength*weight;
	uv.y += sin(TIME*6.1+UV.x*21.0)*0.004*strength*weight;
	vec4 shifted=texture(TEXTURE,uv);
	COLOR=mix(original,shifted,weight);
	COLOR.rgb *= 1.0+weight*sin(TIME*8.0+UV.y*23.0)*0.035;
}
