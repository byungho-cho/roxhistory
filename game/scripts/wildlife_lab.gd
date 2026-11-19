extends Control
signal exited
const Preview:=preload("res://scripts/wildlife_lab_preview.gd")
const Art:=preload("res://scripts/hunt_match_art.gd")
const GOLD:=preload("res://assets/ui/d0026/common-gold-default.svg")
const BLUE:=preload("res://assets/ui/d0026/common-sapphire-default.svg")
const ANIMALS:={
	"forest":{"title":"숲사슴","file":"forest-deer-req037.glb","attack":"front_hoof_kick","slam":"front_hoof_slam","ram":"antler_ram","contact":1.20},
	"stag":{"title":"산수사슴","file":"mountain-stag-req037.glb","attack":"front_hoof_kick","slam":"front_hoof_slam","ram":"antler_ram","contact":1.30},
	"juvenile":{"title":"어린 수퇘지","file":"juvenile-boar-req038.glb","attack":"basic_attack","charge":"charge_ram","contact":1.05},
	"adult":{"title":"큰 멧돼지","file":"adult-boar-req038.glb","attack":"basic_attack","charge":"heavy_charge_ram","contact":1.75},
}
const MOTIONS:={"idle":"대기","walk":"걷기","run":"달리기","attack":"기본 앞발차기","slam":"앞발 내려치기","ram":"뿔 들이받기","hit":"피격","charge":"돌진"}
const LOOP:=["idle","walk","run"]
var app:Node
var canvas:Control
var preview:Preview
var selected:="forest"
var selection:="idle"
var idle_elapsed:=0.0
var local_time:=0.0
var wall_time:=0.0
var rate:=1.5
var route:=false
var playing:=false
var contact_count:=0
var contact_wall:=-1.0
var contact_pulse:=0.0
var animal_buttons:Dictionary={}
var motion_buttons:Dictionary={}
var speed_buttons:Dictionary={}
var route_button:Button
var restart_button:Button
var back_button:Button
var status:Label
var mode_label:Label
var contact_label:Label
var pointer:=-1
var pressed_button:Button

func _ready()->void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var ground:=Art.picture(self,preload("res://assets/ui/hunting-formation/clearing-dirt.png"),Rect2())
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	canvas=Control.new();add_child(canvas)
	text("실험실 · 야생동물",Rect2(230,20,500,36),24)
	back_button=button("‹ 캐릭터 실험실",Rect2(24,20,170,42),func():exited.emit())
	var index:=0
	for key in ANIMALS:
		animal_buttons[key]=button(ANIMALS[key].title,Rect2(166+160*index,76,150,42),select_animal.bind(key),true)
		index+=1
	mode_label=text("",Rect2(170,126,620,28),16)
	status=text("대기 · 모션을 선택해 주세요",Rect2(180,157,600,28),17)
	contact_label=text("접촉 표시는 자세 검수용이며 피해·효과음이 없습니다",Rect2(130,352,700,24),15)
	for value in [1.0,1.5]:
		speed_buttons[value]=button("%.1f배"%value,Rect2(630+110*speed_buttons.size(),480,100,38),set_rate.bind(value),true)
	route_button=button("고정 경로 OFF",Rect2(205,480,170,38),toggle_route,true)
	restart_button=button("↻ 현재 모션",Rect2(390,480,155,38),restart_motion)
	resized.connect(fit)
	select_animal(selected)
	fit()

func text(value:String,rect:Rect2,px:int)->Label:
	var item:Label=app.label(canvas,value,px,Color("fff3d0"))
	item.position=rect.position;item.size=rect.size
	item.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	item.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	item.mouse_filter=Control.MOUSE_FILTER_IGNORE
	item.add_theme_color_override("font_outline_color",Color("322216"))
	item.add_theme_constant_override("outline_size",4)
	return item

func button(value:String,rect:Rect2,action:Callable,toggle:=false)->Button:
	var item:=Button.new()
	item.text=value;item.position=rect.position;item.size=rect.size
	item.toggle_mode=toggle;item.focus_mode=Control.FOCUS_NONE
	item.add_theme_font_override("font",FigmaArt.BODY)
	item.add_theme_font_size_override("font_size",18)
	for state in ["normal","hover","pressed","hover_pressed","disabled"]:
		var active:bool=toggle and state in ["pressed","hover_pressed"]
		var box:=StyleBoxTexture.new();box.texture=BLUE if active else GOLD
		for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:box.set_texture_margin(side,7)
		box.modulate_color=Color(.7,.7,.7,.6) if state=="disabled" else Color.WHITE
		item.add_theme_stylebox_override(state,box)
		item.add_theme_color_override("font_color" if state=="normal" else "font_"+state+"_color",Color("fff3d0") if active else Color("502c12"))
	item.pressed.connect(action);canvas.add_child(item)
	return item

func clip_for(key:String)->String:
	if key in ["idle","walk","run"]:return key
	if key=="hit":return "hit_reaction"
	return ANIMALS[selected].get(key,"")

