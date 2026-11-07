class_name FamilyArrival
extends Node
# Only the committed joined flag is persistent. Interrupted conversations restart.
var app:Node
var bubble:Button
var progress:ProgressBar
var talking:=false
var elapsed:=0.0
var visit_check_elapsed:=0.0
const MEETING := Vector2(1540,975)
func _init(owner_app:Node)->void:app=owner_app
func _ready()->void:
	bubble=DemoButton.new();bubble.name="FamilyConversation";bubble.text="우리도 함께 살고 싶어요!";bubble.custom_minimum_size=Vector2(166,44)
	bubble.add_theme_font_size_override("font_size",12)
	# The shared button theme has pale hover text for dark buttons, unlike this bubble.
	for state in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color","font_disabled_color"]:
		bubble.add_theme_color_override(state,Color("50391f"))
	var skin:=StyleBoxFlat.new();skin.bg_color=Color("fff0c9");skin.border_color=Color("a68045");skin.set_border_width_all(2);skin.set_corner_radius_all(12)
	for state in ["normal","hover","pressed"]:bubble.add_theme_stylebox_override(state,skin)
	bubble.add_theme_color_override("font_color",Color("50391f"));bubble.pressed.connect(request);app.stage.add_child(bubble)
	progress=ProgressBar.new();progress.show_percentage=false;progress.size=Vector2(150,6);progress.mouse_filter=Control.MOUSE_FILTER_IGNORE;bubble.add_child(progress);progress.position=Vector2(8,36);progress.hide()
func request()->void:
	if talking or app.modal or not app.model.family_available():return
	var needed:int=app.model.family_visitor_count()
	if app.model.resident_capacity()-app.model.resident_count()<needed:
		show_capacity_needed();return
	app.navigation.start("family","first",MEETING)
func begin()->void:
	if not app.model.family_available():return
	if app.model.resident_capacity()-app.model.resident_count()<app.model.family_visitor_count():show_capacity_needed();return
	talking=true;elapsed=0;app.task="family";app.task_remaining=1.5;app.task_total=1.5
	app.world.player.face_target(Vector2(1590,900));progress.show()
func finish()->void:
	talking=false;progress.hide()
	var party:int=app.model.family_visitor_count()
	if app.model.join_family():app.toast("주민 %d명이 마을에 합류했어요"%party,2.5)
	elif app.model.family_available() and app.model.resident_capacity()-app.model.resident_count()<party:show_capacity_needed()
func show_capacity_needed()->void:
	var free:int=maxi(0,app.model.resident_capacity()-app.model.resident_count())
	app.toast("주민 %d명이 기다리고 있어요 · 빈자리 %d명\n주민 움집을 짓거나 업그레이드해 주세요"%[app.model.family_visitor_count(),free],4.0)

func _process(delta:float)->void:
	if not is_instance_valid(app.world):return
	if app.application_active and app.screen=="play":
		visit_check_elapsed+=delta
		if visit_check_elapsed>=1.0:
			visit_check_elapsed=0.0;app.model.ensure_family_visit()
	bubble.visible=app.model.family_available() and not app.modal and not app.world_map_open
	if not bubble.visible:return
	var head:=Vector2(1590,745)
	if not app.world.visitors.is_empty():
		head.x=0;head.y=INF
		for resident in app.world.visitors:
			head.x+=resident.position.x;head.y=minf(head.y,resident.position.y-150)
		head.x/=app.world.visitors.size()
	var at:Vector2=app.world.get_global_transform_with_canvas()*head
	bubble.position=Vector2(clampf(at.x-83,app.safe.x,app.w-app.safe.x-166),clampf(at.y-bubble.size.y-10,app.safe.y+90,app.h-app.safe.y-160))
	if talking and app.task!="family":talking=false;progress.hide()
	var needed:int=app.model.family_visitor_count()
	var free:int=app.model.resident_capacity()-app.model.resident_count()
	bubble.text="함께 마을을 가꾸어요…" if talking else ("주민 %d명 · 움집이 필요해요"%needed if free<needed else "%d명이 함께 살고 싶어요!"%needed)
	progress.value=100*(1-app.task_remaining/1.5) if talking else 0
func _exit_tree()->void:
	if is_instance_valid(bubble):bubble.queue_free()
