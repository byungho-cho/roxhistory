class_name BuildingUpgradeSigns
extends Control

const ART:=preload("res://assets/ui/village-guidance/RoxHistory_Upgrade_Wooden_Sign_v1.png")
const WORLD_ART:=preload("res://scripts/world_hud_art.gd")
const HIT_SIZE:=Vector2(44,44)
var app:Node
var signs:Dictionary={}
var dirty:=true

func _init(owner:Node)->void:
	app=owner
	name="BuildingUpgradeSigns"
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	z_index=19

func _ready()->void:
	app.model.changed.connect(func():dirty=true)

func refresh()->void:
	dirty=false
	var keys:=OwnedBuildingUpgrades.keys(app.model)
	if app.model.chief_level()>0:keys.append("chief")
	var eligible: Array[String] = []
	for key in keys:
		var reason: String = app.building_workflow.upgrade_block_reason(app.model.chief_level()+1) if key=="chief" else app.building_workflow.owned_upgrade_reason(key)
		if reason.is_empty():eligible.append(key)
	for key in signs.keys():
		if key not in eligible:
			signs[key].hide()
			signs[key].queue_free()
			signs.erase(key)
	for key in eligible:
		if signs.has(key):continue
		var marker := Control.new()
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(marker)
		var world_art := WORLD_ART.new()
		world_art.bind(marker,app.world)
		app.picture(world_art,ART,Rect2(2,2,40,40))
		marker.set_meta("world_art",world_art)
		signs[key] = marker

func hit_key(screen_point: Vector2) -> String:
	if not is_visible_in_tree() or app.choosing_plot:return ""
	var result := ""
	var frontmost := -INF
	for key in signs:
		var marker: Control = signs[key]
		var bounds := marker.get_global_rect()
		if not marker.is_visible_in_tree() or not bounds.has_point(screen_point):continue
		if app.resident_panel.hud_occludes(bounds):continue
		var world_art: Node2D = marker.get_meta("world_art")
		if world_art.position.y > frontmost:
			result = key
			frontmost = world_art.position.y
	return result

func _process(_delta:float)->void:
	visible=app.application_active and not app.world_map_open and not app.map_transition_active and not app.tutorial.active()
	if not visible:return
	if dirty:refresh()
	var screen:=Rect2(Vector2.ZERO,Vector2(app.w,app.h))
	var zoom:float=app.world.player.zoom_factor
	var visual_extent:=40.0*clampf(zoom,.78,1.6)
	var hit_extent:=maxf(HIT_SIZE.x,visual_extent+4.0)
	for key in signs:
		var marker:Control=signs[key]
		var sprite:Sprite2D=app.world.building_sprite(key)
		if not is_instance_valid(sprite) or not sprite.is_visible_in_tree():
			marker.hide()
			continue
		var bounds:=sprite.get_global_transform_with_canvas()*BuildingVisuals.visible_rect(sprite)
		var ground_offset:=132.0 if key=="chief" else 85.0
		if key.begins_with("wood_store:") or key.begins_with("stone_store:"):ground_offset=46.0
		var south:Vector2=app.world.get_global_transform_with_canvas()*(app.model.building_position(key)+Vector2(0,ground_offset))
		var world_art:Node2D=marker.get_meta("world_art")
		var art:TextureRect=world_art.get_child(0)
		art.size=Vector2.ONE*visual_extent
		art.position=Vector2.ONE*(hit_extent-visual_extent)*.5
		marker.size=Vector2.ONE*hit_extent
		marker.position=south-Vector2(hit_extent*.5,hit_extent*.8)
		if app.building_menu.visible and app.building_menu.selected_key==key:
			var menu_action:Rect2=app.building_menu.upgrade_button.get_global_rect()
			if menu_action.has_point(marker.get_global_rect().get_center()):
				marker.position.y=menu_action.position.y-hit_extent-4.0
		var hit_bounds := marker.get_global_rect()
		marker.visible = screen.intersects(bounds) and screen.intersects(hit_bounds)
		# Sort at the ground anchor so the building cannot cover its own sign.
		var sort_anchor := Vector2(marker.position.x,south.y)
		art.position.y += marker.position.y-sort_anchor.y
		world_art.place(app.world,sort_anchor,Vector2.ONE)
