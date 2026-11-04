extends SceneTree
func _initialize()->void:root.unfocusable=true;call_deferred("run")
func run()->void:
	var app=load("res://scenes/main.tscn").instantiate();root.add_child(app)
	for i in 3:await process_frame
	app.start_region()
	for i in 3:await process_frame
	for a in app.world.animals:a.set_physics_process(false)
	for r in app.world.residents:r.set_physics_process(false)
	app.world.player.position=Vector2(1150,900);app.world.player.resume_camera()
	for i in 30:await process_frame
	app.toast("나무 1개와 돌 1개가 필요해요",2);app._process(.01)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/queue-comparison.png")
	quit()
