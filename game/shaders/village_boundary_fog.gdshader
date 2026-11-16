shader_type canvas_item;
render_mode unshaded;

uniform vec4 boundary;
uniform bool experiment_enabled = false;
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
	vec2 outside = max(max(boundary.xy - world_position, world_position - boundary.zw), vec2(0.0));
	float distance = length(outside);
	float bank = noise(world_position / 300.0 + vec2(sin(TIME * .035),cos(TIME * .028)) * .35);
	float detail = noise(world_position / 115.0);
	float drift = (bank - 0.5) * 155.0 + (detail - 0.5) * 65.0;
	float edge = smoothstep(0.0, experiment_enabled ? 120.0 : 80.0, distance);
	float density = smoothstep(experiment_enabled ? 30.0 : 15.0, experiment_enabled ? 620.0 : 460.0, distance + drift) * edge;
	vec3 cloud = mix(vec3(0.62, 0.73, 0.79), vec3(0.99, 0.96, 0.87), bank * 0.65 + detail * 0.35);
	float opaque_bank = smoothstep(experiment_enabled ? 620.0 : 430.0, experiment_enabled ? 1050.0 : 780.0, distance);
	COLOR = vec4(mix(cloud, vec3(0.97, 0.97, 0.94), opaque_bank), mix(density * (experiment_enabled ? 0.80 : 0.94), 1.0, opaque_bank));
}
