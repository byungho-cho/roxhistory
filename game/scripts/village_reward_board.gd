class_name VillageRewardBoard
extends DemoButton
## The board and animated reward bubble use independent artwork.
const EAST_CORNER:=Vector2(212,36)
const WORLD_ART:=preload("res://scripts/world_hud_art.gd")
var art:Node2D
var app:Node
var marker:TextureRect
var pulse_elapsed:=0.0
var tween:Tween

func _init(owner:Node)->void:
	app=owner
	name="VillageRewardBoard"
	size=Vector2(118,120)
	z_index=20
	focus_mode=Control.FOCUS_NONE
	tooltip_text="마을 보상"

func _ready()->void:
	for state in ["normal","hover","pressed","focus","disabled"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())
	art=WORLD_ART.new()
	art.bind(self,app.world)
	app.picture(art,preload("res://assets/ui/village-guidance/noticeboard.png"),Rect2(Vector2.ZERO,size))
	marker=app.picture(art,preload("res://assets/ui/village-guidance/noticeboard-alert.png"),Rect2(33.5,-15,51,51))
	marker.name="RewardExclamation"
	marker.pivot_offset=Vector2(25.5,43.5)
	marker.hide()
	pressed.connect(open_rewards)
	app.model.changed.connect(refresh_reward)
	refresh_reward()

func open_rewards()->void:
	if not app.choosing_plot and not app.modal and not app.world_map_open and not app.map_transition_active:
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
	if app.model.chief_level()<=0 or app.world_map_open or app.map_transition_active or app.tutorial.active():
		hide()
		return
	var input_filter := Control.MOUSE_FILTER_IGNORE if app.choosing_plot or app.modal else Control.MOUSE_FILTER_STOP
	if mouse_filter != input_filter:
		clear()
		mouse_filter = input_filter
	if not app.application_active:return
	var world:Node2D=app.world
	var transform_to_screen:=world.get_global_transform_with_canvas()
	var at:Vector2=transform_to_screen*(app.model.building_position("chief")+EAST_CORNER)
	scale=Vector2.ONE*app.world.player.zoom_factor
	position=at-size*scale*Vector2(.18,1)
	visible=Rect2(Vector2.ZERO,Vector2(app.w,app.h)).intersects(get_global_rect())
	if not visible:return
	art.place(world,position,scale)
	if marker.visible:
		pulse_elapsed+=delta
		if pulse_elapsed>=13:
			pulse_elapsed=0
			wiggle()
