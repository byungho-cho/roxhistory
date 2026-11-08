class_name BuildSideMenu
extends Control
# Logical order is left-to-right; opening starts at the right (움집 first).
const KINDS:=["outpost","shrine","hearth","wood_store","stone_store","training","farm","hut"]
const TILE_SIZE:=Vector2(72,80) # Keep the hit target, shrink only the composition.
const ART_SCALE:=0.60 # Smaller than the main action, including the approved extra 10%.
const MAX_VISIBLE:=6
const GAP:=8.0
const GUTTER:=24.0
const DRAG_THRESHOLD:=10.0
var app:Node
var hut:DemoButton
var outpost_button:DemoButton
var entries:Dictionary={}
var clip:Control
var content:Control
var backdrop:Panel
var left_hint:Label
var right_hint:Label
var scroll_offset:=0.0
var visible_slots:=MAX_VISIBLE
var pointer:=-2
var press_at:=Vector2.ZERO
var last_at:=Vector2.ZERO
var dragged:=false
var pressed_kind:=""
var pressed_arrow:=0
func _init(owner_app:Node)->void:app=owner_app
func _ready()->void:
	name="BuildSideMenu";z_index=32;mouse_filter=Control.MOUSE_FILTER_IGNORE;hide()
	backdrop=Panel.new();backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(backdrop)
	var skin:=StyleBoxFlat.new();skin.bg_color=Color(.10,.08,.05,.72);skin.set_corner_radius_all(18);skin.shadow_size=3;skin.shadow_color=Color(0,0,0,.18);backdrop.add_theme_stylebox_override("panel",skin)
	clip=Control.new();clip.name="VisibleSlots";clip.clip_contents=true;clip.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(clip)
	content=Control.new();content.mouse_filter=Control.MOUSE_FILTER_IGNORE;clip.add_child(content)
	for kind in KINDS:
		var button:DemoButton=app.button(content,"",func():select_kind(kind));button.name=kind.capitalize()
		button.custom_minimum_size=TILE_SIZE;button.size=TILE_SIZE;button.mouse_filter=Control.MOUSE_FILTER_IGNORE
		for state in ["normal","hover","pressed","disabled","focus"]:button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		install_side_art(button,kind)
		button.enable_art_feedback();entries[kind]=button
	hut=entries.hut;outpost_button=entries.outpost
	left_hint=Label.new();left_hint.text="‹";right_hint=Label.new();right_hint.text="›"
	for hint in [left_hint,right_hint]:
		hint.add_theme_font_size_override("font_size",24);hint.add_theme_color_override("font_color",Color("e6d3aa"));hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hint.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;hint.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(hint)
	visibility_changed.connect(_visibility_changed)
	refresh()
func _visibility_changed()->void:
	cancel_pointer()
	if visible:
		refresh();scroll_offset=max_scroll();layout_scroll()
static func style_label(label:Label)->void:
	label.add_theme_color_override("font_outline_color",Color("231b12"));label.add_theme_constant_override("outline_size",4);label.mouse_filter=Control.MOUSE_FILTER_IGNORE
func max_scroll()->float:return maxf(0,content.size.x-clip.size.x)
func refresh()->void:
	var available_width:float=app.w-app.safe.x*2
	visible_slots=clampi(int((available_width-GUTTER*2+GAP)/(TILE_SIZE.x+GAP)),1,MAX_VISIBLE)
	scale=Vector2.ONE
	size=Vector2(visible_slots*(TILE_SIZE.x+GAP)-GAP+GUTTER*2,TILE_SIZE.y)
	backdrop.size=size;clip.position=Vector2(GUTTER,0);clip.size=Vector2(size.x-GUTTER*2,TILE_SIZE.y)
	content.size=Vector2(KINDS.size()*(TILE_SIZE.x+GAP)-GAP,TILE_SIZE.y)
	left_hint.size=Vector2(GUTTER,TILE_SIZE.y);right_hint.size=left_hint.size;right_hint.position=Vector2(size.x-GUTTER,0)
	for i in KINDS.size():
		var kind:String=KINDS[i];var button:DemoButton=entries[kind]
		button.position=Vector2(i*(TILE_SIZE.x+GAP),0)
		button.hint_text=app.building_workflow.build_block_reason(kind)
		button.disabled=not button.hint_text.is_empty()
		button.tooltip_text=button.hint_text if button.disabled else BuildingWorkflow.building_name(kind)
		button.art_feedback.get_node("Composition/Locked").visible=button.disabled
		button.art_feedback.get_node("Composition/Artwork").modulate=Color(1,1,1,.35) if button.disabled else Color.WHITE
	var center:Vector2=app.build_button.get_global_rect().get_center()
	position=Vector2(clampf(center.x-size.x*.5,app.safe.x,maxf(app.safe.x,app.w-app.safe.x-size.x)),maxf(app.safe.y+95,app.build_button.global_position.y-size.y-8))
	layout_scroll()
