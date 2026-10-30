shader_type canvas_item;
uniform float phase = 0.0;
uniform float strength = 3.0;
uniform float speed = 1.0;
uniform bool animated = true;
void vertex() {
	float tip = pow(clamp(1.0 - UV.y, 0.0, 1.0), 2.4);
	float wind = sin(TIME * speed + phase) + 0.28 * sin(TIME * speed * 1.73 + phase * 2.1);
	VERTEX.x += (animated ? 1.0 : 0.0) * wind * strength * tip;
}
void fragment() {
	COLOR = texture(TEXTURE, UV);
}
