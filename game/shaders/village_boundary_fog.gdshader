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
	vec2 breeze = vec2(23.0, 10.0) * TIME;
	vec2 drift = world_position - breeze;
	float folds = noise(drift / vec2(640.0, 510.0));
	float wisps = noise((world_position - breeze * 1.65) / vec2(425.0, 175.0));
	float banks = noise((world_position - breeze * 0.45) / vec2(1180.0, 760.0));

	float radius = 205.0;
	vec2 box = abs(world_position - center) - (half_extent - vec2(radius));
	float rim = length(max(box, vec2(0.0))) + min(max(box.x, box.y), 0.0) - radius;
	float distance = rim + (folds - 0.5) * 150.0 + (wisps - 0.5) * 70.0;
	float near_mist = smoothstep(-185.0, 160.0, distance) * (0.22 + wisps * 0.12);
	float middle_mist = smoothstep(12.0, 350.0, distance) * 0.35;
	float far_mist = smoothstep(185.0, 590.0, distance);
	float opacity = mix(near_mist + middle_mist, 0.995, far_mist);
	// Hide the registered terrain seam even where its outer edge approaches the mist.
	vec2 art_clearance = min(world_position - terrain_bounds.xy, terrain_bounds.zw - world_position);
	opacity = mix(1.0, opacity, smoothstep(0.0, 110.0, min(art_clearance.x, art_clearance.y)));
	float tone = mix(mix(folds, banks, 0.72), wisps, 0.14);
	vec3 fog = mix(vec3(0.61, 0.68, 0.60), vec3(0.78, 0.81, 0.73), tone);
	COLOR = vec4(fog, opacity);
}
