extends Control
## Shared visuals only: each encounter still owns skill mapping, SP and costs.
signal requested(action:String)
const Art=preload("res://scripts/hunt_match_art.gd")
const ROOT="res://assets/ui/d0071-hud/"
const PORTRAIT_SIZE:=66.0
const SKILL_BOX_LIGHT_ALPHA:=.50
const FACTOR:=.66
const PORTRAITS={"hangyeol":preload(ROOT+"han.png"),"uram":preload(ROOT+"uram.png"),"saebom":preload(ROOT+"saebom.png"),"gahui":preload("res://assets/ui/hero-level-up/gahui-portrait-original.png")}
const ORDINARY={"hangyeol":preload(ROOT+"han-2sp.png"),"uram":preload(ROOT+"uram-2sp.png"),"saebom":preload(ROOT+"saebom-2sp.png"),"gahui":preload("res://assets/ui/hero-level-up/gahui-preview-2sp.svg")}
const LINKED={"hangyeol":preload(ROOT+"han-3sp-A.png"),"uram":preload(ROOT+"uram-3sp.png"),"saebom":preload(ROOT+"saebom-3sp.png"),"gahui":preload("res://assets/ui/hero-level-up/gahui-preview-3sp.svg")}
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
var near_mode:=false
var warm_glow:TextureRect
var chain_glow:TextureRect
var orbs:Array[TextureRect]=[]
var orb_lights:Array[TextureRect]=[]
var orb_light_progress:Array[float]=[1.0,0.0,0.0]
var names:Label
var name_strip:Panel
var chain_frame:Panel
var duel_ready_feedback:=false
var normal_flash:TextureRect
var badge_flash:TextureRect
var linked_flash:TextureRect
var normal_border_arc:Control
var badge_border_arc:Control
var linked_outer_glow:Control
var hp:TextureProgressBar # Hidden compatibility state; HP is displayed overhead.
var sp_label:Label # Hidden: no separate SP text is drawn.
var normal_ready:=false
var chain_ready:=false
var chain_allowed:=true
var normal_age:=0.0
var chain_age:=0.0
var phase:=0.0
var normal_entries:=0
var chain_entries:=0
var character:="hangyeol"
var chain_foreground:Control
var normal_threshold:=2.0
var chain_threshold:=3.0

func place_local_combat_hud(center_x:float)->void:
	# A shared test-only layout inside the existing responsive arena safe area.
	const HUD_SCALE:=1.5
	scale=Vector2.ONE*HUD_SCALE
	position=Vector2(center_x-PORTRAIT_SIZE*HUD_SCALE*.5,406.)

func _ready()->void:
	mouse_filter=MOUSE_FILTER_IGNORE;size=Vector2(66,84)
	portrait_button=_button(self,Rect2(0,0,66,66),"skill")
	background=_panel(portrait_button,Rect2(0,0,66,66),Color(.165,.129,.106,0),Color("715535"),6.6,1)
	_panel(portrait_button,Rect2(2,2,62,62),Color(.20,.161,.133,.8),Color("9e7c51"),5.3,1)
	warm_glow=_rounded_glow(portrait_button,Rect2(2.64,2.64,60.72,60.72),[Color("ffd781"),Color("b07829"),Color("3d2a1b")],5)
	var mask=_panel(portrait_button,Rect2(1.98,1.98,62.04,62.04),Color.WHITE,Color.TRANSPARENT,4.62,0)
	mask.clip_children=CanvasItem.CLIP_CHILDREN_ONLY;mask.clip_contents=true
	portrait=Art.picture(mask,PORTRAITS.hangyeol,Rect2(-3.828,-3.696,69.696,65.736));portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	name_strip=_panel(portrait_button,Rect2(3.3,3.3,59.4,10.56),Color(.129,.102,.071,.8),Color.TRANSPARENT,2.64,0)
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
	chain_foreground=Control.new();chain_foreground.mouse_filter=MOUSE_FILTER_IGNORE;chain_foreground.size=Vector2(52.8,52.8);chain_foreground.pivot_offset=chain_foreground.size*.5;chain_button.add_child(chain_foreground)
	chain_art=Art.picture(chain_foreground,LINKED.hangyeol,Rect2(1.98,1.98,48.84,48.84))
	chain_frame=_panel(chain_button,Rect2(0,0,52.8,52.8),Color.TRANSPARENT,Color("9af3ff"),4.62,1)
	for i in 3:
		var orb=Art.picture(self,ORB_EMPTY,Rect2(Vector2((14+25*i)*FACTOR,104*FACTOR),Vector2(22,22)));orb.scale=Vector2.ONE*FACTOR;orbs.append(orb)
	hp=TextureProgressBar.new();hp.hide();add_child(hp);sp_label=Label.new();sp_label.hide();add_child(sp_label)
	reset("hangyeol")