func layout_scroll()->void:
	scroll_offset=clampf(scroll_offset,0,max_scroll());content.position.x=-scroll_offset
	left_hint.visible=scroll_offset>.5;right_hint.visible=scroll_offset<max_scroll()-.5
func scroll_by(amount:float)->void:
	scroll_offset+=amount;layout_scroll()
func contains_point(at:Vector2)->bool:return is_visible_in_tree() and get_global_rect().has_point(at)
func kind_at(at:Vector2)->String:
	if not clip.get_global_rect().has_point(at):return ""
	for kind in KINDS:
		if entries[kind].get_global_rect().has_point(at):return kind
	return ""
func cancel_pointer()->void:
	for button in entries.values():button.clear()
	pointer=-2;pressed_kind="";pressed_arrow=0;dragged=false
func begin_pointer(at:Vector2,id:int)->void:
	pointer=id;press_at=at;last_at=at;dragged=false;pressed_kind=kind_at(at)
	var x:=at.x-global_position.x
	pressed_arrow=-1 if x<GUTTER else (1 if x>size.x-GUTTER else 0)
	if not pressed_kind.is_empty():
		# DemoButton uses finger for non-toggle touch/managed press animation.
		entries[pressed_kind].finger=0 if not entries[pressed_kind].disabled else -1
func move_pointer(at:Vector2)->void:
	if not dragged and at.distance_to(press_at)>DRAG_THRESHOLD:
		dragged=true
		for button in entries.values():button.clear()
		# Apply the initial travel too, without moving on a jittery tap.
		last_at=press_at
	if dragged:scroll_by(last_at.x-at.x)
	last_at=at
func end_pointer(at:Vector2)->void:
	var kind:=pressed_kind;var arrow:=pressed_arrow
	var activate:=not dragged and press_at.distance_to(at)<=DRAG_THRESHOLD and contains_point(at)
	cancel_pointer()
	if not activate:return
	if arrow!=0:scroll_by(arrow*(TILE_SIZE.x+GAP)*visible_slots)
	elif not kind.is_empty() and kind_at(at)==kind:select_kind(kind)
# Routed before world gestures so a menu drag can never become a world tap/pan.
func handle_input(event:InputEvent)->bool:
	if not is_visible_in_tree():return false
	if event is InputEventMouseButton:
		if event.pressed and contains_point(event.position) and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN,MOUSE_BUTTON_WHEEL_LEFT,MOUSE_BUTTON_WHEEL_RIGHT]:
			scroll_by((TILE_SIZE.x+GAP)*(-1 if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_LEFT] else 1));return true
		if event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed and contains_point(event.position):
				if pointer==-2:begin_pointer(event.position,-1)
				return true
			if not event.pressed and pointer==-1:end_pointer(event.position);return true
	elif event is InputEventMouseMotion and pointer==-1:move_pointer(event.position);return true
	elif event is InputEventScreenTouch:
		if event.pressed and contains_point(event.position):
			if pointer==-2:begin_pointer(event.position,event.index)
			return true
		if not event.pressed and pointer==event.index:end_pointer(event.position);return true
	elif event is InputEventScreenDrag and pointer==event.index:move_pointer(event.position);return true
	return false
