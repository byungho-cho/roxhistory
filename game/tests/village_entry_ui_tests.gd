extends "res://tests/building_hold_v056_tests.gd"

func tap(at:Vector2)->void:
	touch(at,0,true)
	touch(at,0,false)

func run()->void:
	root.size=Vector2i(1200,675)
	app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await frames()
	app.test_mode=true
	app.model=GameState.new(SaveStore.new("user://village_entry_ui_%d"%Time.get_ticks_usec()))
	app.prefs_path=app.model.store.directory.path_join("preferences.cfg")
	app.settings=ConfigFile.new()
	app.performance_diagnostics.path=app.model.store.directory.path_join("performance-diagnostics.jsonl")
	check(PerformanceDiagnostics.enabled(app.settings),"Missing preference defaults to diagnostics ON")
	app.set_performance_diagnostics(false)
	var updated_settings:=ConfigFile.new()
	check(updated_settings.load(app.prefs_path)==OK and not PerformanceDiagnostics.enabled(updated_settings),"Explicit OFF survives reloading preferences")
	app.set_performance_diagnostics(true)
	app.model.changed.connect(app.update_hud)
	await create_timer(.5).timeout
	app.start_region()
	await frames()
	check(app.village_entry_active() and not app.modal and not app.tutorial.active(),"Fresh village entry defers both guide and hand")
	var player:DemoPlayer=app.world.player
	var start:=player.position
	check(player.zoom_factor<1,"Entry begins with a wider view")
	tap(Vector2(app.w,app.h)*.75)
	check(app.gestures.touches.is_empty(),"Entry consumes world touches")
	await create_timer(VillageEntry.DURATION).timeout
	await frames(5)
	check(not app.village_entry_active() and player.position==start and is_equal_approx(player.zoom_factor,1),"Entry restores camera without changing save coordinates")
	var fog:Node2D=app.world.get_node("VillageBoundaryFog")
	var bounds:Rect2=app.world.playable_rect()
	check(fog.visible and fog.material.get_shader_parameter("boundary")==Vector4(bounds.position.x,bounds.position.y,bounds.end.x,bounds.end.y),"Fog remains aligned with the existing playable boundary after entry")
	var entry_log:=FileAccess.get_file_as_string(app.performance_diagnostics.path)
	check(entry_log.contains('"scene":"village_entry"') and entry_log.contains('"frame_p95_ms"'),"Diagnostics record the short entry with real frame intervals")
	check(app.overlay is CharacterGuide,"First guide appears after the clouds")
	if app.overlay is CharacterGuide:app.overlay.advance()
	await frames(5)
	check(not app.modal,"The initial guide does not repeat")

	app.enter_game(true)
	app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	app._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(not app.village_entry_active() and not player.presentation_paused and not player.manual_camera,"Resume restores camera and controls")
	app.enter_game(true)
	app.relayout()
	check(not app.village_entry_active() and is_equal_approx(player.zoom_factor,1),"Relayout interrupts entry safely")
	app.enter_game(true)
	app.go_back()
	check(not app.village_entry_active() and not app.modal,"Back skips the entry without opening another popup")
	app.enter_game()
	check(not app.village_entry_active(),"Continue does not replay the entry")

	var state:Dictionary=app.model.state.duplicate(true)
	state.chief_level=1
	state.wood=400
	state.stone=400
	state.quests_done=FirstQuests.IDS.slice(0,4)
	state.quests_claimed=FirstQuests.IDS.slice(0,3)
	state.quests_guides=FirstQuests.IDS.slice(0,4)
	state.family_next_at=Time.get_unix_time_from_system()+10000
	app.model.commit(state)
	await frames(10)
	var board:VillageRewardBoard=app.stage.get_node("VillageRewardBoard")
	check(board.visible and board.marker.visible and board.size==Vector2(118,120) and board.marker.size==Vector2(51,51),"Larger board and pending marker show")
	var signs:BuildingUpgradeSigns
	for child in app.stage.get_children():
		if child is BuildingUpgradeSigns:signs=child
	var sign_button:DemoButton=signs.signs.get("chief")
	check(is_instance_valid(sign_button) and sign_button.visible,"Eligible chief shows the sign")
	for extent in [Vector2i(1200,675),Vector2i(1200,540),Vector2i(600,900)]:
		root.size=extent
		await frames(8)
		board=app.stage.get_node("VillageRewardBoard")
		for child in app.stage.get_children():
			if child is BuildingUpgradeSigns:signs=child
		for zoom in [.8,1.2]:
			player.zoom_at(Vector2(app.w,app.h)*.5,zoom,app.model.building_position("chief"))
			await frames()
			var transform_to_screen:=app.world.get_global_transform_with_canvas() as Transform2D
			var at:Vector2=transform_to_screen*(app.model.building_position("chief")+VillageRewardBoard.EAST_CORNER)
			check(board.position.distance_to(at-board.size*board.scale*Vector2(.18,1))<1,"Board tracks the east corner across zoom and aspect ratios")
			sign_button=signs.signs.get("chief")
			var south:Vector2=transform_to_screen*(app.model.building_position("chief")+Vector2(0,132))
			var hit_extent:=maxf(44.0,40.0*zoom+4.0)
			check(is_instance_valid(sign_button) and sign_button.position.distance_to(south-Vector2(.5,.8)*hit_extent)<1 and is_equal_approx(sign_button.size.x,hit_extent),"Sign scales around the south corner and keeps a 44 px hit area")
	root.size=Vector2i(1200,675)
	await frames(8)
	player.zoom_at(Vector2(app.w,app.h)*.5,.85,app.model.building_position("chief"))
	await frames()
	board=app.stage.get_node("VillageRewardBoard")
	await capture("village-entry-board")
	check(app.building_menu.show_at(building_point()),"Chief submenu opens")
	await frames()
	await capture("village-entry-menu")
	board.set_process(false)
	var close_at:Vector2=app.building_menu.close_button.get_global_rect().get_center()
	board.position=close_at-board.size*board.scale*.5
	tap(close_at)
	await frames()
	check(not app.building_menu.visible and not app.modal,"Overlapping X consumes the touch ahead of the board")
	check(app.building_menu.show_at(building_point()),"Submenu reopens after X")
	await frames()
	var upgrade_at:Vector2=app.building_menu.upgrade_button.get_global_rect().get_center()
	board.position=upgrade_at-board.size*board.scale*.5
	tap(upgrade_at)
	await frames()
	check(is_instance_valid(app.overlay) and app.overlay.name=="CompactUpgradeOverlay","Overlapping upgrade gets the touch ahead of the board")
	if app.modal:app.close_modal()
	board.set_process(true)
	await frames()
	tap(board.get_global_rect().get_center())
	await frames()
	check(app.modal,"Board receives non-overlapping touch")
	if app.modal:app.close_modal()
	check(app.model.claim_quest_reward(3) and not app.model.claim_quest_reward(3),"Reward can be paid only once")
	await frames()
	check(not board.marker.visible,"Claim updates marker immediately")
	print(JSON.stringify({"checks":checks,"failures":failures}))
	app.queue_free()
	await frames()
	quit(0 if failures.is_empty() else 1)
