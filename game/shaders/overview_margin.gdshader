shader_type canvas_item;
render_mode unshaded;

void fragment() {
	// Fade into a soft cloud boundary inside the original edge. Outside is fully
	// covered, with neither mirrored scenery nor stretched edge-pixel streaks.
	vec2 p = UV * 1.2 - vec2(0.1);
	float edge = max(max(-p.x, p.x - 1.0), max(-p.y, p.y - 1.0));
	float cloud = 0.5 + 0.22*sin(UV.x*33.0+UV.y*11.0) + 0.15*sin(UV.y*47.0-UV.x*19.0);
	float mist = smoothstep(-0.055 + cloud*0.012, 0.0, edge);
	vec3 fog = mix(vec3(0.72,0.79,0.75),vec3(0.88,0.90,0.84),cloud);
	COLOR = vec4(fog,mist);
}
