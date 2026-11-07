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
var placement_active:=false
func _init(owner_app:Node)->void:app=owner_app
func _ready()->void:
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
		if entry[2]:confirm_button=b
	hide();controls.hide()
func select(id:int)->void:
	if id<0 or id>=DemoConfig.BUILD_SITES.size():return
	select_position(DemoConfig.BUILD_SITES[id],app.build_kind)
	site_id=id
func select_position(at:Vector2,building_kind:String="",key:String="")->void:
	kind=app.build_kind if building_kind.is_empty() else building_kind
	moving_key=key
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
	ghost.modulate=Color(1,1,.87,.52) if reason.is_empty() else Color(1,.45,.35,.48)
func clear()->void:
	site_id=-1;placement_active=false;moving_key="";hide()
	if is_instance_valid(controls):controls.hide()
func _process(delta:float)->void:
	if not placement_active:return
	if not app.application_active or app.modal or app.world_map_open:controls.hide();return
	age+=delta;ghost.position.y=-4-3*sin(age*TAU/2.4)
	refresh_validity()
	var at:=get_global_transform_with_canvas()*Vector2(0,-165)
	controls.position=Vector2(clampf(at.x-52,app.safe.x,maxf(app.safe.x,app.w-app.safe.x-104)),clampf(at.y-44,app.safe.y+110,maxf(app.safe.y+110,app.h-app.safe.y-140)))
	controls.visible=visible;queue_redraw()
func _draw()->void:
	if not placement_active:return
	var outline:=EnvironmentProp.hut_footprint(340 if kind=="chief" else 230)
	var color:=Color(.55,.85,.3,.16) if validity() else Color(1,.2,.1,.16)
	draw_colored_polygon(outline,color);outline.append(outline[0]);color.a=.7;draw_polyline(outline,color,2,true)
func _exit_tree()->void:
	if is_instance_valid(controls):controls.queue_free()
