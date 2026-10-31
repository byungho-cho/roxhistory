shader_type canvas_item;
// Remove translucent generator bloom while preserving the authored stone and state tint.
varying vec4 tint;
void vertex(){tint=COLOR;}
void fragment(){vec4 tex=texture(TEXTURE,UV);COLOR=vec4(tex.rgb,smoothstep(0.45,0.65,tex.a))*tint;}
