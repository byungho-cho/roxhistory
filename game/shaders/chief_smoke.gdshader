shader_type canvas_item;
render_mode unshaded;

varying float lifetime_opacity;

void vertex() {
	lifetime_opacity = COLOR.a;
}

void fragment() {
	vec4 cloud = texture(TEXTURE, UV);
	COLOR = vec4(cloud.rgb, pow(cloud.a, 0.46) * lifetime_opacity);
}
