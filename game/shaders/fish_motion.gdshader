shader_type canvas_item;
uniform float phase=0.0;
uniform float clock=0.0;
void vertex(){VERTEX.y+=sin(clock*5.5+phase+UV.x*5.0)*2.0*(1.0-UV.x);}
