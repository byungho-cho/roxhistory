shader_type canvas_item;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 vec2 p=vec2(-600.0,-338.0)+UV*vec2(3600.0,2026.0);
 vec2 uv=p/vec2(2400.0,1350.0);
 vec2 mirrored=vec2(1.0)-abs(mod(uv,vec2(2.0))-vec2(1.0));
 vec4 ground=texture(TEXTURE,mirrored);
 vec2 beyond=max(max(-p,p-vec2(2400.0,1350.0)),vec2(0.0));
 float d=length(beyond);
 float cloud=noise(p*.008)*.65+noise(p*.019)*.35;
 float cover=smoothstep(0.0,130.0,d)*(0.80+cloud*.20);
 COLOR=vec4(mix(ground.rgb,mix(vec3(.80,.87,.88),vec3(1.0,.98,.92),cloud),cover),1.0);
}
