extends Control
signal exited
const Actor=preload("res://scripts/model_test_actor.gd")
const Poly=preload("res://scripts/model_test_poly_catalog.gd")
const Catalog=preload("res://scripts/lab_motion_catalog.gd")
const Wildlife=preload("res://scripts/wildlife_lab.gd")
const Hunt=preload("res://scripts/deer_hunt_screen.gd")
const Art=preload("res://scripts/hunt_match_art.gd")
const GOLD=preload("res://assets/ui/d0026/common-gold-default.svg")
const BLUE=preload("res://assets/ui/d0026/common-sapphire-default.svg")
const SILVER=preload("res://assets/ui/d0049/button-stone-silver@2x.png")
const ROUND_GOLD=preload("res://assets/ui/d0060/round-gold.svg")
const ROUND_SILVER=preload("res://assets/ui/d0060/round-silver.svg")
const ROUND_RUBY=preload("res://assets/ui/d0063/round-ruby.svg")
const RATES=[3.0,2.5,2.0,1.75,1.5,1.0,.5]
const ALLIES=["hangyeol","uram","saebom"]
const LAB_ROSTER := ["hangyeol", "uram", "saebom", "gahui", "bau"]
const LAB_AVAILABLE := ["hangyeol", "gahui"]
const LAB_PORTRAITS := {
	"hangyeol": preload("res://assets/ui/test-roster/han.png"),
	"uram": preload("res://assets/ui/test-roster/uram.png"),
	"saebom": preload("res://assets/ui/test-roster/saebom.png"),
}
const ANIMALS=["forest","stag","juvenile","adult"]
const NAMES={"hangyeol":"한결","uram":"우람","saebom":"새봄","gahui":"가희","bau":"바우","forest":"숲사슴","stag":"산수사슴","juvenile":"어린 수퇘지","adult":"큰 멧돼지"}
const ORDER=["idle","walk","run","attack","hit","skill","chain","guard","counter","death","full"]
var app:Node
var canvas:Control
var field:Control
var actors:Dictionary={}
var captions:Dictionary={}
var polygon_labels:Dictionary={}
var category:="allies"
var selected:="all"
var selection:="idle"
var rate:=1.0
var battle:=false
var route:=false
var age:=0.0
var category_buttons:Dictionary={}
var model_buttons:Dictionary={}
var motion_buttons:Dictionary={}
var speed_buttons:Dictionary={}
var battle_button:Button
var route_button:Button
var restart_button:Button
var back_button:Button
var status:Label
var motion_status:Label
var hud:ColorRect
var selectors:Control
var motions:Control
var speeds:Control
var toggles:Control
var pointer:=-1
var pressed_button:Button
var logical_size:=Vector2(1600,1200)
var comparison_versions:Dictionary={}
var running_comparison:=false
var running_button:Button

static func portrait(id:String)->Texture2D:
	if id == "gahui":
		return preload("res://assets/ui/hero-level-up/gahui-portrait-original.png")
	if id == "bau":
		return preload("res://assets/ui/hero-level-up/bau-portrait-original.png")
	var source:=load("res://assets/ui/d0060/"+id+".png") as Texture2D
	var atlas:=AtlasTexture.new();atlas.atlas=source
	var dimensions:=Vector2(source.get_size())
	var animal:=id in ANIMALS
	atlas.region=Rect2(dimensions*Vector2(.025,.09),dimensions*Vector2(.20,.81)) if animal else Rect2(dimensions*Vector2(.375,.37 if id!="saebom" else .39),dimensions*Vector2(.25,.20))
	atlas.filter_clip=true
	# Material UVs must be local to the crop, rather than AtlasTexture UVs.
	return ImageTexture.create_from_image(source.get_image().get_region(Rect2i(atlas.region)))

