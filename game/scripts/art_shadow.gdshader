shader_type canvas_item;
render_mode unshaded;
uniform vec2 blur_step=vec2(.001);
uniform vec4 shadow_color:source_color=vec4(.1294,.0667,.0235,.30);
// Keep inherited panel/transition opacity before sampling the source texture.
varying vec4 inherited_tint;
void vertex(){ inherited_tint=COLOR; }
void fragment(){
 float a=texture(TEXTURE,UV).a*4.0;
 a+=texture(TEXTURE,UV+vec2(blur_step.x,0)).a*2.0;
 a+=texture(TEXTURE,UV-vec2(blur_step.x,0)).a*2.0;
 a+=texture(TEXTURE,UV+vec2(0,blur_step.y)).a*2.0;
 a+=texture(TEXTURE,UV-vec2(0,blur_step.y)).a*2.0;
 a+=texture(TEXTURE,UV+blur_step).a;
 a+=texture(TEXTURE,UV-blur_step).a;
 a+=texture(TEXTURE,UV+vec2(blur_step.x,-blur_step.y)).a;
 a+=texture(TEXTURE,UV+vec2(-blur_step.x,blur_step.y)).a;
 COLOR=vec4(shadow_color.rgb,shadow_color.a*a/16.0)*inherited_tint;
}
