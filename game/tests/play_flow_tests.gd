extends SceneTree
var app:Node
var checks:=0
var failed:Array[String]=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failed.append(message);push_error(message)
func frames(n:int)->void:
	for i in n:await physics_frame;await process_frame
func snap(name:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/flow-"+name+".png")
func wait_work()->void:
	for i in 1800:
		await frames(1)
		if app.navigation.action=="" and app.task=="":return
	check(false,"Automatic work completes within 30 simulation seconds")
func tap(point:Vector2)->void:
	app.world_tap(app.world.get_global_transform_with_canvas()*point)
func run()->void:
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames(3)
	app.show_screen("title");app.toast("소리 켜짐");await frames(3);await snap("title-version-toast")
	app.start_region();app.close_modal();await frames(5)
	check(app.model.built_count()==0,"One existing hut and zero newly built huts")
	check(app.world.homes.filter(func(h):return h.visible).size()==0,"Future huts remain invisible")
	await snap("initial-hud")
	await frames(3);await snap("menu")
	var p:DemoPlayer=app.world.player
	var zoom:=InputEventMouseButton.new();zoom.button_index=MOUSE_BUTTON_WHEEL_UP;zoom.ctrl_pressed=true;zoom.pressed=true;zoom.position=Vector2(500,300)
	app.gestures._input(zoom);check(p.zoom_factor>1,"Ctrl+wheel zooms")
	zoom.button_index=MOUSE_BUTTON_WHEEL_DOWN;app.gestures._input(zoom)
	var size:Vector2=app.joystick.size
	p.zoom_at(Vector2(500,300),2);check(app.joystick.size==size,"Zoom keeps joystick size fixed");p.zoom_at(Vector2(500,300),1)
	tap(Vector2(1620,960));await frames(8)
	check(app.navigation.action=="gather","Resource tap owns automatic route")
	app.joystick.value=Vector2.RIGHT;await frames(3);app.joystick.clear()
	check(app.navigation.action=="" and app.model.state.wood==0,"Manual movement cancels route without credit")
	tap(Vector2(1620,960));await wait_work()
	check(app.model.state.wood==1,"Tap walks and gathers exactly one wood")
	tap(app.world.art_nodes.stone_2.position);await frames(1)
	check(app.navigation.action=="gather","Tapping current stone position starts gather route")
	await wait_work()
	check(app.model.state.stone==1,"Tap walks and gathers exactly one stone")
	app.choosing_plot=true;app.world.show_candidates=true
	tap(app.world.site.position);app.confirm_build_preview();await wait_work()
	check(app.model.built_count()==1 and not app.modal,"Confirmed build completes without completion modal")
	check(app.model.state.tokens==0 and app.model.reward_pending(0),"Building leaves persisted unclaimed reward")
	await snap("reward-ready")
	var saved:=GameState.new(app.model.store);check(saved.reward_pending(0),"Pending reward survives save reload")
	app.claim_home(0);app.claim_home(0)
	check(app.model.state.tokens==10,"Double click pays reward once")
	await frames(18);await snap("seed-flight");await frames(110)
	check(int(app.chrome.displayed_tokens)==10 and app.chrome.slot("tokens").position.y<100,"Animated seed total reaches upper HUD")
	for i in 2:
		app.model.gather("wood_1");app.model.gather("stone_1")
		app.choosing_plot=true;app.world.show_candidates=true
		for site_id in DemoConfig.BUILD_SITES.size():
			if app.world.site_available(site_id):app.world.select_site(site_id);break
		tap(app.world.site.position);app.confirm_build_preview();await wait_work()
		check(app.model.built_count()==i+2,"Next build site supports another home")
		app.claim_home(i+1)
	check(app.model.state.tokens==30 and not app.model.can_build(),"Three rewards, construction goal capped")
	await frames(90);await snap("three-homes")
	var before:Dictionary=app.model.state.duplicate(true)
	app._notification(Node.NOTIFICATION_APPLICATION_PAUSED);await frames(3);app._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(app.task=="" and app.navigation.action=="","Lifecycle clears task and route")
	check(app.model.state.tokens==before.tokens,"Lifecycle cannot duplicate rewards")
	app.show_screen("title");app.new_game_prompt();await frames(2);await snap("reset-options")
	app.full_reset();await frames(3)
	check(app.screen=="onboarding" and app.model.state.is_empty(),"Full reset returns to first launch")
	check(not app.settings.has_section_key("app","welcomed"),"Full reset removes welcome preference")
	check(app.model.store.load_game().is_empty(),"Full reset has no recoverable old save")
	await snap("first-launch")
	var report:Dictionary={"checks":checks,"failed":failed}
	FileAccess.open("res://reports/play-flow-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report));quit(0 if failed.is_empty() else 1)
