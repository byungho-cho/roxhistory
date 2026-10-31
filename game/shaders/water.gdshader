shader_type canvas_item;
uniform bool animated = true;
uniform vec2 map_size = vec2(2400.0, 1350.0);
varying vec2 world_point;
void vertex() { world_point = VERTEX; }
void fragment() {
	float t = animated ? TIME : 0.0;
	vec2 p = world_point;
	// Continuous sine fields: no scrolling texture seam or frame animation pop.
	float flow = sin(p.x * 0.027 + p.y * 0.054 - t * 1.4);
	float crossing = sin(p.x * 0.013 - p.y * 0.071 + t * 0.91);
	vec2 ripple = vec2(flow, crossing) * 0.00065;
	vec4 still = texture(TEXTURE, UV);
	float water_mask=smoothstep(0.0,0.08,still.b-still.r)*smoothstep(0.0,0.08,still.g-still.r);
	vec4 base = texture(TEXTURE, UV + ripple*water_mask);
	float glint = pow(max(0.0, flow * crossing), 9.0);
	COLOR = vec4(base.rgb + vec3(0.025,0.035,0.03) * glint*water_mask, 1.0);
}
