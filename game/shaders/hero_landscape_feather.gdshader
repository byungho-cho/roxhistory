shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec2 uv = UV;
	vec4 source = texture(TEXTURE, uv);
	float drift = sin(uv.x * 20.0 + 0.2) * 0.010 + sin(uv.x * 43.0) * 0.005;
	float cloud = 1.0 - smoothstep(0.0, 0.078 + drift, uv.y);
	float mist = smoothstep(0.82 + drift, 1.0, uv.y);
	float flank = 1.0 - smoothstep(0.0, 0.15, min(uv.x, 1.0 - uv.x));
	float blend = max(max(cloud, mist), flank);
	vec3 haze = mix(vec3(0.72, 0.75, 0.67), vec3(0.65, 0.66, 0.54), smoothstep(0.1, 0.9, uv.y));
	COLOR = vec4(mix(source.rgb, haze, blend * 0.19), source.a * (1.0 - blend));
}