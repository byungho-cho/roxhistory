extends SceneTree
func _initialize() -> void:call_deferred("run")
func frames(n:int) -> void:
	for i in n:await process_frame;await RenderingServer.frame_post_draw
func run() -> void:
	var app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await process_frame;app.show_screen("region");await frames(30)
	root.get_texture().get_image().save_png("res://reports/region-overview.png")
	for key in ["jeongok","amsa","dongsam"]:
		app.region_selection.select_region(key);await create_timer(.75).timeout;await frames(3)
		root.get_texture().get_image().save_png("res://reports/region-"+key+".png")
	quit()