# This project deliberately turns off mouse emulation from a native touch.
# Keep each finger owned by the actual button and accept only an in-bounds release.
class SkillInputButton extends Button:
	var finger:=-1
	var hit_extension:=Rect2()
	func _has_point(at:Vector2)->bool:
		return Rect2(Vector2.ZERO,size).has_point(at) or hit_extension.has_point(at)
	func _gui_input(event:InputEvent)->void:
		if event is InputEventScreenTouch:
			if event.pressed and finger<0 and not disabled:
				finger=event.index
				set_pressed_no_signal(true)
			elif not event.pressed and event.index==finger:
				finger=-1
				set_pressed_no_signal(false)
				if not disabled and not event.is_canceled() and _has_point(event.position):pressed.emit()
			accept_event()
		elif event is InputEventScreenDrag and event.index==finger:
			accept_event()

func _button(parent:Node,rect:Rect2,action:String)->Button:
	var b:=SkillInputButton.new()
	if action=="skill":
		# Lower-left tap region includes every visible pixel of the 2SP badge
		# even where it extends outside the portrait.
		b.hit_extension=Rect2(-12,34,48,43)
	b.position=rect.position;b.size=rect.size;b.focus_mode=Control.FOCUS_NONE;b.mouse_filter=MOUSE_FILTER_STOP;b.action_mode=BaseButton.ACTION_MODE_BUTTON_RELEASE
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
var portrait_feedback_enabled:=false
var portrait_feedback_last_hp:=-1
var portrait_feedback_age:=0.0
var portrait_feedback_dead:=false
var portrait_feedback_material:ShaderMaterial
var portrait_hurt_textures:Dictionary={}
const PORTRAIT_WOUND_SECONDS:=1.20

func enable_portrait_damage_feedback()->void:
	if portrait_feedback_enabled:return
	portrait_feedback_enabled=true
	var shader:=Shader.new()
	shader.code="""shader_type canvas_item;
	uniform float wound = 0.0;
	uniform bool defeated = false;
	uniform bool has_hurt_art = false;
	uniform sampler2D hurt_art : source_color, filter_linear;
	void fragment(){
		vec4 original=COLOR;
		if(!defeated && has_hurt_art && wound>0.0){
			vec4 hurt=texture(hurt_art,UV);
			float blended_alpha=mix(original.a,hurt.a,wound);
			original=vec4(mix(original.rgb*original.a,hurt.rgb*hurt.a,wound)/max(.001,blended_alpha),blended_alpha);
		}
		vec3 rgb=original.rgb;
		float luma=dot(rgb, vec3(.2126,.7152,.0722));
		if(defeated){ rgb=mix(rgb, vec3(luma),.94)*.57; }
		COLOR=vec4(rgb,original.a);
	}"""
	portrait_feedback_material=ShaderMaterial.new()
	portrait_feedback_material.shader=shader
	portrait.material=portrait_feedback_material
	_load_portrait_hurt_art(character)

func clear_portrait_damage_feedback()->void:
	portrait_feedback_last_hp=-1
	portrait_feedback_age=0.
	portrait_feedback_dead=false
	if portrait_feedback_enabled:
		portrait_feedback_material.set_shader_parameter("wound",0.0)
		portrait_feedback_material.set_shader_parameter("defeated",false)

