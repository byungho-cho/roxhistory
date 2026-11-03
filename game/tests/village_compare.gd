extends SceneTree
var app:Node
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
	for i in n:await physics_frame;await process_frame
func snap(label:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/village-"+label+".png")
func run()->void:
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames(3)
	app.start_region();app.close_modal();await frames(60);await snap("initial")
	app.actions_expanded=true;await frames(3);await snap("expanded");app.actions_expanded=false
	app.world.player.position=Vector2(1150,900)
	app.world.player.zoom_at(Vector2(480,270),2.0,Vector2(1150,820));await frames(30);await snap("maximum")
	app.set_process(false)
	app.world.player.direction=Vector2.RIGHT;await frames(120)
	app.world.player.direction=Vector2.DOWN;await frames(60)
	app.world.player.direction=Vector2.LEFT;await frames(120)
	app.world.player.direction=Vector2.ZERO;await frames(180)
	print("VILLAGE_COMPARE_COMPLETE");quit()
