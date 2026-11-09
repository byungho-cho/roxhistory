class_name FamilyArrival
extends Node
# Only the committed joined flag is persistent. Interrupted conversations restart.
var app:Node
var bubble:Button
var headline:Label
var background:TextureRect
var portrait:TextureRect
const PORTRAIT_REGION:=Rect2(143,52,961,1165)
const BUBBLE_FRONT:=11.0
const ORIGINAL_HEIGHT:=44.0
const BUBBLE_HEIGHT:=ORIGINAL_HEIGHT*1.2
var progress:ProgressBar
var talking:=false
var elapsed:=0.0
var visit_check_elapsed:=0.0
const MEETING := Vector2(1540,975)
func _init(owner_app:Node)->void:app=owner_app
func _ready()->void:
	bubble=DemoButton.new();bubble.name="FamilyConversation";bubble.z_index=22;bubble.text="";bubble.custom_minimum_size=Vector2(0,44);bubble.focus_mode=Control.FOCUS_NONE
	bubble.add_theme_font_size_override("font_size",14)
	# The shared button theme has pale hover text for dark buttons, unlike this bubble.
	for state in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color","font_disabled_color"]:
		bubble.add_theme_color_override(state,Color("49321e"))
	for state in ["normal","hover","pressed","focus"]:bubble.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	bubble.pressed.connect(request);app.stage.add_child(bubble)
	var atlas:=AtlasTexture.new();atlas.atlas=preload("res://assets/ui/v0158/resident-bubble-bg.png");atlas.region=Rect2(211,11,345,105);atlas.filter_clip=true
	background=app.picture(bubble,atlas,Rect2(0,0,270,44));background.stretch_mode=TextureRect.STRETCH_SCALE
	var icon:=AtlasTexture.new();icon.atlas=PlayChrome.RESIDENT_ICON;icon.region=PORTRAIT_REGION;icon.filter_clip=true
	portrait=app.picture(bubble,icon,Rect2(-4,-20,44,60));portrait.name="ResidentPortrait"
	headline=Label.new();headline.theme=DemoArt.theme();headline.position=Vector2(50,0);headline.size=Vector2(210,BUBBLE_HEIGHT);headline.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;headline.add_theme_font_size_override("font_size",14);headline.add_theme_color_override("font_color",Color("49321e"));headline.mouse_filter=Control.MOUSE_FILTER_IGNORE;bubble.add_child(headline)
	progress=ProgressBar.new();progress.show_percentage=false;progress.size=Vector2(250,3);progress.mouse_filter=Control.MOUSE_FILTER_IGNORE;bubble.add_child(progress);progress.position=Vector2(10,BUBBLE_HEIGHT-4);progress.hide()
func request()->void:
	if talking or app.modal or app.world_map_open or not app.application_active or not app.model.family_available():return
	var needed:int=app.model.family_visitor_count()
	if app.model.resident_capacity()-app.model.resident_count()<needed:
		show_capacity_needed();return
	finish()
func begin()->void:
	if not app.model.family_available():return
	if app.model.resident_capacity()-app.model.resident_count()<app.model.family_visitor_count():show_capacity_needed();return
	talking=true;elapsed=0;app.task="family";app.task_remaining=1.5;app.task_total=1.5
	app.world.player.face_target(Vector2(1590,900));progress.show()
func finish()->void:
	talking=false;progress.hide()
	var party:int=app.model.family_visitor_count()
	app.world.animating_family_join=true
	var joined:bool=app.model.join_family()
	app.world.animating_family_join=false
	if joined:app.show_character_guide("주민 %d명이 합류했어요"%party,"새 주민이 마을에 자리를 잡았어요.")
	elif app.model.family_available() and app.model.resident_capacity()-app.model.resident_count()<party:show_capacity_needed()
func show_capacity_needed()->void:
	var free:int=maxi(0,app.model.resident_capacity()-app.model.resident_count())
	app.show_character_guide("주민 %d명이 기다리고 있어요"%app.model.family_visitor_count(),"빈자리 %d명 · 주민 움집을 짓거나 업그레이드해 주세요."%free)

func _process(delta:float)->void:
	if not is_instance_valid(app.world):return
	if app.model.family_available() and not app.model.state.get("resident_guide_seen",false) and not app.modal and not app.choosing_plot and not app.world_map_open and app.application_active:
		var next:Dictionary=app.model.state.duplicate(true);next.resident_guide_seen=true
		if app.model.commit(next):app.show_character_guide("새 주민이 찾아왔어요","함께 머물 곳을 찾고 있어요.\n주민이나 말풍선을 눌러 마을로 맞이해 주세요.")
	if app.application_active and app.screen=="play":
		visit_check_elapsed+=delta
		if visit_check_elapsed>=1.0:
			visit_check_elapsed=0.0;app.model.ensure_family_visit()
	bubble.visible=app.model.family_available() and not app.modal and not app.world_map_open
	if not bubble.visible:return
	headline.text="함께 마을을 가꾸어요…" if talking else "함께 머물 곳을 찾고 있어요"
	var width:float=headline.get_theme_font("font").get_string_size(headline.text,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x+60
	bubble.size=Vector2(minf(width,app.w-app.safe.x*2),BUBBLE_HEIGHT);background.position.x=BUBBLE_FRONT;background.size=Vector2(bubble.size.x-background.position.x,bubble.size.y)
	headline.size.x=bubble.size.x-60;progress.size.x=bubble.size.x-20
	var viewport:=Rect2(0,0,app.w,app.h).grow(4)
	var party_bounds:=Rect2()
	var transform_to_screen:Transform2D=app.world.get_global_transform_with_canvas()
	for resident in app.world.visitors:
		var bounds:Rect2=transform_to_screen*app.world.visitor_bounds(resident)
		if not viewport.intersects(bounds):continue
		party_bounds=party_bounds.merge(bounds) if party_bounds.has_area() else bounds
	var anchor:=Vector2(party_bounds.get_center().x,party_bounds.position.y)
	bubble.position=anchor-Vector2(bubble.size.x*.5,ORIGINAL_HEIGHT+5)
	bubble.visible=party_bounds.has_area() and viewport.intersects(bubble.get_global_rect())
	if talking and app.task!="family":talking=false;progress.hide()
	bubble.set_meta("semantic_text",headline.text)
	progress.value=100*(1-app.task_remaining/1.5) if talking else 0
func _exit_tree()->void:
	if is_instance_valid(bubble):bubble.queue_free()
