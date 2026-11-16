shader_type canvas_item;

uniform vec4 seam;
uniform float clock;
uniform float wind;

void fragment() {
	float seam_x = mix(seam.x, seam.z, clamp((UV.y - seam.y) / (seam.w - seam.y), 0.0, 1.0));
	float weight = pow(clamp((UV.x - seam_x) / 0.23, 0.0, 1.0), 1.36);
	float wave = sin(clock * 6.3 - weight * 5.0 + UV.y * 9.0);
	vec2 offset = vec2(cos(clock * 4.7 - weight * 3.0) * 0.008, wave * 0.017);
	COLOR = texture(TEXTURE, UV - offset * weight * wind);
}
