class_name RegionSelection
extends Control

const BASE:=RegionCatalog.BASE
const REGIONS:=RegionCatalog.REGIONS
var app:Node
var selected:="amsa"
var camera:=RegionCamera.new()
var zoom:float:
	get:return camera.zoom
	set(value):camera.zoom=value
var pan:Vector2:
	get:return camera.pan
	set(value):camera.pan=value
var factor:float:
	get:return camera.factor
var ui_factor:=1.0
var origin:=Vector2.ZERO
var ui_root:Control
var details:RegionPanel
var title_label:Label
var era_label:Label
var intro_label:Label
var symbol:TextureRect
var food:TextureRect
var start_button:DemoButton
var markers:RegionMarkers
var map_surface:TextureRect
var panel_visible:=true
var motion:Tween
var fingers:={}
var moved:=false
var multi:=false
var pinch_distance:=1.0
var pinch_zoom:=1.0
var pinch_anchor:=Vector2.ZERO
var saved:={}
var selection_count:=0

func _init(owner_app:Node,snapshot_state:Dictionary={}) -> void:
	app=owner_app;saved=snapshot_state;name="RegionSelection"

func _ready() -> void:
	size=Vector2(app.w,app.h);mouse_filter=Control.MOUSE_FILTER_IGNORE;clip_contents=true
	camera.configure(size)
	ui_factor=minf(size.x/BASE.x,size.y/BASE.y);origin=(size-BASE*ui_factor)*.5
	map_surface=FigmaArt.picture(self,"94b86.png",Rect2(camera.pan,BASE*factor))
	# Figma uses cover, retaining the source aspect ratio (1672 x 941).
	map_surface.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	markers=RegionMarkers.new(self);add_child(markers)
	ui_root=Control.new();ui_root.name="FixedMapUI";ui_root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui_root.position=origin;ui_root.scale=Vector2.ONE*ui_factor;add_child(ui_root)
	var back:=FigmaArt.button(ui_root,"back",Rect2(35,29,73,73),"",func():app.show_screen("title"),app);back.name="RegionBack";back.tooltip_text="뒤로가기"
	var heading:=FigmaArt.stone_title(ui_root,"첫 터전을 고르세요","title-region.png",Rect2(127,41.5371,251.5737,36.4773));heading.name="RegionHeading"
	var subtitle:=FigmaArt.text(ui_root,"이야기가 시작될 곳을 찾아보세요.",Rect2(127,84,600,27),18,FigmaArt.NOTO,Color("fcf4d8"),false)
	var bag:=FigmaArt.button(ui_root,"bag",Rect2(1495.5,32.764,72,65.471),"",app.show_about,app);bag.name="RegionBag";bag.tooltip_text="가방과 설정"
	var compass:=FigmaArt.picture(ui_root,"compass",Rect2(1502.5,135.983,50,61.034))
	var north:=FigmaArt.text(ui_root,"N",Rect2(1515,113,24,20),17,FigmaArt.NOTO,Color("fcf4d8"))
	details=RegionPanel.new(app);ui_root.add_child(details);details.position=Vector2(1178,372)
	title_label=details.title_label;era_label=details.era_label;intro_label=details.intro_label;symbol=details.symbol;start_button=details.start_button
	var reset:=FigmaArt.button(ui_root,"reset",Rect2(35,792,73,73),"",restore,app);reset.name="MapReset";reset.tooltip_text="선택을 유지하고 전체 지도로 복원"
	var hint:=FigmaArt.text(ui_root,"두 손가락 또는 Ctrl + 휠로 확대·축소",Rect2(127,815,520,30),17,FigmaArt.NOTO,Color("fcf4d8"),false);hint.name="GestureHint"
	for label in [subtitle,hint,north]:
		label.add_theme_color_override("font_shadow_color",Color(0,0,0,.65));label.add_theme_constant_override("shadow_offset_y",2)
	# Design padding already covers ordinary displays. Add only real/custom insets.
	var inset:Vector2=app.safe if app.safe.x>24 or app.safe.y>18 else Vector2.ZERO
	var left_shift:float=(maxf(inset.x,35*ui_factor)-origin.x)/ui_factor-35
	var top_shift:float=(maxf(inset.y,29*ui_factor)-origin.y)/ui_factor-29
	for item in [back,heading,subtitle]:item.position+=Vector2(left_shift,top_shift)
	var right_shift:float=(size.x-maxf(inset.x,25*ui_factor)-origin.x)/ui_factor-1575
	for item in [bag,compass,north,details]:item.position.x+=right_shift
	for item in [bag,compass,north]:item.position.y+=top_shift
	var bottom_shift:float=(size.y-maxf(inset.y,35*ui_factor)-origin.y)/ui_factor-865
	reset.position+=Vector2(left_shift,bottom_shift);hint.position+=Vector2(left_shift,bottom_shift)
	details.position.y=(size.y-maxf(inset.y,45*ui_factor)-origin.y)/ui_factor-483
	if not saved.is_empty():
		selected=saved.get("selected","amsa")
		panel_visible=saved.get("panel_visible",true)
		if not REGIONS.has(selected):selected="amsa"
		zoom=clampf(saved.get("zoom",1.0),1,2);pan=bounded(size*.5-saved.get("center",BASE*.5)*factor*zoom,zoom)
		if saved.get("overview",false) and is_equal_approx(zoom,1):pan=camera.overview_pan()
	refresh();trace_state("ready")

