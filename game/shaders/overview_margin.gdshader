shader_type canvas_item;
render_mode unshaded;

void fragment() {
	// Reuse edge scenery only in the non-playable overview margin. Original
	// world pixels, water, resources and collision coordinates remain untouched.
	vec2 p = UV * 1.56 - vec2(0.28);
	float edge = max(max(-p.x, p.x - 1.0), max(-p.y, p.y - 1.0));
	float cloud = 0.5 + 0.22*sin(UV.x*33.0+UV.y*11.0) + 0.15*sin(UV.y*47.0-UV.x*19.0);
	// A low-frequency continuation of edge colours, not mirrored trees/houses.
	// Increasing the sample footprint outside the world avoids stretched streaks.
	vec2 border = clamp(p, vec2(0.001), vec2(0.999));
	float blur = max(0.0,edge)*0.85;
	vec3 scenery = texture(TEXTURE,border).rgb*0.2;
	scenery += texture(TEXTURE,clamp(border+vec2(blur,blur),vec2(0.001),vec2(0.999))).rgb*0.2;
	scenery += texture(TEXTURE,clamp(border+vec2(-blur,blur),vec2(0.001),vec2(0.999))).rgb*0.2;
	scenery += texture(TEXTURE,clamp(border+vec2(blur,-blur),vec2(0.001),vec2(0.999))).rgb*0.2;
	scenery += texture(TEXTURE,clamp(border-vec2(blur,blur),vec2(0.001),vec2(0.999))).rgb*0.2;
	float mist = smoothstep(0.0, 0.055, edge);
	vec3 fog = mix(vec3(0.72,0.79,0.75),vec3(0.88,0.90,0.84),cloud);
	COLOR = vec4(mix(scenery,fog,mist), step(0.0,edge));
}