func _sync_portrait_damage_feedback(health:int,living:bool,delta:float)->void:
	if not portrait_feedback_enabled:return
	portrait_feedback_age=maxf(0.,portrait_feedback_age-maxf(0.,delta))
	portrait_feedback_dead=not living or health<=0
	if portrait_feedback_dead:portrait_feedback_age=0.
	elif portrait_feedback_last_hp>health:portrait_feedback_age=PORTRAIT_WOUND_SECONDS
	portrait_feedback_last_hp=health
	var wound:=smoothstep(0.,.47,portrait_feedback_age)
	portrait_feedback_material.set_shader_parameter("wound",wound)
	portrait_feedback_material.set_shader_parameter("defeated",portrait_feedback_dead)


func _load_portrait_hurt_art(id:String)->void:
	if not portrait_feedback_enabled:return
	if not portrait_hurt_textures.has(id):
		var path:="res://assets/ui/test55-portraits/"+id+"-hurt.png"
		if ResourceLoader.exists(path,"Texture2D"):
			portrait_hurt_textures[id]=ResourceLoader.load(path,"Texture2D")
		elif FileAccess.file_exists(path):
			var input_image:=Image.load_from_file(path)
			if not input_image.is_empty():portrait_hurt_textures[id]=ImageTexture.create_from_image(input_image)
	var hurt:Texture2D=portrait_hurt_textures.get(id)
	portrait_feedback_material.set_shader_parameter("has_hurt_art",hurt!=null)
	if hurt!=null:portrait_feedback_material.set_shader_parameter("hurt_art",hurt)

func reset(id:String)->void:
	character=id;normal_ready=false;chain_ready=false;normal_age=0;chain_age=0;phase=0;normal_entries=0;chain_entries=0
	near_mode=false
	orb_light_progress.assign([1.0,0.0,0.0])
	_load_portrait_hurt_art(id)
	portrait.texture=PORTRAITS[id];badge_art.texture=ORDINARY[id];chain_art.texture=LINKED[id];names.text={"hangyeol":"한결","uram":"우람","saebom":"새봄","gahui":"가희"}[id]
	# Figma's88% figure width enlarged20%, with its real aspect and lower edge pinned.
	portrait.size=Vector2(69.696,69.696*portrait.texture.get_height()/portrait.texture.get_width())
	portrait.position=Vector2((62.04-portrait.size.x)*.5,62.04-portrait.size.y)
	var colors:Array=[Color("54c0bb"),Color("1a575b"),Color("112b32")] if id=="uram" else [Color("ffad92"),Color("8c3a53"),Color("301a2b")] if id=="saebom" else [Color("8ee6ff"),Color("2e75a2"),Color("122038")]
	chain_glow.texture=_glow(colors)
	var ordinary_colors:Array=[Color("469d9b"),Color("1a575b"),Color("112b32")] if id=="uram" else [Color("7ed9e3"),Color("236b7b"),Color("102e37")] if id=="saebom" else [Color("8ef1be"),Color("2b7955"),Color("0d2a22")]
	badge_glow.texture=_glow(ordinary_colors)
	sync(1,100,100,true,true,0)
	clear_portrait_damage_feedback()
var chain_border_speed:=1.0
var chain_border_age:=0.0

