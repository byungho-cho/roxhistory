extends Control
## Readiness owns only HUD presentation; the isolated duel owns SP and activation.
signal requested(action: String)
const Art = preload("res://scripts/hunt_match_art.gd")
const Hunt = preload("res://scripts/deer_hunt_screen.gd")
const ROOT := "res://assets/ui/duel-hud/"
const WARM = preload(ROOT+"normal-warm-glow.svg")
const BRIGHT = preload(ROOT+"chain-bright-glow.svg")
const ELECTRIC = preload(ROOT+"chain-border-electric.svg")
const SPARKS = preload(ROOT+"chain-border-sparks.svg")
const ORDINARY := {
 "hangyeol":preload("res://assets/ui/d0027/skill-stab-A.png"),
 "uram":preload("res://assets/ui/d0027/skill-hit-B.png"),
 "saebom":preload(ROOT+"saebom-skill.png")}
const LINKED := {
 "hangyeol":preload(ROOT+"hangyeol-chain.jpg"),
 "uram":preload("res://assets/ui/d0036/uram-parry.png"),
 "saebom":preload(ROOT+"saebom-chain.jpg")}
const PORTRAIT_SIZE := 66.0
var portrait_button: Button
var chain_button: Button
var badge: Panel
var badge_art: TextureRect
var chain_art: TextureRect
var portrait: TextureRect
var background: Panel
var frame: Panel
var warm_glow: TextureRect
var chain_glow: TextureRect
var electricity: ColorRect
var border_art: Array[TextureRect] = []
var normal_ready := false
var chain_ready := false
var normal_age := 0.0
var chain_age := 0.0
var phase := 0.0
var normal_entries := 0
var chain_entries := 0
var orbs: Array[TextureRect] = []
var hp: TextureProgressBar
var names: Label
var sp_label: Label

func _ready() -> void:
 mouse_filter=MOUSE_FILTER_IGNORE
 size=Vector2(68,77)
 _panel(self,Rect2(-1,-4,68,77),Color(.21,.16,.10,.72),Color(.56,.43,.26,.65),5)
 portrait_button=_button(self,Rect2(0,0,66,66),"skill")
 background=_panel(portrait_button,Rect2(0,0,66,66),Color("564329"),Color.TRANSPARENT,4.5)
 warm_glow=_asset(portrait_button,WARM,Vector2.ZERO,.5)
 portrait=Art.picture(portrait_button,Hunt.HEADS,Rect2(1,0,63,61))
 _panel(portrait_button,Rect2(1,47,64,17),Color(.125,.094,.067,.85),Color.TRANSPARENT,3)
 var level=_label(portrait_button,"Lv.1",Rect2(4,2,30,11),8)
 level.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
 names=_label(portrait_button,"한결",Rect2(1,48,64,16),11)
 frame=_panel(portrait_button,Rect2(0,0,66,66),Color.TRANSPARENT,Color("b68a4c"),4.5)
 badge=_panel(self,Rect2(-9,29,33,33),Color("25201b"),Color("f8d887"),3.5)
 badge_art=Art.picture(badge,ORDINARY.hangyeol,Rect2(1,1,31,31))
 # Display-only badge: even the part outside the portrait forwards only skill.
 badge.mouse_filter=MOUSE_FILTER_STOP
 badge.gui_input.connect(_badge_input)
 chain_button=_button(self,Rect2(6.6,-64,52.8,52.8),"chain")
 _panel(chain_button,Rect2(0,0,52.8,52.8),Color("25201b"),Color("f8d887"),5.65)
 chain_art=Art.picture(chain_button,LINKED.hangyeol,Rect2(1.8,1.8,49.2,49.2))
 # Figma's upper-left background glow avoids the diagonal weapon artwork.
 chain_glow=_asset(chain_button,BRIGHT,Vector2.ZERO,.5)
 border_art.append(_asset(chain_button,ELECTRIC,Vector2(-.38,-.04),.5))
 border_art.append(_asset(chain_button,SPARKS,Vector2(.54,.25),.5))
 electricity=ColorRect.new();electricity.mouse_filter=MOUSE_FILTER_IGNORE
 electricity.position=Vector2(-1,-1);electricity.size=Vector2(54.8,54.8)
 var material:=ShaderMaterial.new();material.shader=preload("res://shaders/duel_ready_border.gdshader")
 electricity.material=material;chain_button.add_child(electricity)
 for i in 3:orbs.append(Art.picture(self,Hunt.CHARGE_EMPTY,Rect2(6+19*i,-9,16,6)))
 hp=TextureProgressBar.new();hp.mouse_filter=MOUSE_FILTER_IGNORE
 hp.position=Vector2(3,68);hp.size=Vector2(60,7);hp.nine_patch_stretch=true;hp.texture_under=Hunt.CARD_TRACK
 var fill:=GradientTexture2D.new();fill.width=60;fill.height=7;fill.gradient=Gradient.new()
 fill.gradient.colors=PackedColorArray([Color("93c341"),Color("93c341")]);hp.texture_progress=fill;add_child(hp)
 sp_label=_label(self,"1 / 3 SP",Rect2(71,62,62,15),10)
 reset("hangyeol")

