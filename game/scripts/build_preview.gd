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
	ghost=EnvironmentProp.new();ghost.configure("hut",340,Vector2.ZERO);ghost.set_hut_style(0);add_child(ghost)
	ghost.modulate=Color(1,1,.87,.52)
	controls=HBoxContainer.new();controls.name="BuildPreviewControls";controls.add_theme_constant_override("separation",8);app.stage.add_child(controls)
	for entry in [["✕","취소",false],["✓","건설 확인",true]]:
		var b:=Button.new();b.text=entry[0];b.tooltip_text=entry[1];b.custom_minimum_size=Vector2(44,44);b.add_theme_font_size_override("font_size",28)
		var skin:=StyleBoxFlat.new();skin.bg_color=Color("f6e9c7");skin.border_color=Color("b59a60");skin.set_border_width_all(2);skin.set_corner_radius_all(22);skin.shadow_color=Color(0,0,0,.24);skin.shadow_size=3
		for state in ["normal","hover","pressed"]:b.add_theme_stylebox_override(state,skin)
		b.add_theme_color_override("font_color",Color("3a9226") if entry[2] else Color("cf4934"))
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
	if not app.application_active or app.modal:controls.hide();return
	age+=delta;ghost.position.y=-4-3*sin(age*TAU/2.4)
	var at:=get_global_transform_with_canvas()*Vector2(0,-235)
	controls.position=Vector2(clampf(at.x-48,app.safe.x,app.w-app.safe.x-96),clampf(at.y-44,app.safe.y+110,app.h-app.safe.y-140))
	controls.visible=visible
func _draw()->void:
	if site_id<0:return
	draw_set_transform(Vector2(0,-22),0,Vector2(1,.36))
	draw_circle(Vector2.ZERO,155,Color(.55,.85,.3,.16))
	draw_arc(Vector2.ZERO,155,0,TAU,64,Color(.83,.93,.56,.6),2,true)
	draw_set_transform(Vector2.ZERO)
func _exit_tree()->void:
	if is_instance_valid(controls):controls.queue_free()
