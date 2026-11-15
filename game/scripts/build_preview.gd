class_name BuildPreview
extends Node2D
## Ephemeral free placement/movement. Confirmation alone may mutate the save.
var app:Node
var site_id:=-1
var placement_position:=Vector2.ZERO
var moving_key:=""
var kind:="hut"
var age:=0.0
var ghost:EnvironmentProp
var confirm_button:DemoButton
var cost_display:BuildCostDisplay
var placement_active:=false
var move_dragging := false
var moving_level := 1
func _init(owner_app:Node)->void:app=owner_app
func _ready()->void:
	z_index=3 # Both the destination ghost and source move marker overlay buildings.
	ghost=EnvironmentProp.new();ghost.configure("hut",230,Vector2.ZERO);ghost.set_hut_style(1);add_child(ghost)
	ghost.modulate=Color(1,1,.87,.52)
	cost_display=BuildCostDisplay.new();app.stage.add_child(cost_display);cost_display.z_index=9;cost_display.hide()
	cost_display.confirm_button.pressed.connect(app.confirm_build_preview);cost_display.confirm_button.unavailable.connect(app.toast)
	cost_display.cancel_button.pressed.connect(app.cancel_build_preview)
	hide()
func select(id:int)->void:
	if id<0 or id>=DemoConfig.BUILD_SITES.size():return
	select_position(DemoConfig.BUILD_SITES[id],app.build_kind)
	site_id=id
func select_position(at:Vector2,building_kind:String="",key:String="")->void:
	app.toast_time=0 # Position is now selected; retire the previous placement prompt.
	kind=app.build_kind if building_kind.is_empty() else building_kind
	if moving_key!=key and not key.is_empty():
		moving_level=int(app.model.lookup_building(key).get("data",{}).get("level",1))
	moving_key=key
	confirm_button=cost_display.confirm_button
	ghost.visible=key.is_empty()
	if not key.is_empty():
		placement_position=at;position=at;placement_active=true;show()
		cost_display.hide();queue_redraw()
		return
	var level:=1
	var texture:=BuildingWorkflow.approved_texture(BuildingWorkflow.building_asset_id(kind,level))
	if texture==null:return
	ghost.set_hut_style(1);ghost.sprite.material=null
	BuildingVisuals.apply(ghost.sprite,kind,level,340 if kind=="chief" else 230)
	ghost.sprite.position.y-=ghost.depth_visual.position.y
	site_id=-1;placement_position=at;position=at;age=0;placement_active=true;show();refresh_validity();queue_redraw()
func active()->bool:return placement_active
func block_reason()->String:
	if not placement_active:return "위치를 먼저 선택해 주세요"
	if not moving_key.is_empty() and app.model.lookup_building(moving_key).get("data",{}).has("upgrade"):return "공사 완료 후 이동할 수 있어요"
	var reason:String=app.model.placement_requirement(kind,placement_position,moving_key)
	if reason.is_empty() and app.world.has_method("placement_requirement"):reason=app.world.placement_requirement(kind,placement_position,moving_key)
	if reason.is_empty() and moving_key.is_empty():reason=app.building_workflow.build_block_reason(kind,false)
	return reason
func validity()->bool:return block_reason().is_empty()
func refresh_validity()->void:
	var reason:=block_reason()
	confirm_button.disabled=not reason.is_empty();confirm_button.hint_text=reason
	ghost.modulate=Color(1,1,.87,.85 if not moving_key.is_empty() else .52) if reason.is_empty() else Color(1,.45,.35,.48)
func move_marker_hit(at: Vector2) -> bool:
	return not moving_key.is_empty() and not move_dragging and Geometry2D.is_point_in_polygon(at-position,move_outline())

func move_outline() -> PackedVector2Array:
	var bounds:=VillageLayout.foundation_rect(6 if kind=="chief" else 4)
	var center:=bounds.get_center()
	return PackedVector2Array([Vector2(center.x,bounds.position.y),Vector2(bounds.end.x,center.y),Vector2(center.x,bounds.end.y),Vector2(bounds.position.x,center.y)])

func clear()->void:
	move_dragging=false
	site_id=-1;placement_active=false;moving_key="";hide()
	if is_instance_valid(cost_display):cost_display.hide()
func _process(delta:float)->void:
	if not placement_active or not moving_key.is_empty():return
	if not app.application_active or app.modal or app.world_map_open:cost_display.hide();return
	age+=delta;ghost.position.y=-4-3*sin(age*TAU/2.4)
	refresh_validity()
	update_overlay_layout();queue_redraw()
func update_overlay_layout()->void:
	# Anchor to the rendered building, not a fixed world height or a separate HUD band.
	# At an edge, flip the controls as a group instead of letting them stop following.
	var bounds:Rect2=ghost.sprite.get_global_transform_with_canvas()*BuildingVisuals.visible_rect(ghost.sprite)
	var viewport:=Rect2(app.safe,Vector2(app.w,app.h)-app.safe*2)
	if not visible or not bounds.intersects(viewport):
		cost_display.hide();return
	cost_display.set_world_scale(app.world.get_global_transform_with_canvas().get_scale().x)
	var extent:=cost_display.screen_extent
	var top:=bounds.position.y-extent.y-8
	var below:=top<viewport.position.y
	var y:=bounds.end.y+8 if below else top
	var x:=bounds.get_center().x-extent.x*.5
	var safe_x:=clampf(x,viewport.position.x,maxf(viewport.position.x,viewport.end.x-extent.x))
	cost_display.position=Vector2(move_toward(x,safe_x,60),y)
	cost_display.visible=moving_key.is_empty();cost_display.update_cost(app.model.building_cost(kind,1))

func _draw()->void:
	if not placement_active:return
	var outline:=move_outline()
	var valid := validity()
	var color := Color(.55,.85,.3,.16) if valid else Color(1,.2,.1,.16)
	if valid:
		VillageLayout.draw_move_foundation(self,Vector2.ZERO,kind,1 if moving_key.is_empty() else moving_level)
		color=Color(1,.94,.76,.96)
	else:
		draw_colored_polygon(outline,color)
		color.a=.7
	var width := 1.5/maxf(.25,get_global_transform_with_canvas().get_scale().x)
	for i in outline.size():
		var at := outline[i]
		var next := outline[(i+1)%outline.size()]
		var previous := outline[posmod(i-1,outline.size())]
		draw_polyline(PackedVector2Array([at.lerp(previous,.16),at,at.lerp(next,.16)]),color,width,true)
		draw_line(at.lerp(next,.44),at.lerp(next,.56),color,width,true)
func _exit_tree()->void:
	if is_instance_valid(cost_display):cost_display.queue_free()