func select_animal(key:String)->void:
	if not ANIMALS.has(key):return
	pointer=-1;pressed_button=null
	if is_instance_valid(preview):preview.set_enabled(false);preview.free()
	for b in motion_buttons.values():b.free()
	motion_buttons.clear()
	selected=key
	preview=Preview.new()
	preview.model_path="res://assets/animals/d0059/"+ANIMALS[key].file
	preview.render_size_factor=.75
	preview.scale=Vector2.ONE*.92
	preview.position=Vector2(480,325)
	canvas.add_child(preview);canvas.move_child(preview,0)
	preview.set_enabled(true)
	for id in animal_buttons:animal_buttons[id].set_pressed_no_signal(id==selected)
	var keys:Array=[]
	for id in MOTIONS:
		var clip:=clip_for(id)
		if not clip.is_empty() and preview.animation.has_animation(clip):keys.append(id)
	var index:=0
	var width:=minf(126,830.0/keys.size()-8)
	var start:=(960.0-(width+8)*keys.size()+8)*.5
	for id in keys:
		var label:String="기본 들이받기" if id=="attack" and key in ["juvenile","adult"] else MOTIONS[id]
		motion_buttons[id]=button(label,Rect2(start+(width+8)*index,412,width,42),play_motion.bind(id),true)
		index+=1
	play_motion("idle")
	refresh()

func play_motion(key:String)->void:
	var clip:=clip_for(key)
	if clip.is_empty() or not preview.animation.has_animation(clip):return
	selection=key;local_time=0;wall_time=0;contact_count=0;contact_wall=-1;contact_pulse=0;idle_elapsed=0
	preview.start(clip);preview.sample(0,route)
	playing=true
	for id in motion_buttons:motion_buttons[id].set_pressed_no_signal(id==key)
	refresh()

func restart_motion()->void:play_motion(selection)
func set_rate(value:float)->void:
	if value not in [1.0,1.5]:return
	rate=value;refresh()
func toggle_route()->void:
	route=not route;restart_motion()

func advance(delta:float)->void:
	if not playing:
		if selection not in LOOP:
			idle_elapsed+=delta*rate
			preview.sample(idle_elapsed,false)
		return
	var before:=local_time
	wall_time+=delta;local_time+=delta*rate
	contact_pulse=maxf(0,contact_pulse-delta)
	var length:=preview.length(clip_for(selection))
	var contact:=float(ANIMALS[selected].contact) if selection in ["slam","charge"] else -1.0
	if contact>0 and contact_count==0 and before<contact and local_time+.000001>=contact:
		contact_count+=1;contact_wall=wall_time;contact_pulse=.18
	if selection in LOOP:
		preview.sample(local_time,route)
		if route and selection in ["walk","run"] and local_time>=length*2:playing=false
	elif local_time<=length:
		preview.sample(local_time,false)
	else:
		preview.start("idle");preview.sample(0,false);playing=false
	refresh()

func refresh()->void:
	for value in speed_buttons:speed_buttons[value].set_pressed_no_signal(value==rate)
	route_button.set_pressed_no_signal(route)
	route_button.text="고정 경로 ON" if route else "고정 경로 OFF"
	mode_label.text="%.1f배 · "%rate+("걷기·달리기: 원본 이동 2주기 고정 경로" if route else "걷기·달리기: 제자리 검수 · 돌진은 원본 이동")
	status.text=ANIMALS[selected].title+" · "+("기본 들이받기" if selection=="attack" and selected in ["juvenile","adult"] else MOTIONS.get(selection,selection))+( " · 경로 종료" if route and not playing and selection in ["walk","run"] else " · 완료 / 대기" if not playing and selection not in LOOP else "")
	contact_label.text="접촉 자세 (검수 표시 · 피해 판정 아님)" if contact_pulse>0 else "접촉 표시는 자세 검수용이며 피해·효과음이 없습니다"
	contact_label.modulate=Color("ffd258") if contact_pulse>0 else Color.WHITE

func fit()->void:
	var region:=Rect2(Vector2.ZERO,size)
	if OS.has_feature("android"):
		var safe:=DisplayServer.get_display_safe_area();var physical:=Vector2(DisplayServer.screen_get_size())
		if safe.has_area() and physical.x>0 and physical.y>0:region=Rect2(Vector2(safe.position)*size/physical,Vector2(safe.size)*size/physical)
	var factor:=minf(region.size.x/960.0,region.size.y/540.0)
	canvas.scale=Vector2.ONE*factor
	canvas.position=region.position+(region.size-Vector2(960,540)*factor)*.5

func _process(delta:float)->void:
	if app.application_active:advance(delta)

func _input(event:InputEvent)->void:
	if not event is InputEventScreenTouch:return
	if event.pressed:
		if pointer>=0:return
		var list:Array=[back_button,route_button,restart_button]+animal_buttons.values()+motion_buttons.values()+speed_buttons.values()
		for b in list:
			if b.is_visible_in_tree() and not b.disabled and b.get_global_rect().has_point(event.position):
				pointer=event.index;pressed_button=b;get_viewport().set_input_as_handled();return
	elif event.index==pointer:
		var b:=pressed_button;pointer=-1;pressed_button=null
		get_viewport().set_input_as_handled()
		if not event.canceled and is_instance_valid(b) and b.get_global_rect().has_point(event.position):b.pressed.emit()
