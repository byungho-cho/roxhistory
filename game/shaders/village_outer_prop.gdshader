shader_type canvas_item;
render_mode unshaded;

uniform vec2 height_span;
uniform vec4 open_boundary;
uniform float crown_opacity = 0.99;
varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float height = clamp((UV.y - height_span.x) / (height_span.y - height_span.x), 0.0, 1.0);
	float wisp = sin(world_position.x * 0.018 + world_position.y * 0.004 + TIME * 0.32) * 0.045;
	float veil = smoothstep(0.39, 0.92, height + wisp);
	COLOR.rgb = mix(COLOR.rgb, vec3(0.75, 0.79, 0.72), veil * 0.46);
	COLOR.a *= (1.0 - veil) * crown_opacity;
	vec2 outside = max(open_boundary.xy - world_position, world_position - open_boundary.zw);
	COLOR.a *= smoothstep(0.0, 65.0, max(outside.x, outside.y));
}
