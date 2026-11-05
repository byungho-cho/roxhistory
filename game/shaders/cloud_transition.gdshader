shader_type canvas_item;
uniform float coverage : hint_range(0.0, 1.0) = 0.0;
uniform float aspect = 1.7778;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float cloud_noise(vec2 p) {
	vec2 cell=floor(p), f=fract(p);f=f*f*(3.0-2.0*f);
	return mix(mix(hash(cell),hash(cell+vec2(1,0)),f.x),mix(hash(cell+vec2(0,1)),hash(cell+vec2(1,1)),f.x),f.y);
}
void fragment() {
	vec2 p=UV*vec2(aspect,1.0)*7.0;
	float billow=cloud_noise(p+vec2(coverage*.6,0.0));
	float detail=cloud_noise(p*2.0);
	float edge=min(UV.x,1.0-UV.x)+.16-billow*.13-detail*.025;
	float alpha=1.0-smoothstep(coverage*.76-.04,coverage*.76+.04,edge);
	alpha*=smoothstep(0.0,.07,coverage);
	vec3 cream=mix(vec3(.74,.80,.78),vec3(.99,.98,.91),.50+billow*.35+detail*.15);
	COLOR=vec4(cream,alpha);
}
