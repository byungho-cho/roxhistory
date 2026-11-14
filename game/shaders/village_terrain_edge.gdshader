shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec2 edge = min(UV, 1.0 - UV) * vec2(4800.0, 2700.0);
	float distance_to_edge = min(edge.x, edge.y);
	float feather = 245.0 + 32.0 * sin(UV.x * 55.0 + UV.y * 41.0)
		+ 20.0 * sin(UV.x * 112.0 - UV.y * 98.0);
	COLOR.a *= smoothstep(6.0, feather, distance_to_edge);
}
