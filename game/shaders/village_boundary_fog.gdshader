shader_type canvas_item;
render_mode unshaded;

uniform vec4 boundary;
uniform vec4 terrain_bounds;
varying vec2 world_position;

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 blend = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	vec4 seeds = vec4(0.0, 1.0, 57.0, 58.0) + dot(cell, vec2(1.0, 57.0));
	vec4 values = fract(sin(seeds) * 43758.5453);
	return mix(mix(values.x, values.y, blend.x), mix(values.z, values.w, blend.x), blend.y);
}

void vertex() {
	world_position = VERTEX;
}

void fragment() {
	vec2 center = (boundary.xy + boundary.zw) * 0.5;
	vec2 half_extent = (boundary.zw - boundary.xy) * 0.5;
	float corner_radius = 54.0;
	vec2 box = abs(world_position - center) - (half_extent - vec2(corner_radius));
	float edge_distance = length(max(box, vec2(0.0))) + min(max(box.x, box.y), 0.0) - corner_radius;
	float opacity = 0.995 * smoothstep(-40.0, 112.0, edge_distance);
	vec2 wind = vec2(8.0, 2.7) * TIME;
	float brush = noise((world_position - wind) / vec2(1050.0, 415.0));
	float slow_layer = noise((world_position - wind * 0.55) / vec2(1780.0, 910.0));
	float tone = mix(brush, slow_layer, 0.54);
	vec3 fog = mix(vec3(0.63, 0.69, 0.62), vec3(0.75, 0.79, 0.71), tone);
	bool outside_art = any(lessThan(world_position, terrain_bounds.xy)) || any(greaterThanEqual(world_position, terrain_bounds.zw));
	COLOR = vec4(fog, outside_art ? 1.0 : opacity);
}
