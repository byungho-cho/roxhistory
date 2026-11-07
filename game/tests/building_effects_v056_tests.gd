extends "res://tests/building_hold_v056_tests.gd"
func run()->void:
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames()
	app.test_mode=true;app.model=GameState.new(SaveStore.new("user://effects056_%d"%Time.get_ticks_usec()));app.model.start_new();app.model.changed.connect(app.update_hud)
	var state:Dictionary=app.model.state.duplicate(true);state.chief_level=3;app.model.commit(state)
	app.enter_game();await frames(8)
	app.world.player.manual_camera=true;app.world.player.zoom_at(Vector2(app.w,app.h)*.5,.85,app.model.building_position("chief"));await frames()
	var price:int=app.model.state.wood
	app.building_workflow.request_upgrade();await frames()
	mouse(Vector2(app.w*.75,app.h*.7),MOUSE_BUTTON_LEFT,true);mouse(Vector2(app.w*.75,app.h*.7),MOUSE_BUTTON_LEFT,false);await frames()
	check(not app.modal and not app.model.state.has("chief_upgrade") and app.model.state.wood==price,"Outside click closes upgrade without payment")
	check(app.navigation.path.is_empty(),"Dismissal does not start movement")
	app.show_development_settings();await frames()
	var toggle:Button=app.overlay.find_child("FastBuildToggle",true,false)
	var p:=toggle.get_global_rect().get_center();mouse(p,MOUSE_BUTTON_LEFT,true);mouse(p,MOUSE_BUTTON_LEFT,false);await frames()
	check(app.model.debug_fast_build,"Actual settings click enables speed")
	app.close_modal()
	check(GameState.new(app.model.store).debug_fast_build,"Speed survives reload")
	var at:=free_position("hut");check(app.model.begin_construction("hut",at),"Fast construction begins")
	var job:Dictionary=app.model.construction_jobs()[0];var uid:=str(job.uid)
	check(is_equal_approx(job.clock_duration,6.0),"New construction takes6 real seconds")
	await frames();var progress:ConstructionProgress=app.building_workflow.construction_progress[uid]
	var x:=progress.cancel_button.get_global_rect().get_center()
	# Reproduce later overlapping GUI sibling (render Z alone does not fix picking).
	var blocker:=Control.new();app.stage.add_child(blocker);blocker.position=x-Vector2(30,30);blocker.size=Vector2(60,60);blocker.mouse_filter=Control.MOUSE_FILTER_STOP
	mouse(x,MOUSE_BUTTON_LEFT,true);mouse(x,MOUSE_BUTTON_LEFT,false);await frames()
	check(app.modal,"X receives click despite later GUI overlap")
	app.close_modal();blocker.queue_free();await frames()
	x=progress.cancel_button.get_global_rect().get_center();touch(x,0,true);touch(x,0,false);await frames()
	check(app.modal,"Progress X receives touch")
	app.close_modal()
	await create_timer(6.2).timeout;await frames()
	check(app.model.construction_jobs().is_empty() and app.model.built_count()==1,"Real-time6s completion")
	var key:String=app.model.home_key(0);var tokens:int=app.model.state.tokens
	app.world.player.zoom_at(Vector2(app.w,app.h)*.5,.9,at);await frames()
	var sprite:Sprite2D=app.world.building_sprite(key)
	var point:Vector2=(sprite.get_global_transform_with_canvas()*sprite.get_rect()).get_center()
	app.world_tap(point);await frames()
	check(not app.model.reward_pending(0) and not app.building_menu.visible and app.model.state.tokens>tokens,"Building body claims reward before menu")
	tokens=app.model.state.tokens;app.world_tap(point);await frames();check(app.building_menu.visible and app.model.state.tokens==tokens,"Next click menu, reward paid once")
	app.building_menu.close();app.building_workflow.request_owned_upgrade(key);await frames();check(app.building_workflow.confirm_owned_upgrade(key,2),"Fast upgrade begins")
	check(app.model.lookup_building(key).data.upgrade.clock_duration==60,"L2 upgrade takes60 instead600 seconds")
	app.building_workflow.request_cancel_upgrade(key);check(app.building_workflow.confirm_cancel(key,true),"Upgrade cancellation/refund")
	app.show_demolition_confirmation(key);await frames();var before:int=app.model.state.wood;app.confirm_demolition(key);await frames()
	check(app.model.built_count()==0 and app.world.has_node("DemolitionEffect"),"Demolition commits once and retains animated image")
	var returned:int=app.model.state.wood;app.confirm_demolition(key);check(returned>before and app.model.state.wood==returned,"Demolition cannot refund twice")
	await capture("demolition056");await create_timer(1.55).timeout;await frames();check(not app.world.has_node("DemolitionEffect"),"Demolition image disappears after1.5s")
	app.model.set_debug_fast_build(false)
	for kind in ["hearth","shrine","training"]:
		at=free_position(kind);check(app.model.begin_construction(kind,at),kind+" placement");app.model.finish_constructions(Time.get_unix_time_from_system()+61);await frames()
	state=app.model.state.duplicate(true)
	for entry in state.facilities:entry.level=4
	app.model.commit(state);await frames()
	for entry in app.model.facilities():
		var effect:Node=app.world.get_node("Facility_"+str(entry.uid)).get_node("BuildingLifeEffects")
		check(effect.level==4 and effect.kind==entry.kind,"Effect follows saved stage:"+str(entry.kind))
		app.world.player.zoom_at(Vector2(app.w,app.h)*.5,1.3,app.model.building_position(str(entry.kind)+":"+str(entry.uid)));await frames();await capture("life056-"+str(entry.kind))
	check(GameState.new(app.model.store).facilities().size()==3,"Facility stages persist")
	print(JSON.stringify({"checks":checks,"failures":failures,"rendered":DisplayServer.get_name()!="headless"}))
	app.queue_free();await frames();quit(0 if failures.is_empty() else 1)


