extends SceneTree
var app:Node
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
	for i in n:await physics_frame;await process_frame
func run()->void:
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames(3)
	app.start_region();app.close_modal();await frames(10)
	app.canvas.visible=false
	for pose in [["hut-behind",Vector2(865,680),Vector2(865,720)],["hut-front",Vector2(865,780),Vector2(865,720)],["tree-behind",Vector2(330,770),Vector2(330,800)],["tree-front",Vector2(330,850),Vector2(330,800)]]:
		app.world.player.position=pose[1]
		app.world.player.zoom_at(Vector2(480,270),2.0,pose[2]);await frames(15)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://reports/depth-"+pose[0]+".png")
	print("Depth inspection captures complete; staged foot positions, not traversal validation")
	quit()
