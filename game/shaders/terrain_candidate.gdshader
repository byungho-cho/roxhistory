shader_type canvas_item;
uniform sampler2D dirt_texture : source_color, filter_linear_mipmap;
uniform vec2 viewport_size=vec2(960.0,540.0);
uniform vec2 camera_center=vec2(0.0);
uniform float map_zoom=1.0;
uniform float reference_scale=0.57416;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
vec2 mirror_uv(vec2 p){return 1.0-abs(mod(p,2.0)-1.0);}
void fragment(){
	vec2 p=(camera_center+(UV-.5)*viewport_size/map_zoom)/reference_scale;
	vec3 grass=texture(TEXTURE,mirror_uv(p/750.0)).rgb;
	vec3 dirt=texture(dirt_texture,mirror_uv(p/900.0+vec2(.37,.61))).rgb;
	float mask=noise(p/510.0)*.72+noise(p/190.0)*.28;
	COLOR=vec4(mix(grass,dirt,smoothstep(.44,.74,mask)*.78),1.0);
}