func _ready()->void:
	name="Z90000"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=MOUSE_FILTER_STOP
	var backdrop:=Art.picture(self,preload("res://assets/ui/hunting-formation/clearing-dirt.png"),Rect2())
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);backdrop.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	canvas=Control.new();add_child(canvas)
	field=Control.new();canvas.add_child(field);field.clip_contents=true
	var ground:=Art.picture(field,preload("res://assets/ui/hunting-formation/clearing-dirt.png"),Rect2())
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ground.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	hud=ColorRect.new();hud.color=Color(0,0,0,.5);hud.mouse_filter=MOUSE_FILTER_IGNORE;field.add_child(hud)
	selectors=Control.new();field.add_child(selectors);selectors.position=Vector2(24,15.8);selectors.scale=Vector2.ONE*1.3
	back_button=button(selectors,"‹",Rect2(0,0,68,68),func():exited.emit(),"round")
	back_button.add_theme_font_size_override("font_size",54)
	build_selectors()
	var status_brush:=Art.picture(field,preload("res://assets/ui/brush/resource-slot-brush@2x.png"),Rect2(605,35,330,50));status_brush.modulate.a=.25
	status_brush.name="StatusBrush"
	status=text(field,"",Rect2(605,35,330,26),20)
	motion_status=text(field,"",Rect2(605,61,330,24),18)
	toggles=Control.new();field.add_child(toggles);toggles.position=Vector2(1162,20)
	battle_button=switch_button("전장뷰",0,toggle_battle)
	route_button=switch_button("고정 경로",180,toggle_route)
	speeds=Control.new();field.add_child(speeds)
	text(speeds,"배속",Rect2(0,0,96,27),20)
	for i in RATES.size():
		var item:=button(speeds,str(RATES[i]),Rect2(0,32+i*102,96,96),set_rate.bind(RATES[i]),"round")
		item.add_theme_font_size_override("font_size",29);item.modulate.a=.8
		speed_buttons[RATES[i]]=item
	motions=Control.new();field.add_child(motions)
	restart_button=button(field,"↻",Rect2(1414,934,96,96),restart,"round")
	skin(restart_button,ROUND_RUBY);restart_button.modulate.a=.8
	restart_button.add_theme_font_size_override("font_size",51)
	running_button=button(field,"달리기 비교",Rect2(925,77,190,36),toggle_running_comparison)
	running_button.add_theme_font_size_override("font_size",20)
	resized.connect(fit)
	start_preview()
	fit()

func build_selectors() -> void:
	category_buttons.allies=icon_button(selectors,"hangyeol",Rect2(80,0,68,68),choose_category.bind("allies"),false)
	category_buttons.animals=icon_button(selectors,"adult",Rect2(160,0,68,68),choose_category.bind("animals"),false)
	var divider:=ColorRect.new();divider.color=Color("64796c");divider.position=Vector2(248,12);divider.size=Vector2(1,44);divider.mouse_filter=MOUSE_FILTER_IGNORE;selectors.add_child(divider)

func start_preview() -> void:
	choose_category("allies")

func text(parent:Node,value:String,rect:Rect2,px:int,center:=true)->Label:
	var item:Label=app.label(parent,value,px,Color("fff9ec"))
	item.position=rect.position;item.size=rect.size
	item.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT
	item.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;item.mouse_filter=MOUSE_FILTER_IGNORE
	return item

func skin(item:Button, texture:Texture2D, disabled:=false)->void:
	for state in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
		var box:=StyleBoxTexture.new();box.texture=texture
		for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:box.set_texture_margin(side,0 if item.has_meta("round") else 7)
		box.modulate_color=Color(1,1,1,.4) if state=="disabled" else Color.WHITE
		item.add_theme_stylebox_override(state,box)
		item.add_theme_color_override("font_color" if state=="normal" else "font_"+state+"_color",Color("fff8e9") if texture==BLUE or item.has_meta("round") else Color("352519"))

func button(parent:Node,value:String,rect:Rect2,action:Callable,kind:="rect")->Button:
	var item:=Button.new();item.text=value;item.position=rect.position;item.size=rect.size
	item.focus_mode=Control.FOCUS_NONE;item.add_theme_font_override("font",FigmaArt.BODY);item.add_theme_font_size_override("font_size",22 if kind=="rect" else 19)
	if kind=="round":item.set_meta("round",true)
	skin(item,ROUND_GOLD if kind=="round" else GOLD)
	parent.add_child(item);item.pressed.connect(action)
	return item

