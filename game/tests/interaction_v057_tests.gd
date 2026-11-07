extends "res://tests/building_hold_v056_tests.gd"
func destination_near(from:Vector2,distance:float)->Vector2:
	for i in 24:
		var candidate:=from+Vector2.from_angle(TAU*i/24.0)*distance
		var pose:Transform2D=app.world.player.global_transform;pose.origin=candidate
		if app.world.playable_rect().grow(-30).has_point(candidate) and VillageLayout.ground_ok(candidate) and not app.world.player.test_move(pose,Vector2.ZERO,null,.08,true) and not app.navigation.plan_route(candidate,[]).is_empty():return candidate
	return Vector2.INF
func run()->void:
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames()
	app.test_mode=true;app.model=GameState.new(SaveStore.new("user://v057_%d"%Time.get_ticks_usec()));app.model.start_new();app.model.changed.connect(app.update_hud)
	var state:Dictionary=app.model.state.duplicate(true);state.chief_level=4;app.model.commit(state)
	app.enter_game();await frames(8)
	var target:=destination_near(app.world.player.position,500)
	check(target.is_finite() and app.navigation.start("move","",target),"Start long auto route")
	for i in 5:
		await frames(2)
		target=destination_near(app.world.player.position,300+i*10)
		check(target.is_finite() and app.navigation.start("move","",target),"Retarget during movement %d"%i)
	target=destination_near(app.world.player.position,500);app.navigation.start("move","",target);await frames()
	var tap_goal:=destination_near(app.world.player.position,90)
	var tap_screen:Vector2=app.world.get_global_transform_with_canvas()*tap_goal
	mouse(tap_screen,MOUSE_BUTTON_LEFT,true);mouse(tap_screen,MOUSE_BUTTON_LEFT,false)
	check(not app.navigation.path.is_empty() and app.navigation.path[-1].distance_to(tap_goal)<.1,"Actual ground click retargets while walking")
	target=destination_near(app.world.player.position,500);app.navigation.start("move","",target);await frames()
	var before:Vector2=app.world.player.position
	var center:=Vector2(app.w*.5,app.h*.5)
	touch(center-Vector2(45,0),0,true);touch(center+Vector2(45,0),1,true)
	drag_touch(center+Vector2(70,0),1);await create_timer(.15).timeout;await frames()
	check(app.gestures.pinching and app.navigation.action=="move","Pinch keeps auto action")
	check(app.world.player.position.distance_to(before)>5,"Hero actually keeps walking during pinch")
	check(not app.navigation.path.is_empty() and app.navigation.path[-1].distance_to(target)<.1,"Pinch keeps destination")
	touch(center-Vector2(45,0),0,false);touch(center+Vector2(70,0),1,false);await frames()
	check(not app.gestures.blocked and app.navigation.action=="move","Pinch release creates no accidental command")
	var accepted:Vector2=app.navigation.path[-1]
	check(not app.navigation.start("move","",Vector2(-9000,-9000),0,[],true) and app.navigation.path[-1]==accepted,"Rejected impossible destination preserves route")
	app.navigation.cancel()
	app.start_building_move("chief");await frames()
	var source:Sprite2D=app.world.building_sprite("chief")
	check(is_equal_approx(source.self_modulate.a,.85),"Source visibly dimmed85 percent")
	app.cancel_build_preview();check(source.self_modulate==Color.WHITE,"Cancel restores source")
	app.start_building_move("chief");var old:Vector2=app.model.building_position("chief");var at:=free_position("chief","chief")
	app.build_preview.select_position(at,"chief","chief");await frames()
	var wood:int=app.model.state.wood;var stone:int=app.model.state.stone
	app.confirm_build_preview();await frames()
	check(app.relocating_key=="chief" and app.model.building_position("chief")==at,"Move saved once and visual transition active")
	check(app.model.state.wood==wood and app.model.state.stone==stone,"Relocation has no cost or refund")
	check(app.world.building_sprite("chief").self_modulate.a==0,"Destination hidden during departure")
	await create_timer(1.65).timeout;await frames()
	check(app.world.building_sprite("chief").self_modulate.a>0 and app.world.building_sprite("chief").self_modulate.a<1,"Destination rebuilding phase visible")
	await create_timer(1.5).timeout;await frames()
	check(app.relocating_key.is_empty() and app.world.building_sprite("chief").self_modulate==Color.WHITE,"Relocation completes and restores appearance")
	check(GameState.new(app.model.store).building_position("chief")==at,"Relocation survives reload")
	app.model.set_debug_fast_build(true)
	for kind in BuildingRules.KINDS:
		for level in 4:check(BuildingRules.new_job(kind,level,100,true).clock_duration==5,"Fixed5 %s level%d"%[kind,level+1])
	check(app.model.building_duration(4)==5,"Displayed duration is5 at highest tier")
	var legacy:Dictionary=app.model.state.duplicate(true);legacy.erase("fast_build_mode");app.model.commit(legacy)
	var reload:=GameState.new(app.model.store);check(reload.debug_fast_build and reload.state.get("fast_build_mode")=="fixed5","Old ON setting migrates without resetting save")
	print(JSON.stringify({"checks":checks,"failures":failures,"touch":"synthetic","rendered":DisplayServer.get_name()!="headless"}))
	app.queue_free();await frames();quit(0 if failures.is_empty() else 1)
