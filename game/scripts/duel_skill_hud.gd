extends Control
## Shared visuals only: each encounter still owns skill mapping, SP and costs.
signal requested(action:String)
const Art=preload("res://scripts/hunt_match_art.gd")
const ROOT="res://assets/ui/d0071-hud/"
const PORTRAIT_SIZE:=66.0
const FACTOR:=.66
const PORTRAITS={"hangyeol":preload(ROOT+"han.png"),"uram":preload(ROOT+"uram.png"),"saebom":preload(ROOT+"saebom.png")}
const ORDINARY={"hangyeol":preload(ROOT+"han-2sp.png"),"uram":preload(ROOT+"uram-2sp.png"),"saebom":preload(ROOT+"saebom-2sp.png")}
const LINKED={"hangyeol":preload(ROOT+"han-3sp-A.png"),"uram":preload(ROOT+"uram-3sp.png"),"saebom":preload(ROOT+"saebom-3sp.png")}
const ORB_FULL=preload(ROOT+"orb-active.svg")
const ORB_EMPTY=preload(ROOT+"orb-inactive.svg")
var portrait_button:Button
var chain_button:Button
var background:Panel
var frame:Panel
var portrait:TextureRect
var badge:Panel
var badge_art:TextureRect
var badge_glow:TextureRect
var chain_art:TextureRect
var warm_glow:TextureRect
var chain_glow:TextureRect
var orbs:Array[TextureRect]=[]
var names:Label
var hp:TextureProgressBar # Hidden compatibility state; HP is displayed overhead.
var sp_label:Label # Hidden: no separate SP text is drawn.
var normal_ready:=false
var chain_ready:=false
var normal_age:=0.0
var chain_age:=0.0
var phase:=0.0
var normal_entries:=0
var chain_entries:=0
var character:="hangyeol"
var chain_foreground:Control
var normal_threshold:=2.0
var chain_threshold:=3.0

func _ready()->void:
	mouse_filter=MOUSE_FILTER_IGNORE;size=Vector2(66,84)
	portrait_button=_button(self,Rect2(0,0,66,66),"skill")
	background=_panel(portrait_button,Rect2(0,0,66,66),Color(.165,.129,.106,0),Color("715535"),6.6,1)
	_panel(portrait_button,Rect2(2,2,62,62),Color(.20,.161,.133,.8),Color("9e7c51"),5.3,1)
	warm_glow=_rounded_glow(portrait_button,Rect2(2.64,2.64,60.72,60.72),[Color("ffd781"),Color("b07829"),Color("3d2a1b")],5)
	var mask=_panel(portrait_button,Rect2(1.98,1.98,62.04,62.04),Color.WHITE,Color.TRANSPARENT,4.62,0)
	mask.clip_children=CanvasItem.CLIP_CHILDREN_ONLY;mask.clip_contents=true
	portrait=Art.picture(mask,PORTRAITS.hangyeol,Rect2(-3.828,-3.696,69.696,65.736));portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_panel(portrait_button,Rect2(3.3,3.3,59.4,10.56),Color(.129,.102,.071,.8),Color.TRANSPARENT,2.64,0)
	names=_label(portrait_button,"한결",Rect2(3.3,3.3,59.4,10.56),8)
	frame=_panel(portrait_button,Rect2(1.32,1.32,63.36,63.36),Color.TRANSPARENT,Color("a38760"),5.94,1)
	badge=_panel(self,Rect2(-3.96,41.91,26.4,26.4),Color("0d2a22"),Color.TRANSPARENT,4.62,0)
	badge_glow=_rounded_glow(badge,Rect2(0,0,26.4,26.4),[Color("8ef1be"),Color("2b7955"),Color("0d2a22")],4.62)
	badge_art=Art.picture(badge,ORDINARY.hangyeol,Rect2(1.584,1.584,23.232,23.232))
	var edge=Art.picture(badge,preload(ROOT+"badge-edge.svg"),Rect2(0,0,40,40));edge.scale=Vector2.ONE*FACTOR
	badge.mouse_filter=MOUSE_FILTER_IGNORE # No second tap target or duplicate input.
	chain_button=_button(self,Rect2(6.6,-57.42,52.8,52.8),"chain")
	_panel(chain_button,Rect2(0,0,52.8,52.8),Color("122038"),Color.TRANSPARENT,5.28,0)
	chain_glow=_rounded_glow(chain_button,Rect2(0,0,52.8,52.8),[Color("8ee6ff"),Color("2e75a2"),Color("122038")],5.28)
	chain_foreground=Control.new();chain_foreground.mouse_filter=MOUSE_FILTER_IGNORE;chain_foreground.size=Vector2(52.8,52.8);chain_button.add_child(chain_foreground)
	chain_art=Art.picture(chain_foreground,LINKED.hangyeol,Rect2(1.98,1.98,48.84,48.84))
	_panel(chain_button,Rect2(0,0,52.8,52.8),Color.TRANSPARENT,Color("9af3ff"),4.62,1)
	for i in 3:
		var orb=Art.picture(self,ORB_EMPTY,Rect2(Vector2((14+25*i)*FACTOR,104*FACTOR),Vector2(22,22)));orb.scale=Vector2.ONE*FACTOR;orbs.append(orb)
	hp=TextureProgressBar.new();hp.hide();add_child(hp);sp_label=Label.new();sp_label.hide();add_child(sp_label)
	reset("hangyeol")