func _process(_delta:float)->void:
	if not visible:return
	refresh()
	if app.world_map_open or app.modal or not app.application_active:hide()
func select_kind(kind:String)->void:
	cancel_pointer()
	var reason:String=app.building_workflow.build_block_reason(kind)
	if not reason.is_empty():app.toast(reason);return
	app.cancel_build_preview();app.build_kind=kind
	hide();app.choosing_plot=true;app.world.show_candidates=false;app.world.queue_redraw()
	app.toast("%s을 지을 위치를 눌러 주세요"%BuildingWorkflow.building_name(kind))
func select_hut()->void:select_kind("hut")
func select_outpost()->void:select_kind("outpost")

# Slots from I10000 1295:229. Clip source atlases without modifying approved images.
static func image_slot(parent:Control,file:String,at:Vector2,dimensions:Vector2,relative:Rect2=Rect2(0,0,1,1))->void:
	var clip:=Control.new();clip.position=at;clip.size=dimensions;clip.clip_contents=true;clip.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(clip)
	var image:=TextureRect.new();image.texture=load("res://assets/buildings/storage-v001/"+file+"-l1.png") if file in ["stone_store","wood_store"] else load("res://assets/ui/construction-side-v006/"+file+".png");image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.position=relative.position*dimensions;image.size=relative.size*dimensions;image.mouse_filter=Control.MOUSE_FILTER_IGNORE;clip.add_child(image)
static func install_side_art(button:DemoButton,kind:String)->void:
	for state in ["normal","hover","pressed","disabled","focus"]:button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	var composition:=Control.new();composition.name="Composition";composition.size=Vector2(180,200);composition.scale=TILE_SIZE*ART_SCALE/Vector2(180,200);composition.position=TILE_SIZE*(1.0-ART_SCALE)*.5;composition.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(composition)
	var art:=Control.new();art.name="Artwork";art.mouse_filter=Control.MOUSE_FILTER_IGNORE;composition.add_child(art)
	match kind:
		"stone_store","wood_store":image_slot(art,kind,Vector2(2,47),Vector2(180,135))
		"outpost":image_slot(art,kind,Vector2(15,33),Vector2(150,150))
		"shrine":image_slot(art,kind,Vector2(28.75,37.5),Vector2(122.5,137.5),Rect2(-.11,-.0567,1.2104,1.0782))
		"hearth":image_slot(art,kind,Vector2(20.12,56.88),Vector2(143.76,102.12),Rect2(-.0531,-.2743,1.1107,1.5636))
		"training":image_slot(art,kind,Vector2(30.18,37.5),Vector2(119.64,137.5),Rect2(-.1084,-.3522,5.2337,1.5178))
		"hut":image_slot(art,kind,Vector2(16.13,48.7),Vector2(143.75,124.301),Rect2(-.25,-.966,6.3882,2.4626))
		"farm":image_slot(art,kind,Vector2(2,22),Vector2(180,150),Rect2(-19.17/180,18.33/150,218.333/180,200.0/150))
	image_slot(art,"brush",Vector2(0,150),Vector2(180,50),Rect2(-2.2/180,-7.68/50,184.068/180,61.356/50))
	var label:=Label.new();label.text={"hut":"움집","farm":"농장","training":"훈련소","hearth":"화덕","shrine":"신당","outpost":"초소","stone_store":"석재소","wood_store":"제재소"}[kind];label.theme=DemoArt.theme();label.add_theme_font_size_override("font_size",27);label.add_theme_color_override("font_color",Color("fff2cf"));label.position=Vector2(6.666,151.67);label.size=Vector2(166.667,40);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;label.mouse_filter=Control.MOUSE_FILTER_IGNORE;art.add_child(label)
	var locked:=TextureRect.new();locked.name="Locked";locked.texture=IntegratedMenuArt.trimmed(load("res://assets/ui/v0158/lock.png"));locked.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;locked.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;locked.position=Vector2(-2.5,137.5);locked.size=Vector2.ONE*54;locked.modulate.a=.7;locked.mouse_filter=Control.MOUSE_FILTER_IGNORE;composition.add_child(locked)
	button.enable_art_feedback()
