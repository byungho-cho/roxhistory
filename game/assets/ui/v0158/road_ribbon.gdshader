shader_type canvas_item;
void fragment(){
 // Reuse the approved central soil pixels, without the source halo.
 vec2 sample_uv=vec2(0.46+(UV.x-0.5)*0.08,0.53+(UV.y-0.5)*0.08);
 vec4 soil=texture(TEXTURE,sample_uv);
 soil.a*=smoothstep(0.0,0.035,UV.y)*(1.0-smoothstep(0.965,1.0,UV.y));
 COLOR=soil;
}
