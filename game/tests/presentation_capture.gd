extends SceneTree
var app: Node
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame; await process_frame
func walk(direction: Vector2, n: int) -> void:
	app.joystick.value = direction
	await frames(n)
	app.joystick.clear()
	await frames(18)
func run() -> void:
	app = load("res://scenes/main.tscn").instantiate(); root.add_child(app); await frames(2)
	app.settings.set_value("app","sound",true); app.show_screen("title"); await frames(70)
	app.start_region(); app.world.player.set_character_3d(true); await frames(55); app.close_modal()
	await walk(Vector2(0.88,-0.47),150)
	app.gather_action(); await frames(90)
	assert(app.model.state.wood == 1)
	await walk(Vector2.DOWN,90)
	app.gather_action(); await frames(90)
	assert(app.model.state.stone == 1)
	await walk(Vector2.LEFT,195)
	await walk(Vector2(-0.88,0.47),35)
	await walk(Vector2.DOWN,20)
	if not app.world.near_site():
		push_error("Capture route missed site: "+str(app.world.player.position)); quit(1); return
	app.build_action(); await frames(35)
	app.overlay.get_child(1).get_child(0).get_child(2).get_child(1).pressed.emit(); await frames(140)
	assert(app.model.state.built)
	app.overlay.get_child(1).get_child(0).get_child(2).get_child(0).pressed.emit(); await frames(100)
	assert(app.model.state.tokens == 10)
	print("P4 captured with engine-mixed audio; synthetic joystick, no teleport")
	app.audio.configure(false,false,false,false)
	app.queue_free(); await frames(3)
	quit()
