extends RefCounted
const ART:="res://assets/ui/hunt-readiness/"
static func branch(parent:Control,rect:Rect2,_animated:=false)->TextureRect:
 var picture:=TextureRect.new()
 picture.texture=load(ART+"vs/VS-Branch-Title.png")
 picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 picture.position=rect.position;picture.size=rect.size
 picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
 parent.add_child(picture)
 return picture
static func sky(parent:Control)->Control:
 var root:=Control.new();root.name="PowerSkyBackdrop"
 root.mouse_filter=Control.MOUSE_FILTER_IGNORE
 root.position=Vector2(-480,-10);root.size=Vector2(960,134.222)
 parent.add_child(root)
 var picture:=TextureRect.new()
 picture.texture=load(ART+"power/sky-original.png")
 picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 picture.stretch_mode=TextureRect.STRETCH_SCALE
 picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
 root.add_child(picture);picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var shader:=Shader.new()
 shader.code="""
shader_type canvas_item;
varying vec4 tint;
void vertex(){tint=COLOR;}
void fragment(){
 float y=UV.y;
 float mask=1.;
 if(y>.85)mask=mix(.204,0.,clamp((y-.85)/.15,0.,1.));
 else if(y>.65)mask=mix(.714,.204,(y-.65)/.20);
 else if(y>.48)mask=mix(1.,.714,(y-.48)/.17);
 float opacity=y<.5?mix(.902,.702,y*2.):mix(.702,.502,(y-.5)*2.);
 COLOR=texture(TEXTURE,UV)*tint;
 COLOR.a*=opacity*mask;
}
"""
 var material:=ShaderMaterial.new();material.shader=shader;picture.material=material
 var clouds:=TextureRect.new()
 clouds.texture=load(ART+"power/Side-Clouds-alpha.png")
 clouds.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 clouds.mouse_filter=Control.MOUSE_FILTER_IGNORE
 root.add_child(clouds);clouds.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 return root
static func portrait_fade()->ShaderMaterial:
 var shader:=Shader.new()
 shader.code="""
shader_type canvas_item;
varying vec4 tint;
void vertex(){tint=COLOR;}
void fragment(){COLOR=texture(TEXTURE,UV)*tint;COLOR.a*=clamp((1.-UV.y)/.18,0.,1.);}
"""
 var material:=ShaderMaterial.new();material.shader=shader;return material
const WARM_FILES:=["power/sky-original.png", "power/Side-Clouds-alpha.png", "power/han-static.png", "power/Deer-HUD-alpha.png", "vs/VS-Branch-Title.png", "vs/VS-Branch-V.png", "vs/VS-Branch-S.png", "vs/VS-Valley-Plate.png", "vs/VS-Teal-Amber-Plate.png", "vs/Deer-Bust-Extended.png", "brush/lv-brush-ally-up3.png", "brush/lv-brush-enemy-up3.png", "AUTO-0.png", "AUTO-1.png", "X2-0.png", "X2-1.png", "han-success.ogv", "han-failure.ogv", "han-success-first.png", "han-success-last.png", "han-failure-first.png", "han-failure-last.png"]
static func warm_paths()->Array:
 var paths:Array=[]
 for name in WARM_FILES:paths.append(ART+name)
 for role in ROLES:paths.append(ART+"role-badges/role-"+role+".png")
 return paths

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

static func vs_portrait_material(texture:Texture2D,left:bool)->ShaderMaterial:
 var shader:=Shader.new()
 shader.code="""
shader_type canvas_item;
uniform vec4 source_rect=vec4(0.,0.,1.,1.);
uniform bool left;
varying vec4 tint;
void vertex(){tint=COLOR;}
void fragment(){
 vec4 pixel=texture(TEXTURE,UV);
 vec2 p=(UV-source_rect.xy)/source_rect.zw;
 float q=pow(left?1.-p.x:p.x,1.28)*(1.-.43*p.y)*.12;
 vec3 shift=left?vec3(-80.,92.,148.):vec3(122.,45.,-30.);
 pixel.rgb=clamp(pixel.rgb+shift/255.*q,vec3(0.),vec3(1.));
 if(!left)pixel.a*=clamp((1.-p.y)/(63./329.),0.,1.);
 COLOR=pixel*tint;
}
"""
 var material:=ShaderMaterial.new();material.shader=shader
 material.set_shader_parameter("left",left)
 if texture is AtlasTexture:
  var atlas:=texture as AtlasTexture
  var extent:=atlas.atlas.get_size()
  material.set_shader_parameter("source_rect",Vector4(atlas.region.position.x/extent.x,atlas.region.position.y/extent.y,atlas.region.size.x/extent.x,atlas.region.size.y/extent.y))
 return material
