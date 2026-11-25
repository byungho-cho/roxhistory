shader_type canvas_item;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec2 pixel = TEXTURE_PIXEL_SIZE;
	vec2 top = vec2(mix(0.5 * pixel.x, 1.0 - 0.5 * pixel.x, UV.x),
		mix(0.5 * pixel.y, 0.5 - 0.5 * pixel.y, UV.y));
	vec3 rgb = texture(TEXTURE, top).rgb;
	float mask = texture(TEXTURE, top + vec2(0.0, 0.5)).r;
	COLOR = tint * vec4(rgb, mask);
}
