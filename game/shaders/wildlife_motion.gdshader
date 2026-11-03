shader_type spatial;
render_mode cull_disabled;
uniform sampler2D coat : source_color, filter_linear_mipmap;
uniform float clock = 0.0;
uniform float grazing = 0.0;
uniform float walking = 0.0;
uniform float top = 2.0;
void vertex() {
	// Soft spatial weights preserve the source mesh and texture; no whole-body slide.
	float leg = 1.0-smoothstep(top*.22,top*.52,VERTEX.y);
	float side = VERTEX.x>0.0 ? 1.0 : -1.0;
	float fore = VERTEX.z>0.0 ? 1.0 : -1.0;
	float stride = sin(clock*4.2+side*fore*1.5708);
	VERTEX.z += stride*.07*leg*walking;
	VERTEX.y += max(0.0,cos(clock*4.2+side*fore*1.5708))*.035*leg*walking;
	float head = smoothstep(top*.52,top*.80,VERTEX.y)*smoothstep(-.15,.35,VERTEX.z);
	VERTEX.y -= head*grazing*.20;
	VERTEX.z += head*grazing*.08;
	VERTEX.x += sin(clock*1.3)*head*.012;
}
void fragment(){ALBEDO=texture(coat,UV).rgb;ROUGHNESS=.95;SPECULAR=.12;}