func icon_button(parent:Node,id:String,rect:Rect2,action:Callable,circle:=true,portrait_override: Texture2D = null)->Button:
	var item:=button(parent,"",rect,action,"round" if circle else "rect")
	for state in ["normal","hover","pressed","focus"]:item.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	var icon:=Art.picture(item,portrait_override if portrait_override else portrait(id),Rect2(3,3,62,62))
	if portrait_override:
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var shader:=Shader.new();shader.code="shader_type canvas_item; uniform bool circle = true; void fragment(){ if(circle && distance(UV,vec2(.5))>.5){COLOR.a=0.;} }"
	var material:=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("circle",circle);icon.material=material
	item.set_meta("portrait",true);item.tooltip_text=NAMES[id]
	var border:=StyleBoxFlat.new();border.bg_color=Color.TRANSPARENT;border.border_color=Color("e6bc70");border.set_border_width_all(2);border.set_corner_radius_all(34 if circle else 12)
	for state in ["normal","hover","pressed","focus"]:item.add_theme_stylebox_override(state,border)
	return item

func switch_button(label:String,x:float,action:Callable)->Button:
	var brush:=Art.picture(toggles,preload("res://assets/ui/brush/resource-slot-brush@2x.png"),Rect2(x+43,-3,84,30));brush.modulate.a=.1
	text(toggles,label,Rect2(x,0,170,24),20)
	var item:=button(toggles,"",Rect2(x,30,170,50),action)
	item.set_meta("switch",true)
	return item

func show_switch(item:Button,enabled:bool)->void:
	for child in item.get_children():child.free()
	# The approved D0052 knobs and final Figma gradient tracks, at 170 × 50.
	var gradient:=Gradient.new();gradient.colors=PackedColorArray([Color("51cf7f"),Color("228d4f"),Color("0e5331")]) if enabled else PackedColorArray([Color("8f969c"),Color("828b93"),Color("475461")]);gradient.offsets=PackedFloat32Array([0,.5,1])
	var track:=GradientTexture2D.new();track.gradient=gradient;track.width=170;track.height=50;track.fill_from=Vector2(.5,0);track.fill_to=Vector2(.5,1)
	var picture:=Art.picture(item,track,Rect2(0,0,170,50))
	var shader:=Shader.new();shader.code="shader_type canvas_item; void fragment(){vec2 p=UV*vec2(170.,50.); float d=length(max(abs(p-vec2(85.,25.))-vec2(60.,0.),vec2(0.)))-25.;COLOR=texture(TEXTURE,UV);COLOR.a*=1.-smoothstep(-.8,.4,d);}"
	var material:=ShaderMaterial.new();material.shader=shader;picture.material=material
	Art.picture(item,preload("res://assets/ui/d0052/switch-knob-on.svg") if enabled else preload("res://assets/ui/d0052/switch-knob-off.svg"),Rect2(119.5 if enabled else 10.5,5,37,37))
	var label:=text(item,"ON" if enabled else "OFF",Rect2(12 if enabled else 68,6,85,34),24);label.modulate=Color("fcfced") if enabled else Color("1f2a34")
	for state in ["normal","hover","pressed","focus"]:item.add_theme_stylebox_override(state,StyleBoxEmpty.new())

func choose_category(value:String)->void:
	category=value;selected="all";running_comparison=false
	for item in model_buttons.values():item.free()
	model_buttons.clear()
	var ids:Array=ALLIES if category=="allies" else ANIMALS
	for i in ids.size():model_buttons[ids[i]]=icon_button(selectors,ids[i],Rect2(269+i*80,0,68,68),select_model.bind(ids[i]))
	model_buttons.all=button(selectors,"ALL",Rect2(269+ids.size()*80+12,0,68,68),select_model.bind("all"),"round")
	for key in category_buttons:category_buttons[key].modulate=Color.WHITE if key==category else Color(.65,.65,.65)
	rebuild_motions();select_model("all");fit()

