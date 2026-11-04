extends SceneTree
var app:Node
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
	for i in n:await physics_frame;await process_frame
func snap(label:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/s40000-"+label+".png")
func run()->void:
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames(3)
	app.start_region();app.close_modal();await frames(90);await snap("initial")
	await frames(5);await snap("menu")
	for i in 2:
		app.model.gather("wood_1");app.model.gather("stone_1");app.model.build()
	app.model.state.homes[0].style=1;app.model.state.homes[1].style=2;app.world.refresh()
	await frames(120);await snap("overview")
	app.world.player.zoom_at(Vector2(480,270),2.0,Vector2(1150,690));await frames(90);await snap("maximum")
	app.world.player.zoom_at(Vector2(480,270),1);await frames(5)
	app.world_tap(app.world.get_global_transform_with_canvas()*Vector2(1620,960));await frames(20);await snap("route")
	await frames(360);await snap("arrival");app.cancel_task()
	app.model.gather("wood_2");app.model.gather("stone_2")
	app.world.player.position=app.world.site.position+Vector2(0,70);await frames(3);app.build_action();await frames(65);await snap("construction")
	await frames(150)
	app.world.player.zoom_at(Vector2(480,270),2.0,Vector2(650,1000));await frames(240);await snap("wildlife")
	for animal in app.world.animals:print("WILDLIFE ",animal.species," distance=",animal.walked_distance," bones=",animal.rig.get_bone_count())
	print("S40000_CAPTURE_COMPLETE");quit()
