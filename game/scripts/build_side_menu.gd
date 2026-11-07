class_name BuildSideMenu
extends Control
const KINDS:=["chief","hut","outpost","hearth","training","shrine"]
const TILE_SIZE:=Vector2(92,116)
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
		if kind!="chief":
			IntegratedMenuArt.install(button,"side-"+kind,Vector2(92,102))
			button.custom_minimum_size=TILE_SIZE;button.size=TILE_SIZE
		else:
			var base:=TextureRect.new();base.name="Base";base.texture=BuildingMenu.art("button-base.png");base.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;base.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;base.position=Vector2(8,0);base.size=Vector2(76,76);base.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(base)
			var image:=TextureRect.new();image.name="Building";image.texture=DemoArt.facility_icon("chief");image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.position=Vector2(10,4);image.size=Vector2(72,62);image.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(image)
			var title:Label=app.label(button,BuildingWorkflow.building_name(kind),14,Color("fff5d6"));title.name="Title";title.position=Vector2(0,70);title.size=Vector2(92,21);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;style_label(title)
			button.enable_art_feedback()
		var cost:Label=app.label(button.art_feedback,"",11,Color("fff5d6"));cost.name="Cost";cost.position=Vector2(-5,100);cost.size=Vector2(102,18);cost.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;style_label(cost)
		var locked:Label=app.label(button.art_feedback,"잠김",11,Color("fff5d6"));locked.name="Locked";locked.position=Vector2(25,47);locked.size=Vector2(42,20);locked.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;style_label(locked)
		button.enable_art_feedback();entries[kind]=button
	hut=entries.hut;outpost_button=entries.outpost
	refresh()
static func style_label(label:Label)->void:
	label.add_theme_color_override("font_outline_color",Color("231b12"));label.add_theme_constant_override("outline_size",4);label.mouse_filter=Control.MOUSE_FILTER_IGNORE
func refresh()->void:
	var available_width:float=app.w-app.safe.x*2
	var columns:=6 if available_width>=TILE_SIZE.x*6+16 else 3
	size=Vector2(columns*TILE_SIZE.x,ceilf(float(KINDS.size())/columns)*TILE_SIZE.y)
	for i in KINDS.size():
		var kind:String=KINDS[i];var button:DemoButton=entries[kind]
		button.position=Vector2((i%columns)*TILE_SIZE.x,(i/columns)*TILE_SIZE.y)
		button.hint_text=app.building_workflow.build_block_reason(kind)
		button.disabled=not button.hint_text.is_empty()
		button.tooltip_text=button.hint_text if button.disabled else BuildingWorkflow.cost_text(app.model.building_cost(kind,1))
		var cost:Dictionary=app.model.building_cost(kind,1)
		button.art_feedback.get_node("Cost").text="나무 %d · 돌 %d"%[int(cost.get("wood",0)),int(cost.get("stone",0))]
		button.art_feedback.get_node("Locked").visible=button.disabled
		if kind!="chief":IntegratedMenuArt.refresh(button)

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
	hide();app.choosing_plot=true;app.world.show_candidates=true;app.world.queue_redraw()
	app.toast("%s을 지을 위치를 눌러 주세요"%BuildingWorkflow.building_name(kind))
func select_hut()->void:select_kind("hut")
func select_outpost()->void:select_kind("outpost")
