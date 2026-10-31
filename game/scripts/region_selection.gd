class_name RegionSelection
extends Control

const BASE := Vector2(1600,900)
const MAP := preload("res://assets/region-selection/2f8a0.png")
const SYMBOLS := preload("res://assets/region-selection/663c6.png")
const FOODS := preload("res://assets/region-selection/8f28a.png")
const RESET := preload("res://assets/region-selection/159ba.svg")
const DOT := preload("res://assets/region-selection/8b5a2.svg")
const SELECTED_DOT := preload("res://assets/region-selection/fc6ce.svg")
const REGIONS := {
	"jeongok": {"name":"전곡리","era":"구석기 · 전곡리","short":"구석기","intro":"강가를 살피며\n첫 터전을 찾아보세요.","point":Vector2(580,138),"label":Vector2(-252,24),"line":Vector2(-16,28),"focus":Vector2(610,260),"symbol":0,"food":0,"playable":false},
	"amsa": {"name":"암사동","era":"신석기 · 강변의 생활","short":"신석기","intro":"강가에 터를 잡고\n마을의 첫 불씨를 피우세요.","point":Vector2(610,214),"label":Vector2(-252,72),"line":Vector2(-16,76),"focus":Vector2(610,360),"symbol":1,"food":1,"playable":true},
	"dongsam": {"name":"동삼동","era":"신석기 · 바닷가의 생활","short":"신석기","intro":"바닷가에 터를 잡고\n삶의 첫 이야기를 시작하세요.","point":Vector2(967,633),"label":Vector2(-100,24),"line":Vector2(25,28),"focus":Vector2(610,450),"symbol":2,"food":2,"playable":false}}
var app: Node
var selected := "amsa"
var zoom := 1.0
var pan := Vector2.ZERO
var factor := 1.0
var origin := Vector2.ZERO
var ui_root: Control
var details: Panel
var title_label: Label
var era_label: Label
var intro_label: Label
var symbol: TextureRect
var food: TextureRect
var start_button: DemoButton
var motion: Tween
var fingers := {}
var moved := false
var multi := false
var pinch_distance := 1.0
var pinch_zoom := 1.0
var pinch_anchor := Vector2.ZERO
var saved := {}
var selection_count := 0
var marker_icons := {}
var marker_font:FontVariation

func _init(owner_app: Node, snapshot_state: Dictionary={}) -> void:
	app=owner_app;saved=snapshot_state;name="RegionSelection"

