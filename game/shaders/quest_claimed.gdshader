shader_type canvas_item;

void fragment() {
	float luminance = dot(COLOR.rgb, vec3(0.2126, 0.7152, 0.0722));
	COLOR.rgb = mix(COLOR.rgb, vec3(luminance), 0.55);
}
