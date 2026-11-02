extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var model := GameState.new(SaveStore.new("user://tests/wildlife_capture"))
	model.start_new()
	var world := DemoWorld.new(model)
	root.add_child(world)
	await process_frame
	world.player.set_physics_process(false)
	world.player.camera.top_level = true
	world.player.camera.position_smoothing_enabled = false
	world.player.camera.position = Vector2(1200,675)
	world.player.camera.zoom = Vector2.ONE*0.53
	for i in 30: await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://reports")
	root.get_texture().get_image().save_png("res://reports/wildlife-world.png")
	world.player.camera.position = Vector2(1860,1040)
	world.player.camera.zoom = Vector2.ONE*1.1
	for i in 30: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/wildlife-close.png")
	quit()