func sync(sp:float,health:int,max_health:int,living:bool,input_available:bool,delta:float,chain_input_available:Variant=null)->void:
	var ordinary:=living and sp+.000001>=normal_threshold;var linked:=chain_allowed and living and sp+.000001>=chain_threshold
	if ordinary and not normal_ready:normal_age=0;normal_entries+=1
	if linked and not chain_ready:chain_age=0;chain_border_age=0.;chain_entries+=1
	chain_border_age=chain_border_age+delta*chain_border_speed if linked else 0.
	normal_ready=ordinary;chain_ready=linked;normal_age=normal_age+delta if ordinary else 0;chain_age=chain_age+delta if linked else 0;phase=fposmod(chain_age,3.0) if linked else 0
	badge.visible=ordinary;chain_button.visible=linked;portrait_button.disabled=not ordinary or not input_available;chain_button.disabled=not linked or not (input_available if chain_input_available==null else bool(chain_input_available))
	warm_glow.visible=ordinary;warm_glow.modulate.a=smoothstep(0,.35,normal_age);frame.get_theme_stylebox("panel").border_color=Color("ffe2a0") if ordinary else Color("a38760")
	chain_glow.modulate=Color(1,1,1,lerpf(.5,1,smoothstep(0,.3,chain_age)))
	var t:=clampf(phase/.32,0.0,1.0)
	var angle:=sin(t*TAU*2.0)*(1.0-t) if linked and chain_age>=3 and phase<.32 else 0.0
	chain_foreground.rotation=deg_to_rad(7.2)*angle
	portrait.modulate=Color.WHITE if portrait_feedback_enabled or health>0 else Color(.35,.35,.35,.85);hp.max_value=max_health;hp.value=health
	_sync_portrait_damage_feedback(health,living,delta)
	for i in 3:
		var filled:=living and i<floori(sp+.000001)
		if not duel_ready_feedback or orb_lights.size()!=3:
			orbs[i].texture=ORB_FULL if filled else ORB_EMPTY
			continue
		orbs[i].texture=ORB_EMPTY
		orb_light_progress[i]=0.0 if portrait_feedback_enabled and not living else move_toward(orb_light_progress[i],1.0 if filled else 0.0,delta/(.22 if filled else .14))
		var light:=orb_lights[i]
		light.visible=orb_light_progress[i]>.001
		light.material.set_shader_parameter("fill_amount",orb_light_progress[i])
	_draw_duel_ready_state()

func set_saebom_distance_icon(close_mode:bool,skill:Texture2D)->void:
	if character!="saebom":return
	if near_mode!=close_mode:
		near_mode=close_mode
		badge_art.texture=skill if close_mode else ORDINARY.saebom

func enable_duel_ready_feedback()->void:
	duel_ready_feedback=true
	names.add_theme_font_size_override("font_size",9)
	var strip_height:=maxf(14,ceilf(names.get_minimum_size().y)+2)
	name_strip.position=Vector2(3.3,3.3)
	name_strip.size=Vector2(59.4,strip_height)
	names.position=name_strip.position
	names.size=name_strip.size
	var gold:=[Color("fff4bf"),Color("ffca65",.73),Color("efa328",0)]
	var blue:=[Color("f2fbff"),Color("70dbff",.75),Color("60a9ff",0)]
	var portrait_mask:=portrait.get_parent() as Control
	normal_flash=_ready_light(portrait_mask,Rect2(Vector2.ZERO,portrait_mask.size),gold)
	portrait_mask.move_child(normal_flash,portrait.get_index())
	badge_flash=_ready_light(badge,Rect2(0,0,26.4,26.4),gold)
	badge.move_child(badge_flash,badge_art.get_index())
	linked_flash=_ready_light(chain_button,Rect2(1,1,50.8,50.8),blue)
	chain_button.move_child(linked_flash,chain_foreground.get_index())
	normal_border_arc=_make_ready_arc(portrait_button,Rect2(2,2,62,62),5.8)
	badge_border_arc=_make_ready_arc(badge,Rect2(2,2,40,40),6.2,.70)
	badge_border_arc.name="HangyeolBadgeBorderArc"
	badge_border_arc.scale=Vector2.ONE*.60
	linked_outer_glow=_make_linked_outer_glow()
	_setup_ready_convergence()
	_setup_orb_lights()

func _make_ready_arc(parent:Control, contour:Rect2, radius:float, speed:float=1.0)->Control:
	var layer:=Control.new()
	layer.name="OrdinaryBorderArc"
	layer.mouse_filter=MOUSE_FILTER_IGNORE
	parent.add_child(layer)
	layer.draw.connect(func():_draw_ready_arc(layer,contour,radius,normal_age*speed))
	layer.hide()
	return layer

