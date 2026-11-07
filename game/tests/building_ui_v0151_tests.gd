extends SceneTree
var checks:=0
var failures:Array[String]=[]
var app:Node
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures.append(message);push_error(message)
func _initialize()->void:call_deferred("run")
func frames(count:int=3)->void:
	for i in count:await process_frame;await physics_frame
func place(kind:String,ignore_key:String="")->Vector2:
	for y in range(440,1240,90):
		for x in range(640,1940,120):
			var at:=Vector2(x,y)
			if app.model.placement_requirement(kind,at,ignore_key).is_empty() and app.world.placement_requirement(kind,at,ignore_key).is_empty():return at
	return Vector2.INF
func complete(kind:String)->String:
	var at:=place(kind)
	check(at.is_finite(),"Free valid position exists: "+kind)
	check(app.model.begin_construction(kind,at),"Start durable "+kind)
	var jobs:Array=app.model.construction_jobs()
	if jobs.is_empty():return ""
	var uid:=str(jobs.back().uid)
	check(app.model.finish_constructions(Time.get_unix_time_from_system()+61),"Finish "+kind)
	return "chief" if kind=="chief" else (uid if kind=="hut" else kind+":"+uid)
func snapshot()->String:return JSON.stringify(app.model.state)
func assert_viewport(control:Control,label:String)->void:
	var viewport:=Rect2(Vector2.ZERO,Vector2(app.w,app.h))
	check(viewport.encloses(control.get_global_rect()),label+" inside viewport "+str(viewport.size))
