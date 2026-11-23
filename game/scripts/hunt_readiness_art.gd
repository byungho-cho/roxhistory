extends RefCounted
const ART:="res://assets/ui/hunt-readiness/"
const VS_MASK:="""
shader_type canvas_item;
varying vec4 item_tint;
void vertex(){item_tint=COLOR;}
uniform sampler2D plate : filter_linear;
uniform sampler2D unlit : filter_linear;
void fragment(){
 vec4 source=texture(TEXTURE,UV);
 vec3 background=texture(plate,UV).rgb;
 vec3 timber=texture(unlit,UV).rgb;
 float wood=smoothstep(.018,.060,timber.r-timber.b)*smoothstep(.07,.18,timber.r);
 float chroma=max(source.r,max(source.g,source.b))-min(source.r,min(source.g,source.b));
 float fire=smoothstep(.26,.38,chroma)*smoothstep(.60,.82,source.r)*(1.-smoothstep(.55,.85,source.b/max(.001,source.r)));
 float matte=max(wood,fire);
 float edge=smoothstep(0.,.06,UV.x)*(1.-smoothstep(.94,1.,UV.x))*smoothstep(0.,.08,UV.y)*(1.-smoothstep(.94,1.,UV.y));
 COLOR=vec4(source.rgb,source.a*matte*edge)*item_tint;
}
"""
static func branch_material()->ShaderMaterial:
 var material:=ShaderMaterial.new()
 var shader:=Shader.new();shader.code=VS_MASK
 material.shader=shader
 material.set_shader_parameter("plate",load(ART+"branch-vs-plate.png"))
 material.set_shader_parameter("unlit",load(ART+"branch-vs-unlit.png"))
 return material
static func branch(parent:Control,rect:Rect2,animated:bool)->Control:
 var item:Control
 if animated:
  var player:=VideoStreamPlayer.new()
  player.stream=load(ART+"branch-vs.ogv")
  player.expand=true;player.loop=false;player.volume_db=-80.
  item=player
 else:
  var texture:=TextureRect.new()
  texture.texture=load(ART+"branch-vs-unlit.png")
  texture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
  item=texture
 parent.add_child(item)
 item.position=rect.position;item.size=rect.size
 item.mouse_filter=Control.MOUSE_FILTER_IGNORE
 item.material=branch_material()
 return item
static func sky(parent:Control)->Control:
 var sky:=ColorRect.new()
 parent.add_child(sky)
 sky.mouse_filter=Control.MOUSE_FILTER_IGNORE
 sky.position=Vector2(-960,0);sky.size=Vector2(2880,110)
 var shader:=Shader.new()
 shader.code="""
shader_type canvas_item;
varying vec4 item_tint;
void vertex(){item_tint=COLOR;}
void fragment(){
 float y=UV.y;
 float fade=1.-smoothstep(.86,1.,y);
 vec3 blue=mix(vec3(.23,.43,.65),vec3(.91,.94,.92),smoothstep(.0,1.,y));
 float alpha=mix(.10,.50,y)*fade;
 float cloud=exp(-pow((y-.64)*5.,2.))*pow(.5+.5*sin(UV.x*18.+sin(UV.x*41.)),2.);
 COLOR=vec4(mix(blue,vec3(.96,.97,.96),cloud*.75),alpha+cloud*.10*fade)*item_tint;
}
"""
 var material:=ShaderMaterial.new();material.shader=shader;sky.material=material
 return sky


const ROLES:=["ally-melee","ally-ranged","ally-healer","ally-shaman","ally-tank","enemy-melee","enemy-ranged"]
static func role_texture(role:String)->Texture2D:
 if role not in ROLES:return null
 return load(ART+"role-badges/role-"+role+".png")
static func role_material()->ShaderMaterial:
 var shader:=Shader.new()
 shader.code="""
shader_type canvas_item;
varying vec4 item_tint;
void vertex(){item_tint=COLOR;}
void fragment(){
 vec2 p=abs((UV-.5)*19.)-vec2(5.5);
 float sdf=length(max(p,vec2(0.)))+min(max(p.x,p.y),0.)-4.;
 COLOR=texture(TEXTURE,UV)*item_tint;
 COLOR.a*=1.-smoothstep(-.4,.4,sdf);
}
"""
 var material:=ShaderMaterial.new();material.shader=shader
 return material
