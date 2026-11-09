class_name BuildingUpgradeSigns
extends Control

const ART:=preload("res://assets/ui/village-guidance/RoxHistory_Upgrade_Wooden_Sign_v1.png")
const HIT_SIZE:=Vector2(44,44)
var app:Node
var signs:Dictionary={}
var dirty:=true

func _init(owner:Node)->void:
	app=owner
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	z_index=19

func _ready()->void:
	app.model.changed.connect(func():dirty=true)

func refresh()->void:
	dirty=false
	var keys:=OwnedBuildingUpgrades.keys(app.model)
	if app.model.chief_level()>0:keys.append("chief")
	for key in signs.keys():
		if key not in keys:
			signs[key].queue_free()
			signs.erase(key)
	for key in keys:
		var reason:String=app.building_workflow.upgrade_block_reason(app.model.chief_level()+1) if key=="chief" else app.building_workflow.owned_upgrade_reason(key)
		if not signs.has(key) and reason.is_empty():
			var button:DemoButton=QuestRewards.art_button(app,self,"UpgradeSign",Rect2(Vector2.ZERO,HIT_SIZE),app.building_workflow.request_owned_upgrade.bind(key))
			button.tooltip_text="업그레이드"
			app.picture(button,ART,Rect2(2,2,40,40))
			signs[key]=button
		if signs.has(key):signs[key].disabled=not reason.is_empty()

func _process(_delta:float)->void:
	visible=app.application_active and not app.modal and not app.world_map_open and not app.map_transition_active and not app.choosing_plot and not app.tutorial.active() and not app.building_menu.visible
	if not visible:return
	if dirty:refresh()
	var screen:=Rect2(Vector2.ZERO,Vector2(app.w,app.h))
	for key in signs:
		var button:DemoButton=signs[key]
		var sprite:Sprite2D=app.world.building_sprite(key)
		if button.disabled or not is_instance_valid(sprite) or not sprite.is_visible_in_tree():
			button.hide()
			continue
		var bounds:=sprite.get_global_transform_with_canvas()*BuildingVisuals.visible_rect(sprite)
		button.position=Vector2(bounds.end.x-HIT_SIZE.x*.45,bounds.end.y-HIT_SIZE.y*.8)
		button.visible=screen.intersects(bounds) and screen.encloses(button.get_global_rect()) and not app.resident_panel.hud_occludes(button.get_global_rect())
