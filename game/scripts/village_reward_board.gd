class_name VillageRewardBoard
extends DemoButton
## The board and animated reward bubble use independent artwork.
var app:Node
var marker:TextureRect
var pulse_elapsed:=0.0
var tween:Tween

func _init(owner:Node)->void:
	app=owner
	name="VillageRewardBoard"
	size=Vector2(75,72)
	z_index=20
	focus_mode=Control.FOCUS_NONE
	tooltip_text="마을 보상"

func _ready()->void:
	for state in ["normal","hover","pressed","focus","disabled"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())
	app.picture(self,preload("res://assets/ui/village-guidance/noticeboard.png"),Rect2(8,12,59,60))
	marker=app.picture(self,preload("res://assets/ui/village-guidance/noticeboard-alert.png"),Rect2(20,-19,34,34))
	marker.name="RewardExclamation"
	marker.pivot_offset=Vector2(17,29)
	marker.hide()
	pressed.connect(open_rewards)
	app.model.changed.connect(refresh_reward)
	refresh_reward()

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
	var at:Vector2=transform_to_screen*(app.model.building_position("chief")+Vector2(0,132))
	visible=Rect2(Vector2.ZERO,Vector2(app.w,app.h)).has_point(at)
	if not visible:return
	scale=Vector2.ONE*clampf(transform_to_screen.get_scale().x,.85,1.15)
	position=at-size*scale*Vector2(.5,1)
	if marker.visible:
		pulse_elapsed+=delta
		if pulse_elapsed>=13:
			pulse_elapsed=0
			wiggle()
