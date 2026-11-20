shader_type canvas_item;
uniform float phase = 0.0;
uniform bool asset_mask = false;
void fragment() {
 vec2 p=UV-vec2(.5);
 float perimeter;
 if(abs(p.x)>abs(p.y)) perimeter=p.x>0.0 ? .25+(p.y+.5)*.25 : .75+(.5-p.y)*.25;
 else perimeter=p.y<0.0 ? (p.x+.5)*.25 : .5+(.5-p.x)*.25;
 float tail=fract(perimeter-phase+1.0);
 float window=(1.0-smoothstep(.04,.19,tail));
 float edge=abs(max(abs(p.x),abs(p.y))-.473);
 float filament=1.0-smoothstep(.008,.025,edge);
 if(asset_mask) COLOR=texture(TEXTURE,UV)*vec4(1.0,1.0,1.0,window);
 else COLOR=vec4(1.0,.88,.48,filament*window*.85);
}
