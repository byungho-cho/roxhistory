class_name BuildSideMenu
extends Control
const KINDS:=["hut","outpost","hearth","training","shrine","farm"]
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
		if kind=="farm":
			button.text="농장\n임시 외형";button.set_meta("farm_placeholder",true)
			var image:=TextureRect.new();image.name="IntegratedImage";image.texture=preload("res://assets/placeholders/farm.svg");image.size=Vector2(76,52);image.position=Vector2(8,0);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(image)
			button.enable_art_feedback()
		else:IntegratedMenuArt.install(button,"side-"+kind,Vector2(92,102))
		var locked:=TextureRect.new();locked.name="Locked";locked.texture=IntegratedMenuArt.trimmed(load("res://assets/ui/v0158/lock.png"));locked.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;locked.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;locked.position=Vector2(30,36);locked.size=Vector2(32,34);locked.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.art_feedback.add_child(locked)
		button.enable_art_feedback();entries[kind]=button
	hut=entries.hut;outpost_button=entries.outpost
	refresh()
static func style_label(label:Label)->void:
	label.add_theme_color_override("font_outline_color",Color("231b12"));label.add_theme_constant_override("outline_size",4);label.mouse_filter=Control.MOUSE_FILTER_IGNORE
func refresh()->void:
	var available_width:float=app.w-app.safe.x*2
	var columns:=5 if available_width>=TILE_SIZE.x*5+16 else 3
	size=Vector2(columns*TILE_SIZE.x,ceilf(float(KINDS.size())/columns)*TILE_SIZE.y)
	for i in KINDS.size():
		var kind:String=KINDS[i];var button:DemoButton=entries[kind]
		button.position=Vector2((i%columns)*TILE_SIZE.x,(i/columns)*TILE_SIZE.y)
		button.hint_text=app.building_workflow.build_block_reason(kind)
		button.disabled=not button.hint_text.is_empty()
		button.tooltip_text=button.hint_text if button.disabled else BuildingWorkflow.building_name(kind)
		button.art_feedback.get_node("Locked").visible=button.disabled
		if kind!="farm":IntegratedMenuArt.refresh(button)

	var center:Vector2=app.build_button.get_global_rect().get_center()
	position=Vector2(clampf(center.x-size.x*.5,app.safe.x,maxf(app.safe.x,app.w-app.safe.x-size.x)),maxf(app.safe.y+95,app.build_button.global_position.y-size.y-8))
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
