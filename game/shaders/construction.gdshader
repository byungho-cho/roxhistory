shader_type canvas_item;
uniform float progress : hint_range(0.0,1.0) = 0.0;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float edge = 1.0-progress;
	float reveal = smoothstep(edge-0.025,edge+0.025,UV.y);
	tex.rgb = mix(tex.rgb*vec3(1.12,1.02,0.83),tex.rgb,progress);
	COLOR = vec4(tex.rgb,tex.a*reveal*step(0.001,progress));
}
