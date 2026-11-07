class_name FamilyArrival
extends Node
# Only the committed joined flag is persistent. Interrupted conversations restart.
var app:Node
var bubble:Button
var headline:Label
var progress:ProgressBar
var talking:=false
var elapsed:=0.0
var visit_check_elapsed:=0.0
const MEETING := Vector2(1540,975)
func _init(owner_app:Node)->void:app=owner_app
func _ready()->void:
	bubble=DemoButton.new();bubble.name="FamilyConversation";bubble.text="";bubble.custom_minimum_size=Vector2(270,40);bubble.focus_mode=Control.FOCUS_NONE
	bubble.add_theme_font_size_override("font_size",14)
	# The shared button theme has pale hover text for dark buttons, unlike this bubble.
	for state in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color","font_disabled_color"]:
		bubble.add_theme_color_override(state,Color("49321e"))
	for state in ["normal","hover","pressed","focus"]:bubble.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	bubble.pressed.connect(request);app.stage.add_child(bubble)
	var atlas:=AtlasTexture.new();atlas.atlas=preload("res://assets/ui/v0158/resident-bubble-bg.png");atlas.region=Rect2(211,11,345,105);atlas.filter_clip=true
	var background:TextureRect=app.picture(bubble,atlas,Rect2(0,0,270,40));background.stretch_mode=TextureRect.STRETCH_SCALE
	app.picture(bubble,preload("res://assets/ui/v0158/resident-icon.png"),Rect2(-15,-12,42,42))
	headline=Label.new();headline.theme=DemoArt.theme();headline.position=Vector2(32,8);headline.size=Vector2(230,24);headline.add_theme_font_size_override("font_size",14);headline.add_theme_color_override("font_color",Color("49321e"));headline.mouse_filter=Control.MOUSE_FILTER_IGNORE;bubble.add_child(headline)
	progress=ProgressBar.new();progress.show_percentage=false;progress.size=Vector2(250,3);progress.mouse_filter=Control.MOUSE_FILTER_IGNORE;bubble.add_child(progress);progress.position=Vector2(10,35);progress.hide()
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
	if app.model.family_available() and not app.model.state.get("resident_guide_seen",false) and not app.modal and not app.choosing_plot and not app.world_map_open and app.application_active:
		var next:Dictionary=app.model.state.duplicate(true);next.resident_guide_seen=true
		if app.model.commit(next):app.show_character_guide("새 주민이 찾아왔어요","함께 머물 곳을 찾고 있어요.\n주민을 만나 마을로 맞이해 주세요.")
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
	bubble.position=Vector2(clampf(at.x-135,app.safe.x,app.w-app.safe.x-270),clampf(at.y-bubble.size.y,app.safe.y+90,app.h-app.safe.y-160))
	if talking and app.task!="family":talking=false;progress.hide()
	headline.text="함께 마을을 가꾸어요…" if talking else "함께 머물 곳을 찾고 있어요"
	bubble.set_meta("semantic_text",headline.text)
	progress.value=100*(1-app.task_remaining/1.5) if talking else 0
func _exit_tree()->void:
	if is_instance_valid(bubble):bubble.queue_free()
