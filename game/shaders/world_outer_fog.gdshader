shader_type canvas_item;
uniform vec2 viewport_size=vec2(960.0,540.0);
uniform vec2 camera_center=vec2(0.0);
uniform float map_zoom=1.0;
uniform float reference_scale=0.57416;
// Static presentation only. Exploration progression is intentionally not implemented.
uniform vec2 revealed_extent=vec2(1150.0,720.0);
void fragment(){
	vec2 p=(camera_center+(UV-.5)*viewport_size/map_zoom)/reference_scale;
	vec2 uv=1.0-abs(mod((p+vec2(170.0,90.0))/vec2(880.0,440.0),2.0)-1.0);
	vec4 cloud=texture(TEXTURE,uv);
	vec2 edge=min(uv,1.0-uv);
	cloud.a*=smoothstep(0.0,.045,min(edge.x,edge.y));
	float mask=smoothstep(.84,1.19,length(p/revealed_extent));
	vec3 color=mix(vec3(.89,.92,.92),cloud.rgb,cloud.a);
	COLOR=vec4(color,mask*(.78+.22*cloud.a));
}