func rebuild_motions()->void:
	for item in motion_buttons.values():item.free()
	motion_buttons.clear()
	var keys:Array=ORDER if category=="allies" else Actor.ANIMAL_ORDER+["full"]
	for i in keys.size():
		var id:String=keys[i]
		var title:String=Catalog.MOTIONS.get(id,Wildlife.MOTIONS.get(id,id))
		if category=="allies" and id=="skill":title="일반 스킬"
		if category=="allies" and id=="chain":title="연계 스킬"
		if category=="allies" and id=="guard":title="가드"
		if category=="animals" and id=="attack":title="기본 공격"
		motion_buttons[id]=button(motions,title,Rect2((i%7)*144.6,(i/7)*80.8,132.6,72.8),play_motion.bind(id))

func select_model(id:String)->void:
	if id!=selected:running_comparison=false
	selected=id;pointer=-1;pressed_button=null
	for actor in actors.values():actor.preview.set_enabled(false);actor.preview.free()
	for label in captions.values():label.free()
	for label in polygon_labels.values():label.free()
	actors.clear();captions.clear();polygon_labels.clear()
	var ids:Array=(["uram","hangyeol","saebom"] if category=="allies" else ANIMALS).duplicate() if id=="all" else [id]
	for key in ids:
		var actor:=Actor.new();actor.create(field,key,false if paired_comparison() or running_comparison else bool(comparison_versions.get(key,false)),"A" if running_comparison else "");field.move_child(actor.preview,1)
		field.move_child(actor.death_effect,2)
		actor.configure(battle)
		actors[key]=actor
		captions[key]=text(field,NAMES[key]+(" · B" if Poly.MODELS.has(key) and comparison_versions.get(key,false) else ""),Rect2(0,0,150,32),22)
		var brush:=StyleBoxFlat.new();brush.bg_color=Color("162e2a");brush.set_corner_radius_all(6)
		captions[key].add_theme_stylebox_override("normal",brush)
	if paired_comparison():
		# A always stays left and B right. Both adapters use the same key,
		# camera, lighting, local clock and motion mapping.
		var right_id:=id+"_B"
		var right:=Actor.new();right.create(field,id,true);right.configure(battle)
		field.move_child(right.preview,1);actors[right_id]=right
		field.move_child(right.death_effect,2)
		captions[id].text=NAMES[id]+" · 원본"
		captions[right_id]=text(field,NAMES[id]+" · 경량판",Rect2(0,0,150,32),22)
		var brush:=StyleBoxFlat.new();brush.bg_color=Color("162e2a");brush.set_corner_radius_all(6)
		captions[right_id].add_theme_stylebox_override("normal",brush)
		captions[id].hide();captions[right_id].hide()
		polygon_labels[id]=text(field,Poly.LABELS[id][0],Rect2(0,0,260,36),28)
		polygon_labels[right_id]=text(field,Poly.LABELS[id][1],Rect2(0,0,260,36),28)
	elif running_comparison:
		for variant in ["A","B","C"]:
			var key:String=id if variant=="A" else id+"_"+variant
			if variant!="A":
				var actor:=Actor.new();actor.create(field,id,false,variant);actor.configure(battle)
				actors[key]=actor;field.move_child(actor.preview,1)
				field.move_child(actor.death_effect,2)
				captions[key]=text(field,"",Rect2(),20)
			captions[key].hide()
			var label:String=variant+" · "+("현행" if variant=="A" else "원본 1.5배" if variant=="B" else "리폼 후보")
			label+="\n%.3f초"%actors[key].preview.motion_duration("run")
			polygon_labels[key]=text(field,label,Rect2(0,0,260,68),24)
	for key in model_buttons:model_buttons[key].modulate=Color.WHITE if key==id else Color(.7,.7,.7)
	skin(model_buttons.all,ROUND_GOLD if id=="all" else ROUND_SILVER)
	var next:=selection if motion_buttons.has(selection) else "idle"
	var supported:=false
	for actor in actors.values():supported=supported or actor.supported(next)
	layout_actors();play_motion(next if supported else "idle");refresh()

func play_motion(id:String)->void:
	if running_comparison and id not in ["idle","run"]:return
	var supported:=false
	for actor in actors.values():supported=supported or actor.supported(id)
	if not supported:return
	selection=id;age=0
	for actor in actors.values():actor.play(id)
	if id=="full" and selected=="all" and category=="allies":synchronize_full_chain()
	render_frame();refresh()

