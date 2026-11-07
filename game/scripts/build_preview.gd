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
var controls:HBoxContainer
var confirm_button:DemoButton
var move_confirm_button:DemoButton
var cost_display:BuildCostDisplay
var placement_active:=false
var source_sprite:Sprite2D
var source_color:=Color.WHITE
func _init(owner_app:Node)->void:app=owner_app
func _ready()->void:
	z_index=3 # Both the destination ghost and source move marker overlay buildings.
	ghost=EnvironmentProp.new();ghost.configure("hut",230,Vector2.ZERO);ghost.set_hut_style(1);add_child(ghost)
	ghost.modulate=Color(1,1,.87,.52)
	controls=HBoxContainer.new();controls.name="BuildPreviewControls";controls.add_theme_constant_override("separation",8);app.stage.add_child(controls)
	for entry in [["✕","취소",false],["✓","건설 확인",true]]:
		var b:=DemoButton.new();b.custom_minimum_size=Vector2(48,48);b.focus_mode=Control.FOCUS_NONE;b.name="Confirm" if entry[2] else "Cancel"
		b.icon=preload("res://assets/ui/v034/build-confirm.png") if entry[2] else preload("res://assets/ui/v034/build-cancel.png")
		var cropped:=AtlasTexture.new();cropped.atlas=b.icon;cropped.region=b.icon.get_image().get_used_rect();b.icon=cropped
		b.expand_icon=true;b.add_theme_constant_override("icon_max_width",58)
		for state in ["normal","hover","pressed","focus","disabled"]:b.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		b.pressed.connect(app.confirm_build_preview if entry[2] else app.cancel_build_preview);b.unavailable.connect(app.toast)
		controls.add_child(b)
		if entry[2]:move_confirm_button=b;confirm_button=b
	cost_display=BuildCostDisplay.new();app.stage.add_child(cost_display);cost_display.z_index=9;cost_display.hide()
	cost_display.confirm_button.pressed.connect(app.confirm_build_preview);cost_display.confirm_button.unavailable.connect(app.toast)
	hide();controls.hide()
func select(id:int)->void:
	if id<0 or id>=DemoConfig.BUILD_SITES.size():return
	select_position(DemoConfig.BUILD_SITES[id],app.build_kind)
	site_id=id
func select_position(at:Vector2,building_kind:String="",key:String="")->void:
	app.toast_time=0 # Position is now selected; retire the previous placement prompt.
	kind=app.build_kind if building_kind.is_empty() else building_kind
	if moving_key!=key:restore_source()
	moving_key=key
	confirm_button=cost_display.confirm_button if key.is_empty() else move_confirm_button
	if not key.is_empty() and not is_instance_valid(source_sprite):
		source_sprite=app.world.building_sprite(key)
		if is_instance_valid(source_sprite):
			source_color=source_sprite.self_modulate
			source_sprite.self_modulate=Color(.85,.85,.85,.85)
	var level:=1
	if not key.is_empty():level=int(app.model.lookup_building(key).get("data",{}).get("level",1))
	var texture:=BuildingWorkflow.approved_texture(BuildingWorkflow.building_asset_id(kind,level))
	if texture==null:return
	ghost.set_hut_style(1);ghost.sprite.material=null
	BuildingVisuals.apply(ghost.sprite,kind,level,340 if kind=="chief" else 230)
	ghost.sprite.position.y-=ghost.depth_visual.position.y
	site_id=-1;placement_position=at;position=at;age=0;placement_active=true;show();controls.show();refresh_validity();queue_redraw()
func active()->bool:return placement_active
func block_reason()->String:
	if not placement_active:return "위치를 먼저 선택해 주세요"
	if not moving_key.is_empty() and app.model.lookup_building(moving_key).get("data",{}).has("upgrade"):return "공사 완료 후 이동할 수 있어요"
	var reason:String=app.model.placement_requirement(kind,placement_position,moving_key)
	if reason.is_empty() and app.world.has_method("placement_requirement"):reason=app.world.placement_requirement(kind,placement_position,moving_key)
	return reason
func validity()->bool:return block_reason().is_empty()
func refresh_validity()->void:
	var reason:=block_reason()
	confirm_button.disabled=not reason.is_empty();confirm_button.hint_text=reason
	ghost.modulate=Color(1,1,.87,.85 if not moving_key.is_empty() else .52) if reason.is_empty() else Color(1,.45,.35,.48)
func restore_source()->void:
	if is_instance_valid(source_sprite):source_sprite.self_modulate=source_color
	source_sprite=null
func clear()->void:
	restore_source()
	site_id=-1;placement_active=false;moving_key="";hide()
	if is_instance_valid(controls):controls.hide()
	if is_instance_valid(cost_display):cost_display.hide()
func _process(delta:float)->void:
	if not placement_active:return
	if not app.application_active or app.modal or app.world_map_open:controls.hide();cost_display.hide();return
	age+=delta;ghost.position.y=-4-3*sin(age*TAU/2.4)
	refresh_validity()
	update_overlay_layout();queue_redraw()
func update_overlay_layout()->void:
	# Anchor to the rendered building, not a fixed world height or a separate HUD band.
	# At an edge, flip the controls as a group instead of letting them stop following.
	var bounds:Rect2=ghost.sprite.get_global_transform_with_canvas()*ghost.sprite.get_rect()
	var viewport:=Rect2(app.safe,Vector2(app.w,app.h)-app.safe*2)
	if not visible or not bounds.intersects(viewport):
		controls.hide();cost_display.hide();return
	var factor:=minf(1.0,viewport.size.x/380.0)
	cost_display.scale=Vector2.ONE*factor
	var extent:=Vector2(380,65)*factor if moving_key.is_empty() else controls.get_combined_minimum_size().max(Vector2(104,48))
	var top:=bounds.position.y-extent.y-8
	var below:=top<viewport.position.y
	var y:=bounds.end.y+8 if below else top
	# If both sides are outside the viewport, stay on the visible building edge.
	y=clampf(y,viewport.position.y,maxf(viewport.position.y,viewport.end.y-extent.y))
	controls.position=Vector2(clampf(bounds.get_center().x-extent.x*.5,viewport.position.x,maxf(viewport.position.x,viewport.end.x-extent.x)),y)
	controls.visible=not moving_key.is_empty()
	cost_display.position=controls.position
	cost_display.visible=moving_key.is_empty();cost_display.update_cost(app.model.building_cost(kind,1))

func _draw()->void:
	if not placement_active:return
	if not moving_key.is_empty():
		var at:Vector2=app.model.building_position(moving_key)-position+Vector2(0,-65)
		draw_circle(at,14,Color(.18,.14,.08,.65))
		var gold:=Color(1,.84,.4,.9)
		draw_line(at+Vector2(-9,0),at+Vector2(9,0),gold,2,true)
		for side in [-1,1]:
			draw_polyline(PackedVector2Array([at+Vector2(side*4,-5),at+Vector2(side*9,0),at+Vector2(side*4,5)]),gold,2,true)
	var outline:=EnvironmentProp.hut_footprint(340 if kind=="chief" else 230)
	var color:=Color(.55,.85,.3,.16) if validity() else Color(1,.2,.1,.16)
	draw_colored_polygon(outline,color);outline.append(outline[0]);color.a=.7;draw_polyline(outline,color,2,true)
func _exit_tree()->void:
	restore_source()
	if is_instance_valid(controls):controls.queue_free()
	if is_instance_valid(cost_display):cost_display.queue_free()
