class_name VillageRewardBoard
extends DemoButton
## Temporary board art, with the reward indicator on a separate node.
var app:Node
var marker:Label
var pulse_elapsed:=0.0
var tween:Tween

func _init(owner:Node)->void:
	app=owner
	name="VillageRewardBoard"
	size=Vector2(50,48)
	z_index=20
	focus_mode=Control.FOCUS_NONE
	tooltip_text="마을 보상"

func _ready()->void:
	for state in ["normal","hover","pressed","focus","disabled"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())
	marker=app.label(self,"!",23,Color("ffda65"))
	marker.name="RewardExclamation"
	marker.position=Vector2(17,-19)
	marker.size=Vector2(16,27)
	marker.pivot_offset=marker.size*.5
	marker.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	marker.add_theme_color_override("font_outline_color",Color("53341b"))
	marker.add_theme_constant_override("outline_size",4)
	marker.hide()
	pressed.connect(open_rewards)
	app.model.changed.connect(refresh_reward)
	refresh_reward()

func _draw()->void:
	draw_style_box(stone_style(),Rect2(9,37,32,7))
	draw_rect(Rect2(12,15,5,25),Color("654329"))
	draw_rect(Rect2(33,15,5,25),Color("654329"))
	draw_colored_polygon(PackedVector2Array([Vector2(6,9),Vector2(44,9),Vector2(44,28),Vector2(6,28)]),Color("b9864b"))
	draw_rect(Rect2(6,9,38,19),Color("624124"),false,2)
	draw_line(Vector2(10,19),Vector2(40,19),Color("82532e"),1)

func stone_style()->StyleBoxFlat:
	var stone:=StyleBoxFlat.new()
	stone.bg_color=Color("8d8373")
	stone.set_corner_radius_all(3)
	return stone

func open_rewards()->void:
	if not app.modal and not app.world_map_open and not app.map_transition_active:
		QuestRewards.open(app)

func refresh_reward()->void:
	var pending:=not FirstQuests.pending(app.model.state).is_empty()
	if pending and not marker.visible:
		pulse_elapsed=0
		wiggle()
	elif not pending and tween:
		tween.kill()
		marker.rotation=0
	marker.visible=pending

func wiggle()->void:
	if tween:tween.kill()
	marker.rotation=0
	tween=create_tween()
	for angle in [-.16,.16,-.08,0.0]:
		tween.tween_property(marker,"rotation",angle,.075)

func _process(delta:float)->void:
	visible=app.model.chief_level()>0 and not app.modal and not app.world_map_open and not app.map_transition_active and not app.tutorial.active()
	if not visible or not app.application_active:return
	var world:Node2D=app.world
	var transform_to_screen:=world.get_global_transform_with_canvas()
	var at:Vector2=transform_to_screen*(app.model.building_position("chief")+Vector2(-188,95))
	visible=Rect2(Vector2.ZERO,Vector2(app.w,app.h)).has_point(at)
	if not visible:return
	scale=Vector2.ONE*clampf(transform_to_screen.get_scale().x,.85,1.15)
	position=at-size*scale*Vector2(.5,1)
	if marker.visible:
		pulse_elapsed+=delta
		if pulse_elapsed>=13:
			pulse_elapsed=0
			wiggle()
