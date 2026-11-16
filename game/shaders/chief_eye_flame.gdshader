shader_type canvas_item;
render_mode unshaded;

uniform float clock;
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	// The flame occupies the third quarter of the atlas, with its root at the bottom.
	float height = 1.0 - UV.y;
	float sway = sin(clock * 13.0 - height * 6.0) * 0.023;
	sway += sin(clock * 7.0 - height * 3.0) * 0.014;
	vec2 sample_uv = UV - vec2(sway * height * height, 0.0);
	float inside = step(0.501, sample_uv.x) * (1.0 - step(0.749, sample_uv.x));
	sample_uv.x = clamp(sample_uv.x, 0.501, 0.749);
	COLOR = texture(TEXTURE, sample_uv) * tint;
	COLOR.a *= inside;
}
