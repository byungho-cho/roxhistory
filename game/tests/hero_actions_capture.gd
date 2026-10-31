extends SceneTree
# Explicit test staging; real task timers and save commits, not a user playthrough.
var app: Node
var p: DemoPlayer
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n:
		await physics_frame;await process_frame
		p.camera.position=p.position+Vector2(0,-60)
		await RenderingServer.frame_post_draw
func run() -> void:
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await process_frame
	app.settings.set_value("app","sound",true);app.start_region();app.close_modal()
	p=app.world.player;p.set_character_3d(true);p.camera.top_level=true;p.camera.zoom=Vector2(2.0,2.0);app.canvas.visible=false
	p.position=Vector2(1360,830);await frames(30);app.gather_action();await frames(18)
	root.get_texture().get_image().save_png("res://reports/hero-wood-contact.png");await frames(75)
	p.position=Vector2(1360,1080);await frames(30);app.gather_action();await frames(18)
	root.get_texture().get_image().save_png("res://reports/hero-stone-contact.png");await frames(75)
	p.position=Vector2(820,1060);await frames(30);app.build_action()
	app.overlay.get_child(1).get_child(0).get_child(2).get_child(1).pressed.emit();await frames(18)
	root.get_texture().get_image().save_png("res://reports/hero-build-contact.png");await frames(125)
	assert(app.model.state.built and app.model.state.wood==0 and app.model.state.stone==0)
	app.audio.configure(false,false,false,false)
	app.queue_free();await process_frame;await RenderingServer.frame_post_draw
	quit()
