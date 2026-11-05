shader_type canvas_item;
varying vec4 tint;
void vertex(){tint=COLOR;}
uniform sampler2D background_tex : source_color;
uniform sampler2D border_tex : source_color;
uniform sampler2D mask_tex;
vec4 layer(sampler2D tex, vec2 uv) {
	if (any(lessThan(uv,vec2(0.0))) || any(greaterThan(uv,vec2(1.0)))) return vec4(0.0);
	return texture(tex,uv);
}
vec4 over(vec4 a,vec4 b) {
	float alpha=a.a+b.a*(1.0-a.a);
	return vec4((a.rgb*a.a+b.rgb*b.a*(1.0-a.a))/max(alpha,0.0001),alpha);
}
void fragment() {
	// Exact Figma 1024:39 layer geometry, in its 84x82 source coordinate system.
	vec2 p=UV*vec2(84.0,82.0);
	vec4 bg=layer(background_tex,(p-vec2(7.0,7.5))/vec2(70.0,68.0));
	vec4 frame=layer(border_tex,(p-vec2(-1.319, -2.534))/vec2(88.337,88.339));
	frame.a*=layer(mask_tex,(p-vec2(-0.497,-0.5))/vec2(85.0,83.0)).a;
	COLOR=over(frame,bg)*tint;
}
