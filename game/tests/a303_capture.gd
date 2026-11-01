extends SceneTree
func _initialize() -> void:call_deferred("run")
func frames(n:int) -> void:
	for i in n:await process_frame;await RenderingServer.frame_post_draw
func capture(path:String) -> void:
	await create_timer(.65).timeout
	await frames(4);root.get_texture().get_image().save_png("res://reports/"+path+".png")
func run() -> void:
	var app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await process_frame;app.show_screen("region");await frames(10)
	await create_timer(.5).timeout
	var map=app.region_selection
	for key in ["dongsam","jeongok","amsa"]:
		map.selected=key;map.refresh();map.pose(1,(map.size-map.BASE*map.factor)*.5)
		await capture("a303-"+key+"-full")
		map.select_region(key);await create_timer(.7).timeout
		await capture("a303-"+key+"-selected")
	map.pose(1.4,Vector2(-224,-28)*map.factor);await capture("a303-amsa-mid")
	map.pose(2,Vector2(-560,-70)*map.factor);await capture("a303-amsa-max")
	quit()
