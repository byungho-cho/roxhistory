shader_type canvas_item;
uniform bool painted_center = false;
varying vec2 ground;
varying vec4 soil_color;
void vertex(){ground=VERTEX;soil_color=COLOR;}
void fragment(){
    // Reuse only the existing road's soil pixels, in world-sized grains rather
    // than stretching one source image over the entire length of each road.
    vec2 tile=1.0-abs(fract(ground*.013)*2.0-1.0);
    // Follow the diagonal source strip, staying inside its opaque soil core.
    // Mirrored coordinates remove rectangular seams without touching the asset.
    vec2 sample_uv=vec2(.52,.525)+(tile.x-.5)*vec2(.10,-.092)+(tile.y-.5)*vec2(.018,.027);
    if (painted_center) {
        sample_uv=vec2(.50,.52)+(tile.x-.5)*vec2(.18,-.16)+(tile.y-.5)*vec2(.026,.055);
    }
    vec3 soil=texture(TEXTURE,sample_uv).rgb;
    float grit=fract(sin(dot(floor(ground*.6),vec2(12.9898,78.233)))*43758.5453);
    COLOR=vec4(soil*(painted_center ? vec3(.96,.93,.87) : vec3(.88,.86,.78))*(.93+.10*grit),soil_color.a);
}
