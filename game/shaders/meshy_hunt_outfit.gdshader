shader_type spatial;
varying vec3 rest_point;

void vertex() {
	rest_point = VERTEX;
}

void fragment() {
	float accent = smoothstep(.98, 1.15, rest_point.y + rest_point.x * .55);
	float hem = 1.0 - smoothstep(0.54, 0.62, rest_point.y);
	ALBEDO = mix(vec3(.65, .092, .033), vec3(.019, .30, .27), max(accent, hem));
	ROUGHNESS = .83;
	SPECULAR = .18;
}
