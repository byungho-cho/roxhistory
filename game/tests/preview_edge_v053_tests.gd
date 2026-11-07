extends "res://tests/windows_v052_tests.gd"
func run()->void:
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames()
	app.test_mode=true;app.model=GameState.new(SaveStore.new("user://edge053_%d"%Time.get_ticks_usec()));app.model.start_new()
	var state:Dictionary=app.model.state.duplicate(true);state.chief_level=1;app.model.commit(state)
	app.enter_game();await frames(8);app.world.player.manual_camera=true
	app.start_building_move("chief")
	var original:Vector2=app.model.building_position("chief")
	for zoom in [DemoPlayer.MIN_ZOOM,DemoPlayer.MAX_ZOOM]:
		app.world.player.zoom_at(Vector2(app.w,app.h)*.5,zoom);await frames()
		for y in [45.0,75.0,app.h-65,app.h-25]:
			var point:Vector2=app.world.get_global_transform_with_canvas().affine_inverse()*Vector2(app.w*.5,y)
			app.build_preview.select_position(point,"chief","chief");await frames()
			var preview:BuildPreview=app.build_preview
			var building:Rect2=preview.ghost.sprite.get_global_transform_with_canvas()*preview.ghost.sprite.get_rect()
			var buttons:Rect2=preview.controls.get_global_rect()
			check(preview.controls.visible,"Edge preview controls visible")
			check(Rect2(app.safe,Vector2(app.w,app.h)-app.safe*2).encloses(buttons),"Controls stay in viewport")
			var gap:=maxf(0,maxf(building.position.y-buttons.end.y,buttons.position.y-building.end.y))
			check(gap<=8.1,"Controls remain attached at zoom %s y %s"%[zoom,y])
			check(absf(buttons.get_center().x-building.get_center().x)<1,"Controls horizontally follow building")
			if DisplayServer.get_name()!="headless" and zoom==DemoPlayer.MAX_ZOOM and y==45.0:
				await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://reports/v053-top-edge.png")
			if DisplayServer.get_name()!="headless" and zoom==DemoPlayer.MAX_ZOOM and y==app.h-25:
				await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://reports/v053-bottom-edge.png")
	check(app.model.building_position("chief")==original,"Dragging preview never commits coordinates")
	app.cancel_build_preview();check(not app.build_preview.controls.visible,"Cancel removes overlay")
	var report:={"checks":checks,"failures":failures,"rendered":DisplayServer.get_name()!="headless"}
	FileAccess.open("res://reports/v053-edge-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report))
	app.queue_free();await frames();quit(0 if failures.is_empty() else 1)
