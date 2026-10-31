shader_type canvas_item;
render_mode unshaded;
uniform vec2 viewport_size = vec2(960.0,540.0);
uniform vec2 map_origin = vec2(0.0);
uniform vec2 map_extent = vec2(960.0,540.0);

float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float soft_noise(vec2 p) {
	vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
void fragment() {
	vec2 point=UV*viewport_size;
	vec2 map_uv=(point-map_origin)/map_extent;
	float mist=soft_noise(point*.009)*.65+soft_noise(point*.003)*.35;
	vec3 ocean=mix(vec3(.025,.13,.22),vec3(.055,.25,.34),mist);
	vec3 source=texture(TEXTURE,clamp(map_uv,vec2(0),vec2(1))).rgb;
	// Fade only the narrow artwork rim; never extrude coastline pixels outside it.
	float edge=min(min(map_uv.x,map_uv.y),min(1.0-map_uv.x,1.0-map_uv.y));
	float coverage=smoothstep(0.0,.035,edge);
	COLOR=vec4(mix(ocean,source,coverage),1.0);
}
