shader_type canvas_item;
uniform vec2 dimensions = vec2(160.0,44.0);
void fragment() {
	vec4 color = texture(TEXTURE, UV);
	float radius = min(10.0, dimensions.x*0.5);
	vec2 q = abs(UV*dimensions-dimensions*0.5)-(dimensions*0.5-vec2(radius));
	float distance_to_edge = length(max(q,vec2(0.0)))+min(max(q.x,q.y),0.0)-radius;
	color.a *= 1.0-smoothstep(-1.0,0.5,distance_to_edge);
	COLOR = color;
}
