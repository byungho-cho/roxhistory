extends "res://tests/interaction_v057_tests.gd"
func shot(file:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/v057-"+file+".png")
func run()->void:
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames()
	app.test_mode=true;app.model=GameState.new(SaveStore.new("user://capture057"));app.model.start_new();app.model.changed.connect(app.update_hud)
	var state:Dictionary=app.model.state.duplicate(true);state.chief_level=1;app.model.commit(state)
	app.enter_game();await frames(8)
	var old:Vector2=app.model.building_position("chief");var at:=old+Vector2(340,160)
	if not app.world.placement_requirement("chief",at,"chief").is_empty():at=free_position("chief","chief")
	app.start_building_move("chief");app.build_preview.select_position(at,"chief","chief")
	app.world.player.manual_camera=true;app.world.player.zoom_at(Vector2(app.w,app.h)*.5,1.2,(old+at)*.5);await frames(10)
	await shot("move-preview");await create_timer(.6).timeout
	app.confirm_build_preview();await create_timer(.4).timeout;await shot("move-departure")
	await create_timer(1.6).timeout;await shot("move-arrival")
	await create_timer(1.2).timeout;await shot("move-complete")
	app.queue_free();await frames();quit()