func run()->void:
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames()
	app.test_mode=true;app.model=GameState.new(SaveStore.new("user://building_ui_v0151_%s"%Time.get_ticks_usec()));app.model.start_new()
	var state:Dictionary=app.model.state.duplicate(true);state.wood=20000;state.stone=20000;app.model.commit(state)
	app.enter_game();await frames(8)
	app.world.player.set_physics_process(false)
	for animal in app.world.animals:animal.set_physics_process(false)
	var flow:BuildingWorkflow=app.building_workflow
	var side:BuildSideMenu=app.build_side
	side.show();side.refresh()
	check(side.entries.size()==6,"All six building choices always present")
	check(not side.entries.chief.disabled,"HQ0 can build chief")
	for kind in ["hut","outpost","hearth","training","shrine"]:
		check(side.entries[kind].visible and side.entries[kind].disabled and not side.entries[kind].hint_text.is_empty(),"Locked option is visible with reason: "+kind)
	check(side.entries.hut.art_feedback.get_node("Cost").text=="나무 20 · 돌 10","Hut dynamic cost shown")
	check(side.entries.shrine.art_feedback.get_node("Cost").text=="나무 10 · 돌 20","Shrine dynamic cost shown")
	var before:=snapshot();side.select_kind("training")
	check(snapshot()==before and not app.choosing_plot,"Locked selection cannot charge")
	side.select_kind("chief");var at:=place("chief")
	app.world_tap(app.world.get_global_transform_with_canvas()*at);await frames()
	check(app.build_preview.active() and app.build_preview.site_id==-1,"Free-coordinate preview active without fixed site")
	check((app.build_preview.ghost.sprite.texture.get_size()*app.build_preview.ghost.sprite.scale).is_equal_approx(BuildingVisuals.display_size("chief",1,340)),"Chief preview matches completed 340px foundation scale")
	check(snapshot()==before,"Preview is ephemeral")
	check(app.build_preview.ghost.find_children("*","StaticBody2D",true,false).is_empty(),"Preview creates no collider")
	app.cancel_build_preview();check(not app.build_preview.active() and snapshot()==before,"Preview cancellation preserves save")
	side.select_kind("chief");app.build_preview.select_position(at,"chief");app.confirm_build_preview();app.confirm_build_preview();await frames(3)
	check(app.model.construction_jobs().size()==1 and app.model.state.wood==19980,"Duplicate confirmation charges construction once")
	var job:Dictionary=app.model.construction_jobs()[0];var uid:=str(job.uid)
	flow.update_constructions();await frames()
	check(flow.construction_progress.has(uid),"Durable job creates construction progress")
	var progress:ConstructionProgress=flow.construction_progress[uid]
	check(progress.visible and is_instance_valid(progress.cancel_button),"Construction progress has visible X")
	check(progress.cancel_button.get_global_rect().size.x>=43.9 and progress.cancel_button.get_global_rect().size.y>=43.9,"Job X retains 44px touch size through zoom")
	progress.request_cancel();check(app.modal,"X opens confirmation")
	app.close_modal();check(app.model.construction_jobs().size()==1,"Dismissing confirmation preserves job")
	app.show_modal("다른 창","",[{"text":"닫기","action":app.close_modal}]);check(not flow.confirm_cancel(uid,false),"Stale cancel callback cannot act from unrelated modal");app.close_modal()
	progress.request_cancel();check(flow.confirm_cancel(uid,false),"Confirmed X cancels construction")
	check(not flow.confirm_cancel(uid,false) and app.model.state.wood==20000 and app.model.state.stone==20000,"100 percent refund exactly once")
	await frames()
	check(not flow.construction_progress.has(uid),"Cancelled progress removed")
	check(complete("chief")=="chief","Chief built first")
	state=app.model.state.duplicate(true);state.chief_level=4;app.model.commit(state);await frames(5)
	var keys:Dictionary={}
	for kind in ["hut","hearth","training","shrine","outpost"]:
		keys[kind]=complete(kind);await frames(4)
	for kind in keys:
		var key:String=keys[kind];var sprite:Sprite2D=app.world.building_sprite(key)
		check(sprite!=null and sprite.texture!=null,"Completed building has approved sprite: "+kind)
		if kind=="hut":app.model.claim_reward(0)
		check(app.building_menu.show_at(sprite.get_global_transform_with_canvas()*Vector2.ZERO),"Generic building menu opens: "+kind)
		check(app.building_menu.selected_key==key and not app.building_menu.move_button.disabled,"Move active for "+kind)
		check(not app.building_menu.upgrade_button.disabled,"Upgrade active for "+kind)
		check(not app.building_menu.demolish_button.disabled,"Demolition active for "+kind)
		app.building_menu.close()
	var training_key:String=keys.training
	flow.request_owned_upgrade(training_key);check(app.modal,"Facility upgrade confirmation opens")
	check(flow.confirm_owned_upgrade(training_key,2),"Facility upgrade starts")
	await frames()
	check(flow.owned_progress.has(training_key),"Facility upgrade progress shares existing UI")
	var training_sprite:Sprite2D=app.world.building_sprite(training_key)
	app.building_menu.show_at(training_sprite.get_global_transform_with_canvas()*Vector2.ZERO)
	check(app.building_menu.move_button.disabled and not app.building_menu.move_button.hint_text.is_empty(),"Active upgrade locks movement with reason")
	app.building_menu.close()
	before=snapshot();flow.request_cancel_upgrade(training_key);app.close_modal()
	check(snapshot()==before,"Dismiss upgrade cancellation preserves job")
	var wood_before:int=app.model.state.wood
	flow.request_cancel_upgrade(training_key);check(flow.confirm_cancel(training_key,true),"Facility upgrade cancellation")
	check(app.model.state.wood==wood_before+20,"Facility upgrade refunds actual paid amount")
	var old:Vector2=app.model.building_position(training_key);app.start_building_move(training_key)
	check(app.build_preview.moving_key==training_key,"Move reuses preview")
	var destination:=place("training",training_key)
	app.world_tap(app.world.get_global_transform_with_canvas()*destination);app.cancel_build_preview()
	check(app.model.building_position(training_key)==old,"Cancelled move is not saved")
	app.start_building_move(training_key);app.build_preview.select_position(destination,"training",training_key);app.confirm_build_preview()
	check(app.model.building_position(training_key).is_equal_approx(destination),"Confirmed move persists world position")
	var invalid:Vector2=app.model.building_position(keys.hut)
	app.start_building_move(training_key);app.build_preview.select_position(invalid,"training",training_key)
	check(not app.build_preview.validity() and app.build_preview.confirm_button.disabled,"Overlapping preview visibly blocks confirmation")
	app.confirm_build_preview();check(app.model.building_position(training_key)==destination,"Invalid move cannot mutate save");app.cancel_build_preview()
	check(OwnedBuildingUpgrades.start(app.model,keys.shrine),"Progress viewport fixture starts")
	flow.update_owned_upgrades();await frames()
	var viewport_progress:ConstructionProgress=flow.owned_progress[keys.shrine]
	for dimensions in [Vector2i(540,960),Vector2i(960,540),Vector2i(1280,592)]:
		root.size=dimensions;await frames(8);app._process(0)
		app.build_side.show();app.build_side.refresh();await frames()
		for kind in BuildSideMenu.KINDS:assert_viewport(app.build_side.entries[kind],"Side "+kind)
		for i in BuildSideMenu.KINDS.size():
			for j in range(i+1,BuildSideMenu.KINDS.size()):check(not app.build_side.entries[BuildSideMenu.KINDS[i]].get_global_rect().intersects(app.build_side.entries[BuildSideMenu.KINDS[j]].get_global_rect()),"Side hit targets distinct")
		app.build_side.hide()
		var image:Sprite2D=app.world.building_sprite(training_key)
		for zoom in [DemoPlayer.MIN_ZOOM,DemoPlayer.MAX_ZOOM]:
			app.world.player.zoom_at(Vector2(app.w,app.h)*.5,zoom);await frames(2)
			var menu:BuildingMenu=app.building_menu;menu.show_at(image.get_global_transform_with_canvas()*Vector2.ZERO);menu.refresh();await frames()
			for control in [menu.move_button,menu.upgrade_button,menu.demolish_button,menu.close_button]:assert_viewport(control,"Radial "+control.name)
			check(not menu.close_button.get_global_rect().intersects(menu.demolish_button.get_global_rect()),"Close avoids demolish")
			check(menu.position.y+menu.size.y<=app.action_row.global_position.y,"Radial avoids bottom HUD")
			menu.close();await frames()
			viewport_progress=flow.owned_progress[keys.shrine]
			assert_viewport(viewport_progress.cancel_button,"Job X")
			check(viewport_progress.cancel_button.get_global_rect().size.is_equal_approx(Vector2(44,44)),"Job X stays44px at min/maxzoom")
			check(not viewport_progress.get_global_rect().intersects(viewport_progress.cancel_button.get_global_rect()),"Job X does not overlap progress bar")
		app.start_building_move(training_key);await frames()
		for button in app.build_preview.controls.get_children():assert_viewport(button,"Preview "+button.name)
		app.cancel_build_preview()
	flow.request_cancel_upgrade(keys.shrine);check(flow.confirm_cancel(keys.shrine,true),"Viewport fixture upgrade cancelled")
	var durable_at:=place("hearth")
	check(app.model.begin_construction("hearth",durable_at),"Lifecycle fixture durable construction")
	uid=str(app.model.construction_jobs().back().uid)
	flow.update_constructions();await frames()
	progress=flow.construction_progress[uid]
	app.cancel_task();check(not flow.construction_job(uid).is_empty(),"Ordinary task cancellation keeps durable job")
	app.switch_map_scene();await frames(3)
	check(not progress.visible and not flow.construction_job(uid).is_empty(),"Map hides progress without cancellation")
	app._notification(Node.NOTIFICATION_APPLICATION_PAUSED);await frames()
	check(not flow.construction_job(uid).is_empty(),"Pause preserves durable job")
	app._notification(Node.NOTIFICATION_APPLICATION_RESUMED);app.switch_map_scene();await frames(3)
	check(progress.visible,"Resume and village restore progress")
	var cost_before:int=app.model.state.wood
	flow.request_cancel_construction(uid);check(app.modal,"Deadline race opens cancellation")
	check(app.model.finish_constructions(Time.get_unix_time_from_system()+61),"Construction can complete while cancellation dialog open")
	check(not flow.confirm_cancel(uid,false) and app.model.state.wood==cost_before,"Completion before confirmation prevents erroneous refund")
	await frames()
	check(not flow.construction_progress.has(uid),"Completed progress removed after race")
	var settings:=DevelopmentSettings.entries(app)
	check(settings.size()==4,"Three debug toggles and reset")
	app.show_development_settings();await frames(3)
	for id in ["UnlimitedBuilders","FastBuild","ShowBoundary"]:
		var toggle:CheckBox=app.overlay.find_child(id+"Toggle",true,false)
		check(toggle!=null and toggle.text in ["ON","OFF"],"Consistent ON/OFF wording: "+id)
	var fast:CheckBox=app.overlay.find_child("FastBuildToggle",true,false)
	fast.button_pressed=true
	check(app.model.debug_fast_build and fast.text=="ON","FastBuild UI changes model and shows ON")
	fast.button_pressed=false
	check(not app.model.debug_fast_build and fast.text=="OFF","FastBuild UI restores base time and OFF")
	var boundary:CheckBox=app.overlay.find_child("ShowBoundaryToggle",true,false)
	boundary.button_pressed=true
	check(app.model.debug_show_boundary and boundary.text=="ON","Boundary UI changes model and shows ON")
	boundary.button_pressed=false
	check(not app.model.debug_show_boundary and boundary.text=="OFF","Boundary UI restores OFF")
	app.close_modal()
	print(JSON.stringify({"checks":checks,"failures":failures}))
	app.queue_free();await frames();quit(0 if failures.is_empty() else 1)