func _button(parent:Node,rect:Rect2,action:String)->Button:
	var b:=Button.new();b.position=rect.position;b.size=rect.size;b.focus_mode=Control.FOCUS_NONE;b.mouse_filter=MOUSE_FILTER_STOP;b.action_mode=BaseButton.ACTION_MODE_BUTTON_RELEASE
	for state in ["normal","hover","pressed","disabled","focus"]:b.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	b.pressed.connect(func():requested.emit(action));parent.add_child(b);return b
func _panel(parent:Node,rect:Rect2,bg:Color,border:Color,radius:float,width:int)->Panel:
	var p:=Panel.new();p.position=rect.position;p.size=rect.size;p.mouse_filter=MOUSE_FILTER_IGNORE
	var style:=StyleBoxFlat.new();style.bg_color=bg;style.border_color=border;style.set_border_width_all(width);style.set_corner_radius_all(roundi(radius));p.add_theme_stylebox_override("panel",style);parent.add_child(p);return p
func _label(parent:Node,value:String,rect:Rect2,px:int)->Label:
	var l:=Label.new();l.position=rect.position;l.size=rect.size;l.text=value;l.mouse_filter=MOUSE_FILTER_IGNORE;l.add_theme_font_size_override("font_size",px);l.add_theme_color_override("font_color",Color("fff0ca"));l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;l.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;parent.add_child(l);return l
func _rounded_glow(parent:Node,rect:Rect2,colors:Array,radius:float)->TextureRect:
	var mask:=_panel(parent,rect,Color.WHITE,Color.TRANSPARENT,radius,0)
	mask.clip_children=CanvasItem.CLIP_CHILDREN_ONLY
	return Art.picture(mask,_glow(colors),Rect2(Vector2.ZERO,rect.size))
func _glow(colors:Array)->GradientTexture2D:
	var texture:=GradientTexture2D.new();texture.width=96;texture.height=96;texture.fill=GradientTexture2D.FILL_RADIAL;texture.fill_from=Vector2(.5,.5);texture.fill_to=Vector2(1,.5);texture.gradient=Gradient.new();texture.gradient.offsets=PackedFloat32Array([0,.58,1]);texture.gradient.colors=PackedColorArray(colors);return texture
func reset(id:String)->void:
	character=id;normal_ready=false;chain_ready=false;normal_age=0;chain_age=0;phase=0;normal_entries=0;chain_entries=0
	portrait.texture=PORTRAITS[id];badge_art.texture=ORDINARY[id];chain_art.texture=LINKED[id];names.text={"hangyeol":"한결","uram":"우람","saebom":"새봄"}[id]
	# Figma's88% figure width enlarged20%, with its real aspect and lower edge pinned.
	portrait.size=Vector2(69.696,69.696*portrait.texture.get_height()/portrait.texture.get_width())
	portrait.position=Vector2((62.04-portrait.size.x)*.5,62.04-portrait.size.y)
	var colors:Array=[Color("54c0bb"),Color("1a575b"),Color("112b32")] if id=="uram" else [Color("ffad92"),Color("8c3a53"),Color("301a2b")] if id=="saebom" else [Color("8ee6ff"),Color("2e75a2"),Color("122038")]
	chain_glow.texture=_glow(colors)
	var ordinary_colors:Array=[Color("469d9b"),Color("1a575b"),Color("112b32")] if id=="uram" else [Color("7ed9e3"),Color("236b7b"),Color("102e37")] if id=="saebom" else [Color("8ef1be"),Color("2b7955"),Color("0d2a22")]
	badge_glow.texture=_glow(ordinary_colors)
	sync(1,100,100,true,true,0)
func sync(sp:float,health:int,max_health:int,living:bool,input_available:bool,delta:float)->void:
	var ordinary:=living and sp+.000001>=normal_threshold;var linked:=living and sp+.000001>=chain_threshold
	if ordinary and not normal_ready:normal_age=0;normal_entries+=1
	if linked and not chain_ready:chain_age=0;chain_entries+=1
	normal_ready=ordinary;chain_ready=linked;normal_age=normal_age+delta if ordinary else 0;chain_age=chain_age+delta if linked else 0;phase=fposmod(chain_age,3.0) if linked else 0
	badge.visible=ordinary;chain_button.visible=linked;portrait_button.disabled=not ordinary or not input_available;chain_button.disabled=not linked or not input_available
	warm_glow.visible=ordinary;warm_glow.modulate.a=smoothstep(0,.35,normal_age);frame.get_theme_stylebox("panel").border_color=Color("ffe2a0") if ordinary else Color("a38760")
	chain_glow.modulate=Color(1,1,1,lerpf(.5,1,smoothstep(0,.3,chain_age)))
	var twitch:=sin(phase/.2*TAU*2)*(1.0-phase/.2) if linked and chain_age>=3 and phase<.2 else 0.0
	chain_foreground.position=Vector2(twitch*.65,-absf(twitch)*.35)
	portrait.modulate=Color.WHITE if health>0 else Color(.35,.35,.35,.85);hp.max_value=max_health;hp.value=health
	for i in 3:orbs[i].texture=ORB_FULL if living and i<floori(sp+.000001) else ORB_EMPTY
