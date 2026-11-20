shader_type canvas_item;
void fragment(){COLOR.a*=1.0-smoothstep(.475,.5,length(UV-vec2(.5)));}
