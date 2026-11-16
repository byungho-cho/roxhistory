shader_type canvas_item;
render_mode unshaded;

uniform float white_core = 0.0;
varying float lifetime_opacity;

void vertex() {
	lifetime_opacity = COLOR.a;
}

void fragment() {
	vec4 cloud = texture(TEXTURE, UV);
	float core = smoothstep(0.25, 0.8, cloud.a) * white_core;
	COLOR = vec4(mix(cloud.rgb, vec3(1.0), core), mix(pow(cloud.a, 0.46), 1.0, core) * lifetime_opacity);
}
