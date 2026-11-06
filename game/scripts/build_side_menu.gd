class_name BuildSideMenu
extends Control
var app:Node
var hut:DemoButton
var outpost_button:DemoButton
func _init(owner_app:Node)->void:app=owner_app
func _ready()->void:
	name="BuildSideMenu";z_index=8;mouse_filter=Control.MOUSE_FILTER_IGNORE;size=Vector2(152,80);hide()
	outpost_button=app.button(self,"",select_outpost);outpost_button.name="Outpost"
	IntegratedMenuArt.install(outpost_button,"side-outpost",Vector2(72,80));outpost_button.position=Vector2.ZERO
	hut=app.button(self,"",select_hut);hut.name="Hut"
	IntegratedMenuArt.install(hut,"side-hut",Vector2(72,80));hut.position=Vector2(80,0)
	hut.hint_text="나무 20개와 돌 20개가 필요해요"
func _process(_delta:float)->void:
	if not visible:return
	# Availability is rechecked on selection, confirmation and completion.
	outpost_button.hint_text=app.building_workflow.outpost_block_reason()
	outpost_button.disabled=not outpost_button.hint_text.is_empty()
	var center:Vector2=app.build_button.get_global_rect().get_center()
	position=Vector2(center.x-hut.position.x-hut.size.x*.5,app.build_button.global_position.y-size.y-4)
	hut.disabled=not app.model.can_build()
	IntegratedMenuArt.refresh(hut);IntegratedMenuArt.refresh(outpost_button)
	if app.world_map_open or app.modal:hide()
func select_hut()->void:
	if not app.model.can_build():app.toast(hut.hint_text);return
	app.build_kind="hut"
	hide();app.choosing_plot=true;app.world.show_candidates=true;app.world.queue_redraw()

func select_outpost()->void:
	var reason:String=app.building_workflow.outpost_block_reason()
	if not reason.is_empty():app.toast(reason);return
	app.build_kind="outpost"
	hide();app.choosing_plot=true;app.world.show_candidates=true;app.world.queue_redraw()