func _ready() -> void:
	size=Vector2(app.w,app.h);mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_repeat=CanvasItem.TEXTURE_REPEAT_DISABLED
	marker_font=FontVariation.new();marker_font.base_font=preload("res://assets/fonts/NotoSansKR.ttf");marker_font.variation_opentype={"wght":600}
	factor=minf(size.x/BASE.x,size.y/BASE.y);origin=(size-BASE*factor)*.5
	pan=origin
	for key in REGIONS:marker_icons[key]=round_picture(self,region_symbol(key),Rect2(Vector2.ZERO,Vector2.ONE*70*factor)).get_parent()
	ui_root=Control.new();ui_root.name="FixedMapUI";ui_root.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(ui_root);ui_root.position=origin;ui_root.scale=Vector2.ONE*factor
	var back=app.design_button(ui_root,"",Rect2(36,32,84,84),func():app.show_screen("title"),false,"");back.name="RegionBack"
	back.add_theme_stylebox_override("normal",DesignSkin.round_style("dark"));app.picture(back,preload("res://assets/region-selection/fac42.svg"),Rect2(24,24,36,36))
	text("첫 터전을 고르세요",Rect2(148,32,1220,64),48,Color("fff1d5"))
	text("대한민국의 강과 산을 따라, 나의 첫 이야기를 시작합니다",Rect2(148,100,1220,32),21,Color("ebd1a7"))
	var bag=app.design_button(ui_root,"",Rect2(1472,32,88,88),app.show_about,false,"bag");bag.name="RegionBag";bag.add_theme_stylebox_override("normal",DesignSkin.round_style("dark"))
	details=Panel.new();details.name="RegionDetails";details.position=Vector2(1140,173);details.size=Vector2(402,630);details.add_theme_stylebox_override("panel",DesignSkin.style("dark"));ui_root.add_child(details)
	app.picture(details,preload("res://assets/region-selection/ba95c.svg"),Rect2(0,0,402,630))
	symbol=round_picture(details,atlas(SYMBOLS,1),Rect2(127,28,148,148))
	title_label=panel_text("",Rect2(28,194,346,64),48,Color("eeeeee"))
	era_label=panel_text("",Rect2(28,276,346,32),21,Color("bbbbbb"))
	var divider=ColorRect.new();details.add_child(divider);divider.position=Vector2(28,326);divider.size=Vector2(346,2);divider.color=Color(0.7,0.7,0.7,.3);divider.mouse_filter=Control.MOUSE_FILTER_IGNORE
	intro_label=panel_text("",Rect2(28,346,346,80),26,Color("eeeeee"))
	for i in 3:app.picture(details,DemoArt.icon(["wood","stone","berries"][i]),Rect2(32+i*90,444,68,62))
	food=round_picture(details,atlas(FOODS,1),Rect2(302,444,62,62));food.name="RegionalFood";food.tooltip_text="지역의 생활을 소개하는 먹거리입니다. 보유 수량이 아닙니다."
	start_button=app.design_button(details,"이곳에서 시작",Rect2(28,524,346,86),app.start_region,true,"compass");start_button.name="RegionStart"
	var reset=app.design_button(ui_root,"",Rect2(40,810,76,76),restore,false,"");reset.name="MapReset";reset.tooltip_text="지도 최소 배율로 복원";reset.add_theme_stylebox_override("normal",DesignSkin.round_style("dark"));app.picture(reset,RESET,Rect2(23,23,30,30))
	var gesture_hint=text("두 손가락으로 확대·축소",Rect2(140,836,300,24),18,Color("fff1d5"))
	for fixed in [back,bag,reset,details]:
		var at:Vector2=origin+fixed.position*factor
		at=at.clamp(app.safe,size-app.safe-fixed.size*factor)
		fixed.position=(at-origin)/factor
	gesture_hint.position.y=reset.position.y+26
	app.picture(ui_root,DemoArt.icon("compass"),Rect2(1036,160,58,58));text("N",Rect2(1058,136,30,22),16,Color.WHITE)
	if not saved.is_empty():
		selected=saved.get("selected","amsa");zoom=clampf(saved.get("zoom",1.0),1,2);pan=size*.5-saved.get("center",BASE*.5)*factor*zoom;pan=bounded(pan,zoom)
	refresh();queue_redraw();trace_state("ready")

func trace_state(reason:String) -> void:
	if not app.test_mode:return
	var markers:Dictionary={}
	for key in REGIONS:
		var rect=marker_rect(key);markers[key]=[rect.position.x,rect.position.y,rect.size.x,rect.size.y]
	var reset=ui_root.get_node("MapReset").get_global_rect();var start=start_button.get_global_rect()
	print("REGION_STATE "+JSON.stringify({"reason":reason,"selected":selected,"zoom":zoom,"pan":[pan.x,pan.y],"size":[size.x,size.y],"markers":markers,"reset":[reset.position.x,reset.position.y,reset.size.x,reset.size.y],"start":[start.position.x,start.position.y,start.size.x,start.size.y],"playable":not start_button.disabled,"touches":fingers.size(),"ticks_ms":Time.get_ticks_msec()}))

func round_picture(parent:Node,texture:Texture2D,rect:Rect2) -> TextureRect:
	var mask=RoundAsset.new();parent.add_child(mask);mask.position=rect.position;mask.size=rect.size
	return app.picture(mask,texture,Rect2(Vector2.ZERO,rect.size))

func text(value:String, rect:Rect2, font_size:int, color:Color) -> Label:
	var node:Label=app.label(ui_root,value,font_size,color);node.position=rect.position;node.size=rect.size;return node

func panel_text(value:String, rect:Rect2, font_size:int, color:Color) -> Label:
	var node:Label=app.label(details,value,font_size,color);node.position=rect.position;node.size=rect.size;node.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;return node