func restart()->void:play_motion(selection)

func chain_start(_key:String)->float:
	# The model test samples each linked clip immediately, with no battle slots.
	return 0.0

func synchronize_full_chain()->void:
	# Finish each preceding clip at its own unchanged speed. Shorter playlists
	# rest before the shared phase, rather than cutting an action or delaying a
	# character after the linked-skill phase has already begun.
	var common_start:=0.0
	for actor in actors.values():
		for segment in actor.segments:
			if segment.key=="chain":common_start=maxf(common_start,segment.start)
	for actor in actors.values():
		for i in actor.segments.size():
			if actor.segments[i].key!="chain":continue
			var prior_start:float=actor.segments[i].start
			var rest:=common_start-prior_start
			if rest>0.000001:
				for j in range(i,actor.segments.size()):
					actor.segments[j].start+=rest;actor.segments[j].end+=rest
				actor.segments.insert(i,{"key":"idle","start":prior_start,"end":common_start})
				actor.duration+=rest
			break
func paired_comparison()->bool:return Poly.MODELS.has(selected) and not running_comparison
func toggle_running_comparison()->void:
	if selected not in ["hangyeol","saebom"]:return
	running_comparison=not running_comparison
	selection="run" if running_comparison else "idle"
	select_model(selected)
func set_rate(value:float)->void:
	if value not in RATES:return
	rate=value;refresh()
func toggle_battle()->void:
	battle=not battle
	for actor in actors.values():actor.configure(battle)
	layout_actors();render_frame();refresh()
func toggle_route()->void:
	route=not route;restart();refresh()

func layout_actors()->void:
	var index:=0
	for key in actors:
		var actor:Actor=actors[key]
		var ground:Vector2
		if battle:
			var point:Vector2=Hunt.DEER_SLOT if category=="animals" else Hunt.HUNTER_BATTLE_CENTER
			if selected=="all":
				if category=="allies":point=Hunt.HUNTER_BATTLE_CENTER+(Hunt.ALLY_CELLS[{"hangyeol":0,"uram":5,"saebom":3}[key]]-Hunt.FORMATION_CENTER)*.62
				else:point+=Vector2((index%2)*48,(index/2)*58)
			ground=point/Vector2(960,540)*field.size
		else:
			var ground_y:=field.size.y*(.55 if field.size.y<700 else .62)
			ground=Vector2(field.size.x*(.25 if actors.size()==3 else .18)+(field.size.x*(.25 if actors.size()==3 else .21))*index,ground_y) if selected=="all" else Vector2(field.size.x*.5,ground_y)
		if paired_comparison():
			ground.x=field.size.x*(.30 if index==0 else .67)
			ground.y=minf(ground.y,field.size.y-210)
			if field.size.y<700:ground.y=field.size.y-200
		elif running_comparison:
			ground=Vector2(field.size.x*(.12+.28*index),field.size.y*.62 if field.size.y>=700 else field.size.y-200)
		actor.preview.set_meta("ground",ground)
		actor.preview.position=ground
		actor.preview.scale=Vector2.ONE*.92*(1.3 if key=="uram" else 1.05 if category=="allies" else 1.0)*(field.size.x/960.0)
		if paired_comparison() or running_comparison:
			actor.preview.scale*=minf(1,(field.size.y-300)/350.0)
			polygon_labels[key].position=Vector2(ground.x-130,124)
		captions[key].position=ground+Vector2(-75,18)
		actor.place_effect()
		index+=1

