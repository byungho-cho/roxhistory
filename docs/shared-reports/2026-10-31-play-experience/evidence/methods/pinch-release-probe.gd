extends SceneTree
var app: Node
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	checks+=1
	if not ok: failures.append(description);push_error(description)
func frames(n: int) -> void:
	for i in n: await physics_frame;await process_frame
func touch(id: int, at: Vector2, down: bool) -> void:
	var e:=InputEventScreenTouch.new();e.index=id;e.position=at;e.pressed=down;root.push_input(e,true)
func drag(id: int, at: Vector2) -> void:
	var e:=InputEventScreenDrag.new();e.index=id;e.position=at;root.push_input(e,true)
func run() -> void:
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await process_frame
	app.settings.set_value("app","character_3d",false)
	app.start_region();app.close_modal();await frames(3)
	check(ProjectSettings.get_setting("input_devices/pointing/android/disable_scroll_deadzone",false),"Android symmetric pinch bypasses the native scroll deadzone")
	check(not ProjectSettings.get_setting("input_devices/pointing/android/enable_pan_and_scale_gestures",false),"Native scale recognizer does not steal raw touch ownership")
	var p: DemoPlayer=app.world.player
	check(p.use_3d and not p.sprite.visible,"Legacy comparison setting cannot show a 2D hero")
	var state: Dictionary=app.model.state.duplicate(true)
	p.set_character_3d(false)
	check(p.use_3d and app.model.state==state,"Legacy renderer request preserves progress and 3D")
	app.pause_game();await frames(1)
	var comparison_found:=false
	for b in app.overlay.find_children("*","Button",true,false):
		if "비교" in b.text: comparison_found=true
	check(not comparison_found,"Pause menu contains no comparison action")
	app.close_modal();await frames(2)
	check(app.world.objectives.targets.size()==2,"Fresh quest marks one wood and one stone area")
	check(app.world.objectives.targets.wood.id=="wood_3","Guidance groups required resources into a short route")
	check(app.chrome.portrait!=null,"HUD portrait uses the new model render")
	var draws: Array[int]=[0]
	app.chrome.draw.connect(func():draws[0]+=1)
	await frames(3)
	var settled_draws:=draws[0]
	await frames(8)
	check(draws[0]==settled_draws,"Idle HUD does not rebuild style boxes and drawing commands every frame")
	app.model.changed.emit();await frames(2)
	check(draws[0]>settled_draws,"Authoritative state changes invalidate the cached HUD")
	check(p.hybrid.viewport.size==Vector2i(384,480),"Base view uses the lower render cost")
	var hero_size: Vector2=p.hybrid.display.get_rect().size*p.hybrid.display.scale
	var ui_rect: Rect2=app.gather_button.get_global_rect()
	p.position=Vector2(1200,900);p.camera.position=Vector2(0,-120);p.camera.reset_smoothing();await frames(4)
	var anchor: Vector2=root.get_canvas_transform().affine_inverse()*Vector2(500,300)
	touch(10,Vector2(420,300),true);touch(11,Vector2(580,300),true)
	check(app.gestures.pinching and app.gestures.blocked,"Two world-owned fingers begin pinch")
	drag(11,Vector2(700,300));await frames(2)
	check(is_equal_approx(p.zoom_factor,1.75),"Pinch distance sets proportional zoom")
	check(p.hybrid.viewport.size==Vector2i(768,960),"Zoom increases actual 3D rendering resolution")
	check((p.hybrid.display.get_rect().size*p.hybrid.display.scale).distance_to(hero_size)<0.01,"Resolution change preserves the world-space character size")
	var projected: Vector2=root.get_canvas_transform()*anchor
	check(projected.distance_to(Vector2(560,300))<2,"Original world anchor follows the finger midpoint")
	check(app.gather_button.get_global_rect()==ui_rect,"Pinch leaves UI size and placement unchanged")
	touch(10,Vector2(420,300),false)
	check(not app.gestures.pinching and app.gestures.blocked,"Remaining finger stays consumed after pinch")
	await frames(2)
	check((root.get_canvas_transform()*anchor).distance_to(Vector2(560,300))<2,"Release preserves the pinch anchor on the first frames")
	drag(11,app.gather_button.get_global_rect().get_center());touch(11,Vector2(700,300),false)
	check(not app.gestures.blocked and app.task=="","Pinch release cannot accidentally gather")
	await frames(30)
	check((root.get_canvas_transform()*anchor).distance_to(Vector2(560,300))<2,"Released camera retains the anchor after smoothing settles")
	var zoom:=p.zoom_factor
	var joy: Vector2=app.joystick.get_global_rect().get_center()
	touch(12,joy+Vector2(35,0),true);touch(13,Vector2(600,300),true)
	check(not app.gestures.pinching,"Joystick-owned touch never becomes pinch")
	drag(13,Vector2(750,300));check(p.zoom_factor==zoom,"World drag alongside joystick does not zoom")
	touch(12,joy,false);touch(13,Vector2(750,300),false)
	touch(14,Vector2(420,300),true);touch(15,Vector2(580,300),true);touch(16,Vector2(650,350),true)
	check(not app.gestures.pinching and app.gestures.blocked,"Third finger safely suspends pinch without passing to UI")
	for id in [14,15,16]: touch(id,Vector2(500,300),false)
	check(app.gestures.touches.is_empty() and not app.gestures.blocked,"All releases clear gesture ownership")
	p.zoom_at(Vector2(500,300),99);check(p.zoom_factor==3,"Maximum zoom is bounded")
	p.zoom_at(Vector2(500,300),0.01);check(p.zoom_factor==1,"Minimum zoom retains original composition")
	check(p.hybrid.viewport.size==Vector2i(384,480),"Returning to base releases the higher render cost")
	for factor in [1.6,1.4,1.2,2.0,1.0]:
		p.zoom_at(Vector2(500,300),factor)
		await RenderingServer.frame_post_draw
		var nonempty:=p.hybrid.viewport.get_texture().get_image().get_used_rect().has_area()
		var ground: Vector2=p.hybrid.display.position+p.hybrid.camera.unproject_position(Vector3.ZERO)*p.hybrid.display.scale
		check(nonempty and ground.length()<0.01,"First rendered frame after resolution transition retains the hero and foot anchor at "+str(factor))
	for factor in [1.0,3.0]:
		p.zoom_at(Vector2(0,0),factor)
		await frames(2)
		var inv:=root.get_canvas_transform().affine_inverse()
		var first: Vector2=inv*Vector2.ZERO;var last: Vector2=inv*root.get_visible_rect().size
		check(first.x>=-1 and first.y>=-1 and last.x<=2401 and last.y<=1351,"Camera exposes no empty map margin at zoom "+str(factor))
	touch(20,Vector2(420,300),true);touch(21,Vector2(580,300),true)
	app._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
	check(app.gestures.touches.is_empty() and not app.gestures.blocked and app.joystick.finger==-1,"Pause clears pinch and joystick ownership")
	app._notification(MainLoop.NOTIFICATION_APPLICATION_RESUMED)
	check(app.application_active and p.direction==Vector2.ZERO,"Resume has no retained movement")
	p.position=Vector2(1360,830);p.zoom_factor=1;p.fit_camera();await frames(4)
	app.gather_action();await frames(76)
	check(app.model.state.wood==1,"One completed 1.2-second gather awards exactly one wood")
	check(app.chrome.flights.size()==1 and app.chrome.flights[0].kind=="wood","Successful gather sends the matching icon toward the resource slot")
	check(not app.world.objectives.targets.has("wood"),"Satisfied wood objective removes its area marker")
	check(app.world.feedback.notices.is_empty(),"Gather result uses an icon instead of repetitive +1 text")
	app.chrome.clear_effects();app.finish_task()
	check(app.model.state.wood==1 and app.chrome.flights.is_empty(),"Interrupted visual and duplicate completion never duplicate or lose inventory")
	p.position=Vector2(1400,1070);await frames(4);app.gather_action();await frames(8)
	touch(25,Vector2(420,300),true);touch(26,Vector2(580,300),true)
	check(app.task=="","Beginning pinch cancels an active gather")
	touch(25,Vector2(420,300),false);touch(26,Vector2(580,300),false);await frames(3)
	check(app.model.state.stone==0 and app.chrome.flights.is_empty(),"Cancelled gathering has no grant or acquisition flight")
	app.gather_action();await frames(76)
	check(app.model.state.stone==1 and app.world.objectives.targets.is_empty(),"One stone gather completes the material objective")
	await frames(55)
	check(app.chrome.flights.is_empty(),"Acquisition flight completes without retaining visual objects")
	var saved: Dictionary=app.model.state.duplicate(true)
	check(app.model.store.load_game().wood==saved.wood,"Authoritative wood amount is persisted independently of animation")
	var report: Dictionary={"checks":checks,"failed":failures,"utc":Time.get_datetime_string_from_system(true),"runtime":"Native Godot synthetic multi-touch; Android is tested separately"}
	FileAccess.open("res://reports/pinch-release-probe.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