func _arc_point(box:Rect2, radius:float, distance:float)->Vector2:
	var straight:=box.size.x-2.0*radius
	var vertical:=box.size.y-2.0*radius
	var corner:=radius*PI*.5
	var d:=fposmod(distance,2.0*(straight+vertical)+4.0*corner)
	var p:=Vector2(radius,0)
	var points:=[Vector2(box.size.x-radius,radius),box.size-Vector2.ONE*radius,Vector2(radius,box.size.y-radius),Vector2.ONE*radius]
	var edges:=[straight,vertical,straight,vertical]
	for i in 4:
		var a:=float(i)*PI*.5-PI*.5
		if d < edges[i]:
			return box.position+p+Vector2(-sin(a),cos(a))*d
		d-=edges[i]
		if d < corner:
			return box.position+points[i]+Vector2.from_angle(a+d/radius)*radius
		d-=corner
		p=points[i]+Vector2.from_angle(a+PI*.5)*radius
	return box.position+p

func _ready_arc_heads(age:float, perimeter:float)->PackedFloat32Array:
	var base:=age*1.5/1.72+.05
	return PackedFloat32Array([perimeter*base,perimeter*(base+1.0/3.0),perimeter*(base+2.0/3.0)])

func _draw_ready_arc(layer:Control, box:Rect2, radius:float, age:float)->void:
	var perimeter:=2.0*(box.size.x+box.size.y-4.0*radius)+TAU*radius
	var path:=_closed_ready_arc(box,radius,perimeter,age)
	layer.draw_polyline(path,Color("ffab38",.20),5.2,true)
	layer.draw_polyline(path,Color("ffd66d",.54),2.1,true)
	layer.draw_polyline(path,Color("ffe5a7",.49),1.0,true)
	for head in _ready_arc_heads(age,perimeter):
		_draw_arc_streak(layer,box,radius,perimeter,head,age+head/perimeter)

func _closed_ready_arc(box:Rect2, radius:float, perimeter:float, age:float)->PackedVector2Array:
	var path:=PackedVector2Array()
	for i in 80:
		var u:=float(i)/80.0
		var d:=perimeter*u
		var tangent:=_arc_point(box,radius,d+.6)-_arc_point(box,radius,d-.6)
		var ripple:=sin(TAU*(u*19.0-age*3.4))*.45+sin(TAU*(u*33.0-age*2.1))*.28
		path.append(_arc_point(box,radius,d)+tangent.normalized().orthogonal()*ripple)
	path.append(path[0])
	return path

func _draw_arc_streak(layer:Control, box:Rect2, radius:float, perimeter:float, head:float, age:float)->void:
	var tint:=Color("ffbc43")
	var tip:=Color("fff2bd")
	var span:=perimeter*.30
	var previous:=_arc_point(box,radius,head-span)
	for j in range(1,19):
		var f:=float(j)/18.0
		var d:=head-span*(1.0-f)
		var point:=_arc_point(box,radius,d)
		var tangent:=_arc_point(box,radius,d+.6)-_arc_point(box,radius,d-.6)
		var jag:=sin(float(j)*7.5+age*13.0)*lerpf(1.7,.45,f)*sin(f*PI)
		point+=tangent.normalized().orthogonal()*jag
		var power:=smoothstep(0.0,.75,f)
		layer.draw_line(previous,point,Color(tint,.12*power),7.5,true)
		layer.draw_line(previous,point,Color(tint,.55*power),3.6,true)
		layer.draw_line(previous,point,Color(tip,power),1.65,true)
		previous=point
	var tip_normal:=(_arc_point(box,radius,head+.6)-_arc_point(box,radius,head-.6)).normalized().orthogonal()
	var fork:=previous+tip_normal*4.1
	layer.draw_line(previous,fork,Color(tint,.72),2.4,true)
	layer.draw_circle(previous,3.2,Color(tint,.28),true,-1,true)
	layer.draw_circle(previous,1.55,tip,true,-1,true)

