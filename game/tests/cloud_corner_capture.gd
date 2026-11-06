extends SceneTree
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
	for i in n:await process_frame
func run()->void:
	var app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames(5)
	app.model=GameState.new(SaveStore.new("user://cloud_%s"%Time.get_ticks_usec()));app.model.start_new();app.enter_game();await frames(20)
	for dimensions in [Vector2i(1280,720),Vector2i(540,960)]:
		root.size=dimensions;await frames(20)
		for factor in [DemoPlayer.MIN_ZOOM,DemoPlayer.MAX_ZOOM]:
			app.world.player.zoom_at(Vector2(app.w,app.h)*.5,factor);await frames(10)
			var clouds=app.world.get_node("VillageEdgeClouds")
			assert(clouds.get_child_count()==4)
			assert(not clouds.visible if factor==DemoPlayer.MAX_ZOOM else clouds.modulate.a<=.301)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://reports/cloud-%dx%d-%s.png"%[dimensions.x,dimensions.y,str(factor)])
	print("Four corner-cloud captures and maximum zoom exclusion: PASS")
	app.queue_free();await process_frame;quit()
