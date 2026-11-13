shader_type canvas_item;

void fragment() {
	vec4 tint = COLOR;
	vec4 pixel = texture(TEXTURE, UV);
	vec2 frame = fract(UV * vec2(4.0, 34.0));
	float row = floor(UV.y * 34.0);
	float luminance = dot(pixel.rgb, vec3(0.299, 0.587, 0.114));
	float warm = step(0.035, pixel.r - pixel.b);
	float hair = warm * (1.0 - smoothstep(0.34, 0.52, luminance)) * (1.0 - smoothstep(0.24, 0.36, frame.y));
	float cloth = warm * smoothstep(0.30, 0.42, frame.y) * (1.0 - smoothstep(0.62, 0.73, frame.y));
	cloth *= smoothstep(0.07, 0.14, pixel.r - pixel.g) * (1.0 - smoothstep(0.41, 0.55, luminance));
	// Keep the center of the cargo rows dedicated to the baked prop artwork.
	if (row >= 16.0 && frame.y > 0.37 && frame.y < 0.61) {
		cloth *= smoothstep(0.16, 0.28, abs(frame.x - 0.5));
	}
	vec3 orange = vec3(1.0, 0.30, 0.13) * (0.64 + luminance);
	vec3 teal = vec3(0.09, 0.62, 0.60) * (0.49 + luminance);
	pixel.rgb = mix(pixel.rgb, mix(orange, teal, 1.0 - smoothstep(0.43, 0.48, frame.x)), cloth);
	float skin = warm * smoothstep(0.22, 0.46, luminance) * (1.0 - cloth) * (1.0 - hair);
	pixel.rgb = mix(pixel.rgb, min(pixel.rgb * vec3(1.60, 1.36, 1.21), vec3(1.0)), skin);
	pixel.rgb = mix(pixel.rgb, vec3(luminance * 0.58), hair);
	COLOR = pixel * tint;
}