func _make_linked_outer_glow()->Control:
	var margin:=26.0
	var halo:=Art.picture(chain_button,_glow([Color.WHITE,Color.WHITE,Color.WHITE]),Rect2(-margin,-margin,52.8+2.0*margin,52.8+2.0*margin))
	halo.name="LinkedOuterGlow"
	halo.mouse_filter=MOUSE_FILTER_IGNORE
	chain_button.move_child(halo,0)
	var shader:=Shader.new()
	shader.code="""
shader_type canvas_item;
render_mode blend_mix;
uniform float age = 0.0;
uniform float spread_scale = 1.0;
uniform vec3 outer_color = vec3(.08,.50,1.0);
uniform vec3 glow_tint = vec3(.54,.91,1.0);
uniform vec3 rim_color = vec3(.88,.985,1.0);
float bell(float x){return exp(-x*x);}
void fragment(){
	vec2 px=(UV-vec2(.5))*104.8;
	float corner=5.4;
	vec2 q=abs(px)-vec2(26.4-corner);
	float d=length(max(q,vec2(0.0)))+min(max(q.x,q.y),0.0)-corner;
	vec2 around=normalize(px+vec2(.001,0.0));
	float walk=sin(dot(around,vec2(6.3,-3.8))+age*4.9);
	float cross=sin(dot(around,vec2(-4.2,8.4))-age*3.4+.73);
	float rough=sin(dot(around,vec2(16.6,12.1))+age*7.7+walk*.8);
	float jitter=.52*walk+.31*cross+.14*rough;
	float peak=.70+.17*walk+.10*cross+.06*rough;
	float rim=bell((d-.9-jitter)/max(.65,.98+.23*cross+.12*rough));
	float spread_d=d/max(spread_scale,.1);
	float exterior=smoothstep(-.35,.9,spread_d);
	float bright=bell((spread_d-2.24-jitter*1.2)/3.45)*(.57+.14*walk)*exterior;
	float soft=bell(max(spread_d-3.0-jitter*1.6,0.0)/8.5)*(.47+.11*cross)*exterior;
	float falloff=bell(max(spread_d-4.0,0.0)/15.8)*.29*exterior;
	float phase=fract(age/2.28+.075*dot(around,vec2(.9,.7)));
	float pulse=sin(phase*3.14159265);
	float wave_at=mix(3.8,19.0,phase)+1.55*cross+1.08*walk;
	float echo=bell((spread_d-wave_at)/2.05)*(.19+.08*rough+.07*walk)*pulse*exterior;
	float mask=1.0-smoothstep(23.0,25.5,spread_d);
	vec3 cyan=mix(outer_color,glow_tint,clamp(bright+echo,0.0,1.0));
	vec3 tint=mix(cyan,rim_color,clamp(rim*(.82+.18*walk),0.0,1.0));
	COLOR=vec4(tint,clamp(rim*peak+bright+soft+falloff+echo,0.0,1.0)*mask);
}
"""
	var material:=ShaderMaterial.new()
	material.shader=shader
	halo.material=material
	halo.hide()
	return halo

func _setup_ready_convergence()->void:
	var shader:=Shader.new()
	shader.code="""
shader_type canvas_item;
render_mode blend_add;
uniform vec4 glow_color : source_color = vec4(1.0,0.7,0.3,1.0);
uniform float gather_phase = 0.0;
uniform float strength = 0.50;
void fragment() {
	vec2 uv = (UV - vec2(0.5)) * 2.0;
	float dist = length(uv);
	float edge = 1.0 - smoothstep(0.88, 1.0, max(abs(uv.x), abs(uv.y)));
	float radius = mix(1.07, 0.03, smoothstep(0.0, 1.0, gather_phase));
	float ring = exp(-pow((dist - radius) / 0.14, 2.0));
	float in_motion = smoothstep(0.0, 0.12, gather_phase) * (1.0 - smoothstep(0.81, 1.0, gather_phase));
	float core = exp(-pow(dist / 0.27, 2.0));
	float settled = smoothstep(0.65, 0.93, gather_phase);
	vec3 color = mix(glow_color.rgb, vec3(1.0), 0.22 * ring);
	COLOR = vec4(color, (0.15 * core + 0.58 * in_motion * ring + 0.17 * settled * core) * edge * strength);
}
"""
	for light in [badge_flash,linked_flash]:
		var material:=ShaderMaterial.new()
		material.shader=shader
		material.set_shader_parameter("glow_color",Color("ffd07a") if light==badge_flash else Color("86dcff"))
		material.set_shader_parameter("strength",SKILL_BOX_LIGHT_ALPHA)
		light.material=material