func _button(parent:Node,rect:Rect2,action:String)->Button:
 var b:=Button.new();b.position=rect.position;b.size=rect.size;b.focus_mode=Control.FOCUS_NONE
 b.mouse_filter=MOUSE_FILTER_STOP;b.action_mode=BaseButton.ACTION_MODE_BUTTON_RELEASE
 for state in ["normal","hover","pressed","disabled","focus"]:b.add_theme_stylebox_override(state,StyleBoxEmpty.new())
 b.pressed.connect(func():requested.emit(action));parent.add_child(b);return b
func _panel(parent:Node,rect:Rect2,bg:Color,border:Color,radius:float)->Panel:
 var p:=Panel.new();p.position=rect.position;p.size=rect.size;p.mouse_filter=MOUSE_FILTER_IGNORE
 var style:=StyleBoxFlat.new();style.bg_color=bg;style.border_color=border
 style.set_border_width_all(1);style.set_corner_radius_all(roundi(radius));p.add_theme_stylebox_override("panel",style)
 parent.add_child(p);return p
func _asset(parent:Node,texture:Texture2D,at:Vector2,factor:float)->TextureRect:
 # Keep imported SVG root dimensions; scale its wrapper uniformly.
 var t:=Art.picture(parent,texture,Rect2(at,texture.get_size()));t.scale=Vector2.ONE*factor;return t
func _label(parent:Node,value:String,rect:Rect2,px:int)->Label:
 var l:=Label.new();l.position=rect.position;l.size=rect.size;l.text=value;l.mouse_filter=MOUSE_FILTER_IGNORE
 l.add_theme_font_size_override("font_size",px);l.add_theme_color_override("font_color",Color("fff3d8"))
 l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;l.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 parent.add_child(l);return l
func _badge_input(event:InputEvent)->void:
 # A release outside the portrait must still be a deliberate badge tap.
 if portrait_button.disabled:return
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
  requested.emit("skill");badge.accept_event()

func reset(character:String)->void:
 normal_ready=false;chain_ready=false;normal_age=0;chain_age=0;phase=0
 normal_entries=0;chain_entries=0
 var index: int=["hangyeol","uram","saebom"].find(character)
 var atlas:=AtlasTexture.new();atlas.atlas=Hunt.HEADS;atlas.region=Rect2(724*index,0,724,724)
 portrait.texture=atlas;portrait.stretch_mode=TextureRect.STRETCH_SCALE
 names.text={"hangyeol":"한결","uram":"우람","saebom":"새봄"}[character]
 badge_art.texture=ORDINARY[character];chain_art.texture=LINKED[character]
 sync(1,100,100,true,true,0)

func sync(sp:float,health:int,max_health:int,living:bool,input_available:bool,delta:float)->void:
 var ordinary:=living and sp+.000001>=2
 var linked:=living and sp+.000001>=3
 if ordinary and not normal_ready:normal_age=0;normal_entries+=1
 if linked and not chain_ready:chain_age=0;phase=0;chain_entries+=1
 normal_ready=ordinary;chain_ready=linked
 normal_age=normal_age+delta if ordinary else 0.0
 chain_age=chain_age+delta if linked else 0.0
 phase=fposmod(phase+delta/1.35,1) if linked else 0.0
 badge.visible=ordinary;chain_button.visible=linked
 portrait_button.disabled=not ordinary or not input_available
 chain_button.disabled=not linked or not input_available
 var rise:=smoothstep(0,.48,normal_age)
 background.get_theme_stylebox("panel").bg_color=Color("564329").lerp(Color("78603a"),rise) if ordinary else Color("564329")
 warm_glow.visible=ordinary;warm_glow.modulate.a=lerpf(.15,1,rise)
 frame.get_theme_stylebox("panel").border_color=Color("ffd96b") if ordinary else Color("b68a4c")
 var chain_rise:=smoothstep(0,.36,chain_age)
 chain_glow.visible=linked;chain_glow.modulate.a=lerpf(.1,1.45,chain_rise)
 electricity.visible=linked;electricity.material.set_shader_parameter("phase",phase)
 for t in border_art:
  t.visible=linked
  # Static design assets remain fixed; only a short light window travels.
  if t.material==null:
   var mat:=ShaderMaterial.new();mat.shader=preload("res://shaders/duel_ready_border.gdshader");mat.set_shader_parameter("asset_mask",true);t.material=mat
  t.material.set_shader_parameter("phase",phase)
 hp.max_value=max_health;hp.value=health;portrait.modulate=Color.WHITE if health>0 else Color(.35,.35,.35,.85)
 for i in 3:orbs[i].texture=Hunt.CHARGE_FULL if i<floori(sp+.000001) else Hunt.CHARGE_EMPTY
 sp_label.text="%d / 3 SP"%floori(sp+.000001)
