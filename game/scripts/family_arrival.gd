class_name FamilyArrival
extends Node
# Only the committed joined flag is persistent. Interrupted conversations restart.
var app:Node
var bubble:Button
var progress:ProgressBar
var talking:=false
var elapsed:=0.0
const MEETING := Vector2(1540,975)
func _init(owner_app:Node)->void:app=owner_app
func _ready()->void:
	bubble=Button.new();bubble.name="FamilyConversation";bubble.text="우리도 함께 살고 싶어요!";bubble.custom_minimum_size=Vector2(186,44)
	bubble.add_theme_font_size_override("font_size",13)
	var skin:=StyleBoxFlat.new();skin.bg_color=Color("fff0c9");skin.border_color=Color("a68045");skin.set_border_width_all(2);skin.set_corner_radius_all(12)
	for state in ["normal","hover","pressed"]:bubble.add_theme_stylebox_override(state,skin)
	bubble.add_theme_color_override("font_color",Color("50391f"));bubble.pressed.connect(request);app.stage.add_child(bubble)
	progress=ProgressBar.new();progress.show_percentage=false;progress.size=Vector2(170,6);progress.mouse_filter=Control.MOUSE_FILTER_IGNORE;bubble.add_child(progress);progress.position=Vector2(8,36);progress.hide()
func request()->void:
	if talking or app.modal or not app.model.family_available():return
	app.navigation.start("family","first",MEETING)
func begin()->void:
	if not app.model.family_available():return
	talking=true;elapsed=0;app.task="family";app.task_remaining=1.5;app.task_total=1.5
	app.world.player.face_target(Vector2(1590,900));progress.show()
func finish()->void:
	talking=false;progress.hide()
	if app.model.join_family():app.toast("새 가족이 마을에 합류했어요",2.5)
func _process(_delta:float)->void:
	if not is_instance_valid(app.world):return
	bubble.visible=app.model.family_available() and not app.modal and not app.world_map_open
	if not bubble.visible:return
	var at:Vector2=app.world.get_global_transform_with_canvas()*Vector2(1590,795)
	bubble.position=Vector2(clampf(at.x-93,app.safe.x,app.w-app.safe.x-186),clampf(at.y,app.safe.y+120,app.h-app.safe.y-160))
	if talking and app.task!="family":talking=false;progress.hide()
	bubble.text="함께 마을을 가꾸어요…" if talking else "우리도 함께 살고 싶어요!"
	progress.value=100*(1-app.task_remaining/1.5) if talking else 0
func _exit_tree()->void:
	if is_instance_valid(bubble):bubble.queue_free()