func render_frame()->void:
	var common_velocity:=Vector2.ZERO
	var local_age:=minf(age,.6) if running_comparison and route else age
	if running_comparison and route and selection=="run":
		var source:Actor=actors[selected]
		var p=source.preview
		var velocity=p.skeleton.global_basis*source.stride/source.duration
		common_velocity=(p.camera.unproject_position(velocity)-p.camera.unproject_position(Vector3.ZERO))*p.display.scale*p.scale
	for key in actors:
		var actor:Actor=actors[key]
		var start:=chain_start(key)
		if age<start:
			actor.resident_sample("idle",0.0)
		else:
			actor.sample(local_age,false) if running_comparison else actor.sample(age-start,route)
		var travel:float=actor.preview.get_meta("route_fraction",0.0)
		var direction:=Vector2(.82,-.36) if battle else Vector2(1,.28)
		actor.preview.position=actor.preview.get_meta("ground")+direction*travel*field.size.x*.12
		actor.preview.position+=actor.preview.get_meta("walk_offset",Vector2.ZERO)
		if running_comparison:actor.preview.position=actor.preview.get_meta("ground")+common_velocity*local_age
		actor.place_effect()
		captions[key].position=actor.preview.position+Vector2(-75,18)
	if selected=="all" and category=="allies":
		if selection=="chain" or (selection=="full" and actors.saebom.sampled_motion=="chain"):actors.saebom.face_support(actors.hangyeol.screen_anchor())
		else:actors.saebom.configure(battle)

func refresh()->void:
	for id in motion_buttons:
		var supported:=false
		for actor in actors.values():supported=supported or actor.supported(id)
		if running_comparison and id not in ["idle","run"]:supported=false
		motion_buttons[id].disabled=not supported
		skin(motion_buttons[id],SILVER if id=="full" else BLUE if id==selection else GOLD)
	for value in speed_buttons:skin(speed_buttons[value],ROUND_GOLD if value==rate else ROUND_SILVER)
	show_switch(battle_button,battle);show_switch(route_button,route)
	status.text=("아군 · 3명 비교" if category=="allies" else "CH1 · 4종 비교") if selected=="all" else NAMES[selected]
	if paired_comparison():status.text+=" · 원본 / 경량판"
	if running_comparison:status.text+=" · 달리기 A/B/C"
	running_button.visible=selected in ["hangyeol","saebom"]
	running_button.text="기본 보기로" if running_comparison else "달리기 비교"
	status.position=Vector2(900,16)
	motion_status.position.x=status.position.x
	motion_status.position.y=44
	status.size.x=240
	motion_status.size.x=status.size.x
	field.get_node("StatusBrush").position.x=status.position.x
	motion_status.text=motion_buttons[selection].text+" · "+str(rate)+"배속"

func fit()->void:
	var region := ViewportLayout.content_rect(size)
	if not region.has_area():
		return
	var factor:=region.size.x/1600.0
	logical_size=Vector2(1600,region.size.y/factor)
	factor=minf(factor,region.size.y/logical_size.y)
	canvas.scale=Vector2.ONE*factor;canvas.position=region.position+(region.size-logical_size*factor)*.5
	field.size=logical_size;hud.size=Vector2(field.size.x,120)
	motions.position=Vector2(24,field.size.y-177.6)
	var control_scale:=minf(1,(field.size.y-155)/856.0)
	speeds.scale=Vector2.ONE*control_scale;speeds.position=Vector2(field.size.x-30-96*control_scale,131)
	restart_button.scale=Vector2.ONE*control_scale
	restart_button.position=Vector2(field.size.x-30-96*control_scale,field.size.y-24-96*control_scale)
	# Keep the same right edge at every aspect ratio while fitting the rail.
	layout_actors()

func advance(delta:float)->void:
	age+=delta*rate;render_frame()
func _process(delta:float)->void:
	if app.application_active:advance(delta)

func _input(event:InputEvent)->void:
	if not event is InputEventScreenTouch:return
	if event.pressed:
		if pointer>=0:return
		var list:Array=[back_button,restart_button,running_button]+category_buttons.values()+model_buttons.values()+motion_buttons.values()+speed_buttons.values()
		for child in toggles.get_children():
			if child is Button:list.append(child)
		for item in list:
			if item.is_visible_in_tree() and not item.disabled and item.get_global_rect().has_point(event.position):pointer=event.index;pressed_button=item;get_viewport().set_input_as_handled();return
	elif event.index==pointer:
		var item:=pressed_button;pointer=-1;pressed_button=null;get_viewport().set_input_as_handled()
		if not event.canceled and is_instance_valid(item) and item.get_global_rect().has_point(event.position):item.pressed.emit()
