class_name BuildSideMenu
extends Control
const KINDS:=["outpost","shrine","hearth","training","farm","hut"]
const TILE_SIZE:=Vector2(92,102)
var app:Node
var hut:DemoButton
var outpost_button:DemoButton
var entries:Dictionary={}
func _init(owner_app:Node)->void:app=owner_app
func _ready()->void:
	name="BuildSideMenu";z_index=8;mouse_filter=Control.MOUSE_FILTER_IGNORE;hide()
	for kind in KINDS:
		var button:DemoButton=app.button(self,"",func():select_kind(kind));button.name=kind.capitalize()
		button.custom_minimum_size=TILE_SIZE;button.size=TILE_SIZE
		for state in ["normal","hover","pressed","disabled","focus"]:button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		install_side_art(button,kind)
		button.enable_art_feedback();entries[kind]=button
	hut=entries.hut;outpost_button=entries.outpost
	refresh()
static func style_label(label:Label)->void:
	label.add_theme_color_override("font_outline_color",Color("231b12"));label.add_theme_constant_override("outline_size",4);label.mouse_filter=Control.MOUSE_FILTER_IGNORE
func refresh()->void:
	var available_width:float=app.w-app.safe.x*2
	var factor:=minf(1.0,available_width/(TILE_SIZE.x*6+10*5))
	scale=Vector2.ONE*factor
	size=Vector2(TILE_SIZE.x*6+10*5,TILE_SIZE.y)
	for i in KINDS.size():
		var kind:String=KINDS[i];var button:DemoButton=entries[kind]
		button.position=Vector2(i*(TILE_SIZE.x+10),0)
		button.hint_text=app.building_workflow.build_block_reason(kind)
		button.disabled=not button.hint_text.is_empty()
		button.tooltip_text=button.hint_text if button.disabled else BuildingWorkflow.building_name(kind)
		button.art_feedback.get_node("Composition/Locked").visible=button.disabled
		button.art_feedback.get_node("Composition/Artwork").modulate=Color(1,1,1,.35) if button.disabled else Color.WHITE

	var center:Vector2=app.build_button.get_global_rect().get_center()
	position=Vector2(clampf(center.x-size.x*factor*.5,app.safe.x,maxf(app.safe.x,app.w-app.safe.x-size.x*factor)),maxf(app.safe.y+95,app.build_button.global_position.y-size.y*factor-8))
func _process(_delta:float)->void:
	if not visible:return
	refresh()
	if app.world_map_open or app.modal or not app.application_active:hide()
func select_kind(kind:String)->void:
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
	var image:=TextureRect.new();image.texture=load("res://assets/ui/construction-side-v006/"+file+".png");image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.position=relative.position*dimensions;image.size=relative.size*dimensions;image.mouse_filter=Control.MOUSE_FILTER_IGNORE;clip.add_child(image)
static func install_side_art(button:DemoButton,kind:String)->void:
	var composition:=Control.new();composition.name="Composition";composition.size=Vector2(180,200);composition.scale=TILE_SIZE/Vector2(180,200);composition.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(composition)
	var art:=Control.new();art.name="Artwork";art.mouse_filter=Control.MOUSE_FILTER_IGNORE;composition.add_child(art)
	match kind:
		"outpost":image_slot(art,kind,Vector2(15,33),Vector2(150,150))
		"shrine":image_slot(art,kind,Vector2(28.75,37.5),Vector2(122.5,137.5),Rect2(-.11,-.0567,1.2104,1.0782))
		"hearth":image_slot(art,kind,Vector2(20.12,56.88),Vector2(143.76,102.12),Rect2(-.0531,-.2743,1.1107,1.5636))
		"training":image_slot(art,kind,Vector2(30.18,37.5),Vector2(119.64,137.5),Rect2(-.1084,-.3522,5.2337,1.5178))
		"hut":image_slot(art,kind,Vector2(16.13,48.7),Vector2(143.75,124.301),Rect2(-.25,-.966,6.3882,2.4626))
		"farm":image_slot(art,kind,Vector2(2,22),Vector2(180,150),Rect2(-19.17/180,18.33/150,218.333/180,200.0/150))
	image_slot(art,"brush",Vector2(0,150),Vector2(180,50),Rect2(-2.2/180,-7.68/50,184.068/180,61.356/50))
	var label:=Label.new();label.text={"hut":"움집","farm":"농장","training":"훈련소","hearth":"화덕","shrine":"신당","outpost":"초소"}[kind];label.theme=DemoArt.theme();label.add_theme_font_size_override("font_size",27);label.add_theme_color_override("font_color",Color("fff2cf"));label.position=Vector2(6.666,151.67);label.size=Vector2(166.667,40);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;label.mouse_filter=Control.MOUSE_FILTER_IGNORE;art.add_child(label)
	var locked:=TextureRect.new();locked.name="Locked";locked.texture=IntegratedMenuArt.trimmed(load("res://assets/ui/v0158/lock.png"));locked.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;locked.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;locked.position=Vector2(-2.5,137.5);locked.size=Vector2.ONE*54;locked.modulate.a=.7;locked.mouse_filter=Control.MOUSE_FILTER_IGNORE;composition.add_child(locked)
	button.enable_art_feedback()
