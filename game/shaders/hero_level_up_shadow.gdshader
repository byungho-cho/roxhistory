shader_type canvas_item;

void fragment() {
	// The SVG's Gaussian blur needs a runtime equivalent in Godot's SVG renderer.
	vec2 blur = vec2(6.0, 4.0) * TEXTURE_PIXEL_SIZE;
	float alpha = texture(TEXTURE, UV).a * 4.0;
	alpha += 2.0 * texture(TEXTURE, UV + vec2(blur.x, 0.0)).a;
	alpha += 2.0 * texture(TEXTURE, UV - vec2(blur.x, 0.0)).a;
	alpha += 2.0 * texture(TEXTURE, UV + vec2(0.0, blur.y)).a;
	alpha += 2.0 * texture(TEXTURE, UV - vec2(0.0, blur.y)).a;
	alpha += texture(TEXTURE, UV + blur).a + texture(TEXTURE, UV - blur).a;
	alpha += texture(TEXTURE, UV + vec2(blur.x, -blur.y)).a;
	alpha += texture(TEXTURE, UV + vec2(-blur.x, blur.y)).a;
	COLOR = vec4(0.0, 0.0, 0.0, alpha / 16.0);
}