func _ready_gather_phase(age:float)->float:
	return clampf(fposmod(age,2.0)/1.42,0,1)

func _setup_orb_lights()->void:
	var shader:=Shader.new()
	shader.code="shader_type canvas_item; uniform float fill_amount = 0.0; void fragment() { vec4 orb = texture(TEXTURE, UV); float d = length(UV - vec2(0.50)); float radius = mix(0.04, 0.76, fill_amount); float spread = 1.0 - smoothstep(max(0.0, radius - 0.13), radius, d); COLOR = vec4(orb.rgb, orb.a * spread * smoothstep(0.0, 0.17, fill_amount)); }"
	for orb in orbs:
		var overlay:=Art.picture(self,ORB_FULL,Rect2(orb.position,orb.size))
		overlay.scale=orb.scale
		overlay.mouse_filter=MOUSE_FILTER_IGNORE
		var mat:=ShaderMaterial.new();mat.shader=shader
		overlay.material=mat
		overlay.hide()
		orb_lights.append(overlay)

func _ready_light(parent:Control,rect:Rect2,colors:Array)->TextureRect:
	var light:=Art.picture(parent,_glow(colors),rect)
	light.mouse_filter=MOUSE_FILTER_IGNORE
	var additive:=CanvasItemMaterial.new()
	additive.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD
	light.material=additive
	light.hide()
	return light

func _draw_duel_ready_state()->void:
	if not duel_ready_feedback:return
	var normal_frame:=frame.get_theme_stylebox("panel") as StyleBoxFlat
	normal_flash.visible=normal_ready
	badge_flash.visible=normal_ready
	linked_flash.visible=false # Do not wash or pulse the skill art.
	normal_border_arc.visible=false
	if normal_border_arc.visible:normal_border_arc.queue_redraw()
	badge_border_arc.visible=normal_ready
	if badge_border_arc.visible:badge_border_arc.queue_redraw()
	linked_outer_glow.visible=chain_ready
	linked_outer_glow.material.set_shader_parameter("spread_scale",.70)
	if chain_ready:
		var halo_mat:=linked_outer_glow.material as ShaderMaterial
		halo_mat.set_shader_parameter("age",chain_border_age)
		var outer:=Vector3(.08,.50,1.0)
		var glow:=Vector3(.54,.91,1.0)
		var rim:=Vector3(.88,.985,1.0)
		match character:
			"uram":
				outer=Vector3(.89,.16,.08)
				glow=Vector3(1.0,.47,.19)
				rim=Vector3(1.0,.86,.55)
			"saebom":
				outer=Vector3(.91,.51,.08)
				glow=Vector3(1.0,.78,.28)
				rim=Vector3(1.0,.96,.69)
		halo_mat.set_shader_parameter("outer_color",outer)
		halo_mat.set_shader_parameter("glow_tint",glow)
		halo_mat.set_shader_parameter("rim_color",rim)
	normal_frame.set_border_width_all(2 if normal_ready else 1)
	if normal_ready:
		var pulse:=pow(.5+.5*cos(normal_age*TAU/1.12),2.4)
		normal_flash.modulate.a=(.11+pulse*.39)*.90
		if character=="hangyeol":warm_glow.modulate.a=.82
		badge_flash.material.set_shader_parameter("gather_phase",_ready_gather_phase(normal_age))
		normal_frame.border_color=Color("ffe2a0") if character=="hangyeol" else Color("df9f34").lerp(Color("fff1ac"),.48+pulse*.52)
		badge_glow.modulate.a=.66*SKILL_BOX_LIGHT_ALPHA/.90
	var linked_frame:=chain_frame.get_theme_stylebox("panel") as StyleBoxFlat
	linked_frame.set_border_width_all(2 if chain_ready else 1)
	if chain_ready:
		linked_flash.material.set_shader_parameter("gather_phase",_ready_gather_phase(chain_age))
		chain_glow.modulate.a=.62*SKILL_BOX_LIGHT_ALPHA/.90
		linked_frame.border_color=Color("e8b95e")
