extends SceneTree
var app:Node
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:root.unfocusable=true;call_deferred("run")
func frames(n:int=3)->void:
	for i in n:await process_frame;await physics_frame
func check(ok:bool,title:String)->void:
	checks+=1
	if not ok:failures.append(title);push_error(title)
func mouse(at:Vector2,button:int,down:bool)->void:
	var event:=InputEventMouseButton.new();event.position=at;event.button_index=button;event.pressed=down;root.push_input(event,true)
func motion(at:Vector2)->void:
	var event:=InputEventMouseMotion.new();event.position=at;root.push_input(event,true)
func free_position(kind:String,ignore:String="")->Vector2:
	var rect:Rect2=app.world.playable_rect().grow(-200)
	for y in range(int(rect.position.y),int(rect.end.y),110):
		for x in range(int(rect.position.x),int(rect.end.x),140):
			var p:=Vector2(x,y)
			if app.world.placement_requirement(kind,p,ignore).is_empty():return p
	return Vector2.INF
func capture(file:String)->void:
	if DisplayServer.get_name()=="headless":return
	await frames(5);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/v052-"+file+".png")
func run()->void:
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames()
	app.test_mode=true;app.model=GameState.new(SaveStore.new("user://v052_%d"%Time.get_ticks_usec()));app.model.start_new();app.model.changed.connect(app.update_hud)
	app.model.set_debug_fast_build(false);app.model.debug_unlimited_buildings=false
	var fixture:Dictionary=app.model.state.duplicate(true);fixture.resident_guide_seen=true;app.model.commit(fixture)
	app.enter_game();await frames(8)
	for animal in app.world.animals:animal.set_physics_process(false)
	check(not app.model.debug_unlimited_buildings,"Normal building caps default")
	app.construction_menu();check(app.choosing_plot and app.build_kind=="chief","Fresh HQ dedicated placement entry")
	check(not app.build_side.entries.has("chief"),"HQ absent from normal side menu")
	var at:=free_position("chief");check(at.is_finite(),"Free HQ position")
	app.build_preview.select_position(at,"chief");await frames()
	check(app.build_preview.cost_display.visible and app.build_preview.cost_display.amounts[0].text=="20","Placement has real wood price")
	app.toast_time=0;app.world.player.manual_camera=true;app.world.player.zoom_at(Vector2(app.w,app.h)*.5,.9,at)
	await capture("placement")
	app.confirm_build_preview();await frames()
	var job:Dictionary=app.model.construction_jobs()[0];var uid:=str(job.uid)
	var progress:ConstructionProgress=app.building_workflow.construction_progress[uid]
	var x:=progress.cancel_button.get_global_rect().get_center()
	mouse(x,MOUSE_BUTTON_LEFT,true);mouse(x,MOUSE_BUTTON_LEFT,false);await frames()
	check(app.modal and app.building_workflow.cancellation_confirmation=="build:"+uid,"Actual progress X click opens cancellation")
	app.close_modal();check(app.model.construction_jobs().size()==1,"Dismiss X preserves construction")
	check(app.model.set_debug_fast_build(true),"Tenfold speed enabled during construction")
	check(float(app.model.construction_jobs()[0].clock_duration)==6.0,"Level1 construction full clock becomes6 seconds at tenfold speed")
	app.building_workflow.request_cancel_construction(uid);check(app.building_workflow.confirm_cancel(uid,false),"Confirmed construction cancel")
	check(app.model.state.wood==99999 and app.model.state.stone==99999,"Exact full refund")
	check(not app.model.cancel_construction(uid),"Duplicate refund rejected")
	app.model.set_debug_fast_build(false)
	check(app.model.begin_construction("chief",at),"Rebuild HQ")
	app.model.finish_constructions(Time.get_unix_time_from_system()+61);await frames()
	check(app.model.chief_level()==1,"Completed HQ unlocks huts")
	var state:Dictionary=app.model.state.duplicate(true);state.chief_level=3;app.model.commit(state);await frames()
	var hearth_at:=free_position("hearth");check(app.model.begin_construction("hearth",hearth_at),"First hearth allowed")
	check(not app.model.building_requirement("hearth").is_empty(),"Pending hearth reserves one-only slot")
	app.model.finish_constructions(Time.get_unix_time_from_system()+61);await frames()
	check(not app.model.building_requirement("hearth").is_empty(),"Completed hearth remains unique")
	var shrine_at:=free_position("shrine");check(app.model.begin_construction("shrine",shrine_at),"First shrine allowed")
	check(not app.model.building_requirement("shrine").is_empty(),"Pending shrine reserves one-only slot")
	app.model.finish_constructions(Time.get_unix_time_from_system()+61);await frames()
	app.model.debug_unlimited_buildings=true
	check(app.model.building_requirement("hearth").is_empty() and app.model.building_requirement("shrine").is_empty(),"Test switch bypasses facility count caps")
	var saved:=GameState.new(app.model.store);check(saved.debug_unlimited_buildings,"Count switch persisted")
	app.model.debug_unlimited_buildings=false
	check(not app.model.building_requirement("hearth").is_empty() and app.model.facilities().size()==2,"Switch off restores caps without deleting buildings")
	for tier in range(1,5):
		state=app.model.state.duplicate(true);state.chief_level=tier;app.model.commit(state)
		check(app.model.home_limit()==[1,2,3,3][tier-1],"HQ%d hut cap"%tier)
	state=app.model.state.duplicate(true);state.chief_level=3;app.model.commit(state);await frames()
	# Tier changes now show the reusable growth guide before other modal actions.
	for notice in 3:
		if not app.overlay is CharacterGuide:break
		check(app.overlay.heading.begins_with("촌장집"),"Growth guide owns input before upgrade")
		var dismiss:Vector2=app.overlay.close_button.get_global_rect().get_center()
		mouse(dismiss,MOUSE_BUTTON_LEFT,true);mouse(dismiss,MOUSE_BUTTON_LEFT,false);await frames()
	app.building_workflow.request_upgrade();await frames()
	check(app.overlay.find_child("UpgradeConfirmation",true,false)!=null,"Compact approved upgrade panel")
	await capture("upgrade")
	var confirm:Button=app.overlay.find_child("ConfirmUpgrade",true,false)
	if confirm==null:
		app.queue_free();await frames();quit(1);return
	var price:int=app.model.state.wood
	var click:=confirm.get_global_rect().get_center();mouse(click,MOUSE_BUTTON_LEFT,true);mouse(click,MOUSE_BUTTON_LEFT,false);await frames()
	check(app.model.state.has("chief_upgrade") and app.model.state.wood==price-300,"Actual compact confirm starts upgrade")
	app.model.set_debug_fast_build(true);check(app.model.state.chief_upgrade.clock_duration==1080,"Level4 upgrade full clock becomes1080 seconds at tenfold speed")
	app.building_workflow.request_cancel_upgrade("chief");check(app.building_workflow.confirm_cancel("chief",true),"Upgrade cancel full refund")
	check(app.model.state.wood==price,"Upgrade restores paid price")
	app.model.set_debug_fast_build(false)
	app.show_development_settings();await frames();await capture("settings")
	check(app.overlay.find_child("UnlimitedBuildingsToggle",true,false)!=null,"Separate count switch available")
	check(app.overlay.find_child("ResetProgressButton",true,false)!=null and app.overlay.find_child("FullResetButton",true,false)!=null,"Both reset options in settings")
	app.close_modal()
	var base:Vector2=app.model.building_position("chief")
	check(app.building_menu.hit_key(base+Vector2(0,30))=="chief","Ground footprint selects building")
	var sprite:Sprite2D=app.world.building_sprite("chief")
	check(app.building_menu.show_at(sprite.get_global_transform_with_canvas()*Vector2.ZERO),"Building menu opens for roof")
	await frames()
	var button:DemoButton=app.building_menu.move_button
	var press:=button.get_global_rect().get_center();mouse(press,MOUSE_BUTTON_LEFT,true);mouse(press,MOUSE_BUTTON_LEFT,false);await frames()
	check(app.build_preview.moving_key=="chief","Move menu click starts preview")
	check(app.model.building_position("chief")==base,"Move preview preserves saved position")
	app.cancel_build_preview();await create_timer(.2).timeout
	var hero:Vector2=app.world.player.position
	var center:=Vector2(app.w*.55,app.h*.5)
	mouse(center,MOUSE_BUTTON_MIDDLE,true);motion(center+Vector2(65,10));mouse(center+Vector2(65,10),MOUSE_BUTTON_MIDDLE,false);await frames()
	check(app.world.player.manual_camera and not app.gestures.middle_dragging,"Middle mouse drag pans and releases")
	check(app.world.player.position.distance_to(hero)<2,"Middle drag does not move hero")
	var zoom:float=app.world.player.zoom_factor;mouse(center,MOUSE_BUTTON_WHEEL_UP,true);await frames()
	check(app.world.player.zoom_factor>zoom or is_equal_approx(zoom,DemoPlayer.MAX_ZOOM),"Wheel zoom works without Ctrl")
	var animal:WorldAnimal=app.world.animals[0];var vacant:=free_position("hut");animal.position=vacant;await frames()
	check(app.world.placement_requirement("hut",vacant).is_empty(),"Wildlife collider does not block building")
	app.world.evacuate_animals(vacant,"hut");check(animal.position.distance_to(vacant)>=229.9 and animal.safe_ground(animal.position),"Wildlife relocates to valid ground")
	app.switch_map_scene();await frames(20)
	var map_center:Vector2=app.world_map.center
	mouse(center,MOUSE_BUTTON_MIDDLE,true);motion(center+Vector2(60,0));mouse(center+Vector2(60,0),MOUSE_BUTTON_MIDDLE,false);await frames()
	check(app.world_map.center.distance_to(map_center)>1 and not app.world_map.middle_down,"World map middle drag")
	var map_zoom:float=app.world_map.zoom;mouse(center,MOUSE_BUTTON_WHEEL_UP,true);await frames()
	check(app.world_map.zoom>map_zoom,"World map ordinary wheel zoom")
	app.switch_map_scene();await frames(20)
	app.show_screen("title");await frames();app.pause_game();await frames();check(app.modal,"Settings opens safely from title");app.close_modal()
	app.enter_game();await frames();check(app.model.chief_level()==3 and app.model.facilities().size()==2,"Continue preserves completed state")
	await capture("village")
	var report:={"checks":checks,"failures":failures,"rendered":DisplayServer.get_name()!="headless","device":"Windows automated input; not physical touch or direct listening"}
	FileAccess.open("res://reports/v052-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report))
	app.queue_free();await frames();quit(0 if failures.is_empty() else 1)
