shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec3 background = texture(screen_texture, SCREEN_UV).rgb;
	COLOR = vec4(max(background, source.rgb), source.a);
}
