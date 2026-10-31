extends SceneTree
func _initialize():call_deferred("run")
func run():
	var app=load("res://scenes/main.tscn").instantiate();root.add_child(app)
	await process_frame
	for screen in ["onboarding","title","region"]:
		app.show_screen(screen)
		for i in 30:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://reports/c001-"+screen+".png")
	app.start_region();app.close_modal();app.world.player.position=Vector2(1060,1030)
	for i in 60:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/c001-play.png")
	app.world.player.zoom_factor=2.0;app.world.player.fit_camera()
	for i in 60:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/c001-zoom.png")
	quit()
