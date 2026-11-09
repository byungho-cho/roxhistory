extends "res://tests/building_hold_v056_tests.gd"

func marker(key:String)->UnassignedBuildingIndicator:
	var sprite:Sprite2D=app.world.building_sprite(key)
	return sprite.get_parent().get_node_or_null("UnassignedBuildingIndicator") if is_instance_valid(sprite) else null

func snap(label:String)->void:
	if DisplayServer.get_name()=="headless":return
	await frames(3);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/unassigned-"+label+".png")

func run()->void:
	root.size=Vector2i(1280,720)
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames()
	app.model=GameState.new(SaveStore.new("user://tests/unassigned_%d"%Time.get_ticks_usec()));app.model.start_new();app.model.changed.connect(app.update_hud)
	var s:Dictionary=app.model.state.duplicate(true)
	s.chief_level=4;s.resident_count=3;s.resident_roster=["resident-0","resident-1","resident-2"];s.family_joined=true;s.resident_guide_seen=true;s.family_next_at=Time.get_unix_time_from_system()+10000;s.pending_family_count=0
	s.wood=1000;s.stone=1000;s.grain=1000;s.quests_done=FirstQuests.IDS.duplicate();s.quests_claimed=FirstQuests.IDS.duplicate()
	s.homes=[{"uid":"h1","style":1,"claimed":true,"level":4,"position":[800,900],"cost":{"wood":20,"stone":10}}];s.built=true;s.reward_claimed=true
	s.facilities=[{"uid":"f1","kind":"farm","level":1,"position":[1200,1000],"cost":{"wood":10,"stone":5}},{"uid":"f2","kind":"farm","level":2,"position":[1600,1000],"cost":{"wood":10,"stone":5}},{"uid":"ws","kind":"wood_store","level":1,"position":[1200,650],"cost":{"wood":20,"stone":20}},{"uid":"ss","kind":"stone_store","level":1,"position":[1600,650],"cost":{"wood":20,"stone":20}},{"uid":"hearth","kind":"hearth","level":1,"position":[800,650],"cost":{"wood":20,"stone":20}}]
	s.outposts=[{"uid":"p1","level":1,"position":[1950,850],"cost":{"wood":10,"stone":10}}]
	check(app.model.commit(s),"Empty-workplace fixture commits")
	app.enter_game();await frames(12)
	for actor in app.world.residents:actor.set_physics_process(false)
	for animal in app.world.animals:animal.set_physics_process(false)
	app.world.player.set_physics_process(false);app.world.player.manual_camera=true
	app.world.player.zoom_at(Vector2(app.w,app.h)*.5,.8,Vector2(1400,800));await frames()
	var keys:=["farm:f1","farm:f2","wood_store:ws","stone_store:ss","outpost:p1"]
	for key in keys:
		check(is_instance_valid(marker(key)) and marker(key).visible,"Empty workplace has Zzz: "+key)
		check(app.resident_panel.bubbles.has(key),"Zzz uses the same assignable buildings as UI: "+key)
	check(marker("hearth:hearth")==null and marker("h1")==null and marker("chief")==null,"Non-workplace structures have no Zzz")
	var farm:=marker("farm:f1");var identity:=farm.get_instance_id()
	var before_state:Dictionary=app.model.state.duplicate(true)
	var phase:=farm.clock;farm._process(.2)
	check(farm.clock!=phase and app.model.state==before_state,"Animation changes only presentation")
	for index in 3:
		var glyph:=farm.glyph_sample(index)
		check(glyph.alpha>=0 and glyph.alpha<=.9 and glyph.position.y<=0,"Staggered glyph drifts upward with bounded opacity")
	check(farm.glyph_sample(0).position!=farm.glyph_sample(1).position,"Zzz letters do not move in lockstep")
	await snap("empty-workplaces")
	var jobs:=ResidentJobs.new(app.model)
	check(jobs.assign("resident-0","farmer","farm:f1") and not farm.visible,"Assignment immediately removes Zzz")
	check(marker("farm:f2").visible,"One farm assignment does not wake another farm")
	check(jobs.assign("resident-0","farmer","farm:f2") and farm.visible and not marker("farm:f2").visible,"Reassignment swaps the two farm markers")
	check(jobs.assign("resident-0","idle") and marker("farm:f2").visible,"Unassigning immediately restores Zzz")
	check(jobs.assign("resident-0","wood") and not marker("wood_store:ws").visible,"Implicit wood role counts as sawmill assignment")
	check(jobs.assign("resident-1","wood","wood_store:ws"),"Second sawmill worker assigned")
	jobs.assign("resident-0","idle")
	check(not marker("wood_store:ws").visible,"One remaining sawmill worker keeps Zzz hidden")
	jobs.assign("resident-1","idle")
	check(marker("wood_store:ws").visible,"Last sawmill worker removal restores Zzz")
	check(jobs.assign("resident-1","stone","stone_store:ss") and not marker("stone_store:ss").visible,"Quarry assignment removes Zzz")
	check(jobs.assign("resident-2","guard","outpost:p1") and not marker("outpost:p1").visible,"Watchtower assignment removes Zzz")
	s=app.model.state.duplicate(true);s.grain=0;app.model.commit(s)
	check(not marker("stone_store:ss").visible and not marker("outpost:p1").visible,"Assigned but paused workers are not mislabeled unassigned")
	s=app.model.state.duplicate(true);s.grain=1000;app.model.commit(s)
	jobs.assign("resident-1","idle");jobs.assign("resident-2","idle")
	check(OwnedBuildingUpgrades.start(app.model,"farm:f1"),"Farm upgrade starts")
	check(not farm.visible,"Construction presentation takes priority over Zzz")
	check(OwnedBuildingUpgrades.cancel(app.model,"farm:f1") and farm.visible,"Cancelled upgrade restores unassigned marker")
	check(OwnedBuildingUpgrades.start(app.model,"farm:f1"),"Second farm upgrade starts")
	check(OwnedBuildingUpgrades.finish(app.model,Time.get_unix_time_from_system()+10000) and farm.visible,"Completed upgrade restores unassigned marker")
	var sprite:Sprite2D=app.world.building_sprite("farm:f1")
	var bounds:Rect2=sprite.transform*BuildingVisuals.visible_rect(sprite)
	check(farm.position.is_equal_approx(Vector2(bounds.end.x-16,bounds.position.y+14)),"Upgrade recomputes the visible-art roof anchor")
	var local_anchor:=farm.position
	for zoom in [.28,.8,1.4]:
		app.world.player.zoom_at(Vector2(app.w,app.h)*.5,zoom,Vector2(1200,1000));await frames()
		var expected:Vector2=sprite.get_parent().get_global_transform_with_canvas()*local_anchor
		check(farm.get_global_transform_with_canvas().origin.distance_to(expected)<.01 and farm.position==local_anchor,"Zoom retains building-relative anchor: "+str(zoom))
	app.world.player.camera.offset+=Vector2(70,35);app.world.player.camera.force_update_scroll();await frames()
	check(farm.get_global_transform_with_canvas().origin.distance_to(sprite.get_parent().get_global_transform_with_canvas()*local_anchor)<.01,"Camera pan retains anchor")
	app.world.player.zoom_at(Vector2(app.w,app.h)*.5,1.1,Vector2(1200,1000));await frames()
	# Keep the pre-existing assignment entry point clickable, even when Zzz is active.
	var bubble:DemoButton=app.resident_panel.bubbles["farm:f1"]
	check(bubble.visible and app.gestures.ui_hit(bubble.get_global_rect().get_center()),"Assignment bubble still owns its input")
	touch(bubble.get_global_rect().get_center(),0,true);touch(bubble.get_global_rect().get_center(),0,false);await frames()
	check(app.modal and app.overlay.find_child("AssignmentContent",true,false)!=null,"Touch opens existing assignment panel")
	app.close_modal();await frames()
	var building_point:Vector2=(sprite.get_global_transform_with_canvas()*sprite.get_rect()).get_center()
	app.world_tap(building_point);await frames()
	check(app.building_menu.visible and app.building_menu.selected_key=="farm:f1","Building tap still opens the existing building menu")
	await snap("farm-menu");app.building_menu.close()
	app._notification(Node.NOTIFICATION_APPLICATION_PAUSED);await frames()
	phase=farm.clock;await frames(5)
	check(farm.clock==phase,"Application pause freezes Zzz")
	app._notification(Node.NOTIFICATION_APPLICATION_RESUMED);await frames(5)
	check(farm.clock!=phase,"Resume restarts Zzz without duplicate nodes")
	app.world.hide();phase=farm.clock;await frames(5)
	check(farm.clock==phase,"Hidden world does not advance animation")
	app.world.show()
	s=app.model.state.duplicate(true);s.facilities[0].position=[1300,1200];app.model.commit(s)
	check(farm.get_instance_id()==identity and farm.global_position.is_equal_approx(Vector2(1300,1200)+farm.position),"Building relocation reuses and moves the marker")
	for iteration in 5:app.world.refresh()
	check(farm.get_instance_id()==identity and sprite.get_parent().find_children("UnassignedBuildingIndicator","",false,false).size()==1,"Repeated refresh does not duplicate the marker")
	jobs.assign("resident-0","farmer","farm:f1")
	var reloaded:=GameState.new(app.model.store);var restored:=DemoWorld.new(reloaded);root.add_child(restored);await frames()
	check(not restored.building_sprite("farm:f1").get_parent().get_node("UnassignedBuildingIndicator").visible,"Reload preserves assigned-hidden state")
	check(restored.building_sprite("farm:f2").get_parent().get_node("UnassignedBuildingIndicator").visible,"Reload immediately restores empty-building Zzz")
	restored.queue_free();await frames()
	jobs.assign("resident-0","idle")
	app.world.player.zoom_at(Vector2(app.w,app.h)*.5,1.1,Vector2(1300,1200));await frames();await snap("farm-zzz-a")
	await create_timer(.55).timeout;await snap("farm-zzz-b")
	check(app.model.demolish("farm:f1"),"Farm demolition succeeds")
	await frames()
	check(not is_instance_valid(farm) and marker("farm:f1")==null,"Demolition removes the marker with its building")
	print(JSON.stringify({"checks":checks,"failures":failures,"rendered":DisplayServer.get_name()!="headless","touch":"synthetic Windows touch; Android hardware not tested"}))
	app.queue_free();await frames();quit(0 if failures.is_empty() else 1)
