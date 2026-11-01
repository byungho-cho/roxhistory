shader_type canvas_item;
render_mode unshaded;
uniform float edge_blend=0.0;
varying vec4 tint;
void vertex(){ tint=COLOR; }
void fragment(){
 vec4 source=texture(TEXTURE,UV);
 float rim=min(min(UV.x,1.0-UV.x),min(UV.y,1.0-UV.y));
 source.a*=mix(1.0,smoothstep(0.0,.07,rim),edge_blend);
 COLOR=source*tint;
}
