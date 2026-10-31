extends SceneTree
var app: Node
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame;await RenderingServer.frame_post_draw
func run() -> void:
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await process_frame
	app.start_region();app.close_modal()
	var p: DemoPlayer=app.world.player
	p.position=Vector2(1060,1030);p.hybrid.target_heading=0
	await frames(60)
	print("OBJECTIVES ",app.world.objectives.targets)
	root.get_texture().get_image().save_png("res://reports/play-world.png")
	app.set_process(false);p.set_physics_process(false)
	p.hybrid.set_render_zoom(3);p.camera.position_smoothing_enabled=false;p.camera.zoom=Vector2(1.4,1.4);p.camera.position=Vector2(0,-70);p.camera.reset_smoothing()
	for entry in [[0.0,"front"],[PI/2,"side"],[PI,"back"]]:
		p.hybrid.heading=entry[0];p.hybrid.target_heading=entry[0];p.hybrid.animate(0,Vector2.ZERO,0,false,"",0,false)
		await frames(4)
		root.get_texture().get_image().save_png("res://reports/play-"+entry[1]+".png")
	if "--portrait" in OS.get_cmdline_user_args():
		p.hybrid.heading=0;p.hybrid.target_heading=0;p.hybrid.animate(0,Vector2.ZERO,0,false,"",0,false)
		p.hybrid.viewport.size=Vector2i(512,512)
		p.hybrid.camera.size=1.75;p.hybrid.camera.position=Vector3(0,2.5,5);p.hybrid.camera.look_at(Vector3(0,1.86,0))
		await frames(5)
		var portrait:=p.hybrid.viewport.get_texture().get_image();portrait.resize(256,256,Image.INTERPOLATE_LANCZOS)
		DirAccess.make_dir_recursive_absolute("res://assets/ui")
		portrait.save_png("res://assets/ui/hero_portrait.png")
	quit()