func update_markers() -> void:
	map_surface.position=pan;map_surface.size=BASE*factor*zoom
	markers.refresh()

func refresh() -> void:
	details.show_region(selected);details.visible=panel_visible;food=details.food;update_markers()

func map_point(key:String) -> Vector2:return camera.project(REGIONS[key].point)
func marker_rect(key:String) -> Rect2:return markers.hit_rect(key)
func bounded(value:Vector2,scale_value:float) -> Vector2:return camera.bounded(value,scale_value)
func pose(value:float,position_value:Vector2) -> void:
	camera.pose(value,position_value);update_markers()

func trace_state(reason:String) -> void:
	if not app.test_mode:return
	var markers:Dictionary={}
	for key in REGIONS:
		var rect=marker_rect(key);markers[key]=[rect.position.x,rect.position.y,rect.size.x,rect.size.y]
	var reset=ui_root.get_node("MapReset").get_global_rect();var start=start_button.get_global_rect()
	print("REGION_STATE "+JSON.stringify({"reason":reason,"selected":selected,"zoom":zoom,"pan":[pan.x,pan.y],"size":[size.x,size.y],"markers":markers,"reset":[reset.position.x,reset.position.y,reset.size.x,reset.size.y],"start":[start.position.x,start.position.y,start.size.x,start.size.y],"playable":not start_button.disabled,"panel_visible":panel_visible,"touches":fingers.size(),"ticks_ms":Time.get_ticks_msec()}))

func animate_to(value:float,position_value:Vector2,seconds:float) -> void:
	if motion and motion.is_valid():motion.kill()
	var initial_zoom=zoom;var initial_pan=pan
	motion=create_tween();motion.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion.tween_method(func(t:float):pose(lerpf(initial_zoom,value,t),initial_pan.lerp(position_value,t)),0.0,1.0,seconds)
	motion.tween_callback(func():trace_state("animation_end"))

func select_region(key:String) -> void:
	if not REGIONS.has(key):return
	if motion and motion.is_valid():motion.kill()
	selected=key;selection_count+=1;panel_visible=true;markers.trigger_selection();refresh();app.audio.cue("ui");trace_state("selected")

func restore() -> void:
	cancel_input();animate_to(1.0,camera.overview_pan(),0.5)

func snapshot() -> Dictionary:return {"selected":selected,"zoom":zoom,"center":(size*.5-pan)/(factor*zoom),"panel_visible":panel_visible,"overview":is_equal_approx(zoom,1) and pan.is_equal_approx(camera.overview_pan())}

func cancel_input() -> void:
	fingers.clear();moved=false;multi=false
	if is_instance_valid(ui_root):
		for button in ui_root.find_children("*","Button",true,false):
			if button is DemoButton:button.clear()
	if motion and motion.is_valid():motion.kill()

func ui_hit(at:Vector2) -> bool:
	if app.modal:return true
	if details.visible and details.get_global_rect().has_point(at):return true
	for control in ui_root.find_children("*","Button",true,false):
		if control.is_visible_in_tree() and control.get_global_rect().has_point(at):return true
	return ui_root.get_node("RegionHeading").get_global_rect().grow(12*ui_factor).has_point(at)

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
		var found:=false
		for key in REGIONS:
			if markers.contains(key,at):select_region(key);found=true;break
		if not found:
			panel_visible=false;details.hide()
	for id in fingers:fingers[id].start=fingers[id].at;fingers[id].pan=pan
	if fingers.size()==2:
		var pair=fingers.values()
		pinch_distance=maxf(1,pair[0].at.distance_to(pair[1].at));pinch_zoom=zoom;pinch_anchor=((pair[0].at+pair[1].at)*.5-pan)/(factor*zoom)
	if fingers.is_empty():trace_state("gesture_end")

func _input(event:InputEvent) -> void:
	if app.screen!="region":return
	if event is InputEventMouseButton and event.pressed and event.ctrl_pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and not ui_hit(event.position):
		if motion and motion.is_valid():motion.kill()
		var anchor:Vector2=(event.position-pan)/(factor*zoom)
		var next_zoom:=clampf(zoom*(1.12 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1/1.12),1,2)
		pose(next_zoom,event.position-anchor*factor*next_zoom);get_viewport().set_input_as_handled();trace_state("wheel")
		return
	if event is InputEventScreenTouch:
		if event.pressed:begin_pointer(event.index,event.position)
		else:end_pointer(event.index,event.position)
	elif event is InputEventScreenDrag:move_pointer(event.index,event.position)
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.device!=-1:
		if event.pressed:begin_pointer(-10,event.position)
		else:end_pointer(-10,event.position)
	elif event is InputEventMouseMotion and event.device!=-1:move_pointer(-10,event.position)