static func atlas(sheet:Texture2D,index:int) -> AtlasTexture:
	var result=AtlasTexture.new();result.atlas=sheet;var width=sheet.get_width()/3.0;result.region=Rect2(index*width,0,width,sheet.get_height());return result

func region_symbol(key:String) -> Texture2D:
	return atlas(FOODS,2) if key=="dongsam" else atlas(SYMBOLS,REGIONS[key].symbol)

func update_markers() -> void:
	for key in marker_icons:marker_icons[key].position=marker_rect(key).position+Vector2(5.8,4.2)*factor
	queue_redraw()

func refresh() -> void:
	var data:Dictionary=REGIONS[selected]
	title_label.text=data.name;era_label.text=data.era;intro_label.text=data.intro;symbol.texture=region_symbol(selected);food.texture=atlas(FOODS,data.food)
	start_button.disabled=not data.playable
	start_button.text="이곳에서 시작" if data.playable else "준비 중"
	var font_size=24
	var text_width=DemoArt.theme().default_font.get_string_size(start_button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var icon_width=86*.54
	var group_x=(346-icon_width-8-text_width)*.5
	for child in start_button.get_children():
		if child is Label:
			child.text=start_button.text;child.position.x=group_x+icon_width+8;child.size.x=text_width
			child.add_theme_color_override("font_color",Color("49321e") if data.playable else Color("e8ddc8"))
		elif child is TextureRect:child.position.x=group_x
	start_button.hint_text="현재 데모는 암사동에서 시작할 수 있습니다." if not data.playable else ""
	update_markers()

func map_point(key:String) -> Vector2:return pan+REGIONS[key].point*factor*zoom
func marker_rect(key:String) -> Rect2:return Rect2(map_point(key)+REGIONS[key].label*factor,Vector2(249.6,82.8)*factor)

func bounded(value:Vector2,scale_value:float) -> Vector2:
	var extent=BASE*factor*scale_value
	for axis in 2:value[axis]=(size[axis]-extent[axis])*.5 if extent[axis]<=size[axis] else clampf(value[axis],size[axis]-extent[axis],0)
	return value

func pose(value:float,position_value:Vector2) -> void:
	zoom=clampf(value,1,2);pan=bounded(position_value,zoom);update_markers()

func animate_to(value:float,position_value:Vector2,seconds:float) -> void:
	if motion and motion.is_valid():motion.kill()
	var initial_zoom=zoom;var initial_pan=pan
	motion=create_tween();motion.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion.tween_method(func(t:float):pose(lerpf(initial_zoom,value,t),initial_pan.lerp(position_value,t)),0.0,1.0,seconds)
	motion.tween_callback(func():trace_state("animation_end"))

func select_region(key:String) -> void:
	if not REGIONS.has(key):return
	selected=key;selection_count+=1;refresh();app.audio.cue("ui")
	animate_to(2.0,origin+REGIONS[key].focus*factor-REGIONS[key].point*factor*2,0.6)

func restore() -> void:
	cancel_input();animate_to(1.0,origin,0.5)

func snapshot() -> Dictionary:return {"selected":selected,"zoom":zoom,"center":(size*.5-pan)/(factor*zoom)}

func cancel_input() -> void:
	fingers.clear();moved=false;multi=false
	if is_instance_valid(ui_root):
		for button in ui_root.find_children("*","Button",true,false):
			if button is DemoButton:button.clear()
	if motion and motion.is_valid():motion.kill()

func ui_hit(at:Vector2) -> bool:
	if app.modal:return true
	if details.get_global_rect().has_point(at):return true
	for control in ui_root.find_children("*","Button",true,false):
		if control.get_global_rect().has_point(at):return true
	return at.y<origin.y+132*factor

func begin_pointer(index:int,at:Vector2) -> void:
	if fingers.is_empty():moved=false;multi=false
	var owned=not ui_hit(at)
	fingers[index]={"at":at,"start":at,"owned":owned,"pan":pan}
	if owned and motion and motion.is_valid():motion.kill()
	if fingers.size()>=2:
		multi=true;moved=true
		var pair=fingers.values()
		if pair.size()==2 and pair[0].owned and pair[1].owned:
			pinch_distance=maxf(1,pair[0].at.distance_to(pair[1].at));pinch_zoom=zoom;pinch_anchor=((pair[0].at+pair[1].at)*.5-pan)/(factor*zoom)

func move_pointer(index:int,at:Vector2) -> void:
	if not fingers.has(index):return
	fingers[index].at=at
	if fingers.size()==2:
		var pair=fingers.values()
		if pair[0].owned and pair[1].owned:
			var next_zoom=clampf(pinch_zoom*pair[0].at.distance_to(pair[1].at)/pinch_distance,1,2)
			pose(next_zoom,(pair[0].at+pair[1].at)*.5-pinch_anchor*factor*next_zoom)
	elif fingers.size()==1 and fingers[index].owned:
		var delta:Vector2=at-fingers[index].start
		if delta.length()>8:moved=true
		if moved:pose(zoom,fingers[index].pan+delta)

func end_pointer(index:int,at:Vector2) -> void:
	if not fingers.has(index):return
	var tap:bool=fingers[index].owned and not moved and not multi and at.distance_to(fingers[index].start)<=8
	fingers.erase(index)
	if tap:
		for key in REGIONS:
			if marker_rect(key).has_point(at):select_region(key);break
	for id in fingers:fingers[id].start=fingers[id].at;fingers[id].pan=pan
	if fingers.size()==2:
		var pair=fingers.values()
		pinch_distance=maxf(1,pair[0].at.distance_to(pair[1].at));pinch_zoom=zoom;pinch_anchor=((pair[0].at+pair[1].at)*.5-pan)/(factor*zoom)
	if fingers.is_empty():trace_state("gesture_end")

func _input(event:InputEvent) -> void:
	if app.screen!="region":return
	if event is InputEventScreenTouch:
		if event.pressed:begin_pointer(event.index,event.position)
		else:end_pointer(event.index,event.position)
	elif event is InputEventScreenDrag:move_pointer(event.index,event.position)
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.device!=-1:
		if event.pressed:begin_pointer(-10,event.position)
		else:end_pointer(-10,event.position)
	elif event is InputEventMouseMotion and event.device!=-1:move_pointer(-10,event.position)

func _draw() -> void:
	if factor<=0:return
	# Edge-clamped map pixels fill non-16:9 margins without cropping the full map at minimum zoom.
	var tex_scale=Vector2(MAP.get_size())/BASE
	draw_texture_rect_region(MAP,Rect2(Vector2.ZERO,size),Rect2(-pan/(factor*zoom)*tex_scale,size/(factor*zoom)*tex_scale),Color.WHITE,false,false)
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.09,0.07,0.035,.1232))
	for key in REGIONS:
		var data:Dictionary=REGIONS[key];var chosen=key==selected;var point=map_point(key);var rect=marker_rect(key)
		if not Rect2(Vector2.ZERO,size).intersects(rect):continue
		draw_set_transform(point,atan2(data.line.y,data.line.x),Vector2.ONE*factor)
		var connector=preload("res://assets/region-selection/10e90.svg") if key=="amsa" else preload("res://assets/region-selection/90ccd.svg") if key=="jeongok" else preload("res://assets/region-selection/a211f.svg")
		draw_texture_rect(connector,Rect2(0,-2,data.line.length(),2),false)
		draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
		var dot_size=18.0 if chosen else 12.0;draw_texture_rect(SELECTED_DOT if chosen else DOT,Rect2(point-Vector2.ONE*dot_size*factor*.5,Vector2.ONE*dot_size*factor),false)
		draw_set_transform(rect.position,0,Vector2.ONE*factor)
		var style=DesignSkin.style("gold" if chosen else "dark")
		draw_style_box(style,Rect2(0,0,81.6,78.4));draw_style_box(style,Rect2(88,4,161.6,76.8))
		var color=Color("49321e") if chosen else Color("eeeeee")
		draw_string(marker_font,Vector2(97.6,35),data.name,HORIZONTAL_ALIGNMENT_LEFT,142.4,20,color)
		draw_string(marker_font,Vector2(97.6,61),data.short,HORIZONTAL_ALIGNMENT_LEFT,142.4,17,color)
		draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

