shader_type canvas_item;

uniform sampler2D face : source_color, filter_linear_mipmap;

float rounded_mask(vec2 point, vec2 size, float inset, float radius) {
	vec2 edge = abs(point - size * 0.5) - (size * 0.5 - vec2(inset + radius));
	float distance = length(max(edge, vec2(0.0))) + min(max(edge.x, edge.y), 0.0) - radius;
	return 1.0 - smoothstep(-0.5, 0.5, distance);
}

void fragment() {
	vec4 tint = COLOR;
	vec2 size = 1.0 / vec2(length(dFdx(UV)), length(dFdy(UV)));
	vec2 point = UV * size;
	float scale = min(size.y / 104.0, 1.0);
	float y = UV.y;
	vec3 rim = mix(vec3(0.95, 0.96, 0.97), vec3(0.22, 0.26, 0.30), smoothstep(0.0, 0.64, y));
	rim = mix(rim, vec3(0.64, 0.70, 0.75), smoothstep(0.64, 0.83, y));
	rim = mix(rim, vec3(0.28, 0.33, 0.37), smoothstep(0.83, 1.0, y));
	vec3 inner = mix(vec3(0.98), vec3(0.34, 0.39, 0.44), smoothstep(0.0, 0.35, y));
	inner = mix(inner, vec3(0.84, 0.88, 0.90), smoothstep(0.35, 1.0, y));
	vec3 color = mix(vec3(0.20, 0.23, 0.27), rim, rounded_mask(point,size,2.0*scale,15.0*scale));
	color = mix(color,inner,rounded_mask(point,size,3.0*scale,14.0*scale));
	color = mix(color,vec3(0.11,0.14,0.17),rounded_mask(point,size,6.0*scale,11.0*scale));
	float inset = 7.0 * scale;
	vec2 face_uv = clamp((point - vec2(inset)) / (size - vec2(2.0*inset)), vec2(0.0), vec2(1.0));
	vec3 metal = texture(face,face_uv).rgb;
	metal = mix(metal,vec3(1.0),0.25*(1.0-smoothstep(0.0,0.55,y)));
	metal *= 1.0-0.27*smoothstep(0.55,1.0,y);
	color = mix(color,metal,rounded_mask(point,size,inset,10.0*scale));
	float highlight = rounded_mask(point,size,10.0*scale,9.0*scale) - rounded_mask(point,size,11.0*scale,8.0*scale);
	color = mix(color,vec3(0.77,0.82,0.85),highlight*0.5);
	COLOR = vec4(color,rounded_mask(point,size,0.0,16.0*scale)) * tint;
}
