extends SceneTree
var app: Node
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await process_frame
func snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/worldlife-"+label+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://reports")
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app); await frames(2)
	app.model.start_new(); app.start_region(); app.close_modal(); await frames(30)
	await snap("settlement")
	app.joystick.value = Vector2.RIGHT; await frames(30)
	app.joystick.value = Vector2.DOWN; await frames(30)
	app.joystick.value = Vector2.LEFT; await frames(30)
	app.joystick.clear(); await frames(20)
	var player: DemoPlayer = app.world.player
	player.position = Vector2(1360,830)
	player.position = app.world.gather_stand(Vector2(1420,830),"wood")
	player.camera.reset_smoothing(); await frames(5)
	app.gather_action(); await frames(65)
	player.position = Vector2(1400,1070); await frames(5)
	app.gather_action(); await frames(65)
	player.position = Vector2(820,1060);player.camera.reset_smoothing();await frames(5)
	app.build_action();await frames(10)
	app.overlay.get_child(1).get_child(0).get_child(2).get_child(1).pressed.emit()
	await frames(30);await snap("construction")
	await frames(40);await snap("completed")
	app.close_modal();await frames(20)
	player.position = Vector2(1830,1210)
	player.camera.position = Vector2(0,-80)
	player.zoom_factor = 1.7;player.fit_camera();await frames(35)
	await snap("wildlife")
	await frames(60)
	quit()
