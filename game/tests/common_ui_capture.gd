extends SceneTree
func _initialize() -> void:call_deferred("run")
func capture(app:Node,key:String) -> void:
	await create_timer(.5).timeout
	for i in 3:await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/a303-"+key+".png")
func run() -> void:
	var app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await process_frame
	app.show_screen("onboarding");await capture(app,"onboarding")
	app.show_screen("title");await capture(app,"title")
	app.chapter_menu();await capture(app,"chapter");app.close_modal()
	app.show_screen("region");app.start_region();app.close_modal();await capture(app,"play")
	app.quest_details();await capture(app,"quest")
	quit()
