shader_type canvas_item;
render_mode unshaded;

uniform float coverage : hint_range(0.0, 1.0) = 0.0;
uniform float aspect = 1.7778;

void fragment() {
	float vertical = UV.y - 0.5;
	float drift = sin(UV.y * 9.0 + TIME * 1.4) * 0.040;
	drift += sin(UV.y * 19.0 - TIME * 0.9) * 0.015;
	float distance_from_edge = min(UV.x + drift, 1.0 - UV.x - drift);
	float front = coverage * 0.76 - 0.13;
	float veil = 1.0 - smoothstep(front - 0.16, front + 0.16, distance_from_edge);
	float wisp = sin((UV.x * aspect * 2.5 + vertical * 3.0) * 3.0 - TIME * 1.6);
	float thin_mist = veil * (0.67 + 0.12 * wisp);
	float crossover = smoothstep(0.54, 1.0, coverage);
	float opacity = mix(thin_mist, 0.99, crossover) * smoothstep(0.0, 0.16, coverage);
	vec3 tint = mix(vec3(0.59,0.66,0.61),vec3(0.82,0.85,0.76),0.55 + 0.28*wisp);
	COLOR = vec4(tint, opacity);
}
