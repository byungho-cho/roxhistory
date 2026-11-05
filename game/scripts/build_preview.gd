class_name BuildPreview
extends Node2D
# Ephemeral placement preview: never participates in physics or saved homes.
var app:Node
var site_id:=-1
var age:=0.0
var ghost:EnvironmentProp
var controls:HBoxContainer
func _init(owner_app:Node)->void:app=owner_app
func _ready()->void:
	ghost=EnvironmentProp.new();ghost.configure("hut",230,Vector2.ZERO);ghost.set_hut_style(1);add_child(ghost)
	ghost.modulate=Color(1,1,.87,.52)
	controls=HBoxContainer.new();controls.name="BuildPreviewControls";controls.add_theme_constant_override("separation",8);app.stage.add_child(controls)
	for entry in [["✕","취소",false],["✓","건설 확인",true]]:
		var b:=Button.new();b.tooltip_text=entry[1];b.custom_minimum_size=Vector2(48,48)
		b.icon=preload("res://assets/ui/v034/build-confirm.png") if entry[2] else preload("res://assets/ui/v034/build-cancel.png")
		var cropped:=AtlasTexture.new();cropped.atlas=b.icon;cropped.region=b.icon.get_image().get_used_rect();b.icon=cropped
		b.expand_icon=true;b.add_theme_constant_override("icon_max_width",58)
		for state in ["normal","hover","pressed"]:b.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		b.pressed.connect(app.confirm_build_preview if entry[2] else app.cancel_build_preview)
		controls.add_child(b)
	hide();controls.hide()
func select(id:int)->void:
	site_id=id;position=DemoConfig.BUILD_SITES[id];age=0;show();controls.show();queue_redraw()
func clear()->void:
	site_id=-1;hide()
	if is_instance_valid(controls):controls.hide()
func _process(delta:float)->void:
	if site_id<0:return
	if not app.application_active or app.modal or app.world_map_open:controls.hide();return
	age+=delta;ghost.position.y=-4-3*sin(age*TAU/2.4)
	var at:=get_global_transform_with_canvas()*Vector2(0,-165)
	controls.position=Vector2(clampf(at.x-48,app.safe.x,app.w-app.safe.x-96),clampf(at.y-44,app.safe.y+110,app.h-app.safe.y-140))
	controls.visible=visible
func _draw()->void:
	if site_id<0:return
	var outline:=VillageLayout.plot_polygon(site_id)
	for i in outline.size():outline[i]-=position
	draw_colored_polygon(outline,Color(.55,.85,.3,.16));outline.append(outline[0]);draw_polyline(outline,Color(.83,.93,.56,.6),2,true)
func _exit_tree()->void:
	if is_instance_valid(controls):controls.queue_free()
