shader_type canvas_item;
void fragment(){
 // Reuse the approved soil pixels; discard the candidate's large golden halo.
 vec2 sample_uv=vec2(0.46+(UV.x-0.5)*0.08,0.53+(UV.y-0.5)*0.08);
 vec4 soil=texture(TEXTURE,sample_uv);
 vec2 p=abs(UV*2.0-1.0);
 float edge=p.x+p.y;
 soil.a*=1.0-smoothstep(0.86,1.05,edge);
 COLOR=soil;
}
