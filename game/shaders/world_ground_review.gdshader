shader_type canvas_item;
uniform sampler2D soil_tex : source_color, filter_linear_mipmap;
uniform vec2 viewport_size=vec2(960.0,540.0);
uniform vec2 camera_center=vec2(0.0);
uniform float map_zoom=1.0;
uniform float reference_scale=0.57416;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
float fbm(vec2 p){return noise(p)*.55+noise(p*2.03)*.27+noise(p*4.11)*.13+noise(p*8.21)*.05;}
void fragment(){
	vec2 p=(camera_center+(UV-.5)*viewport_size/map_zoom)/reference_scale;
	vec2 warp=vec2(fbm(p/180.0),fbm((p+731.0)/180.0))*65.0;
	vec2 t=(p+warp)/vec2(253.021,133.248);
	vec2 mirrored=1.0-abs(mod(t,2.0)-1.0);
	vec3 grass=texture(TEXTURE,vec2(.209318,.265675)+mirrored*vec2(.568182,.53135)).rgb;
	float patch=fbm((p+warp)/260.0)+.12*(noise(p/12.0)-.5);
	float dirt=smoothstep(.46,.67,patch)*.82;
	vec2 soil_uv=.5+(1.0-abs(mod((p+warp)/140.0,2.0)-1.0)-.5)*vec2(.36,.22);
	vec3 soil=texture(soil_tex,soil_uv).rgb;
	float light=dot(grass,vec3(.299,.587,.114));
	grass=mix(vec3(light),grass,.78)*vec3(.94,1.0,.94);
	vec3 ground=mix(grass,soil*vec3(.88,.88,.80),dirt);
	ground*=.94+.12*fbm(p/72.0);
	COLOR=vec4(ground,1.0);
}
