extends SceneTree

var app: Node
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.model.start_new()
	app.enter_game()
	app.close_modal()
	if "--effects-off" in OS.get_cmdline_user_args():
		app.world.set_environment_effects(false)
	if "--no-shaders" in OS.get_cmdline_user_args():
		for p in app.world.environment_props: p.sprite.material = null
		app.world.water.material = null
	app.world.player.position = Vector2(990,1020)
	var camera: Camera2D = app.world.player.camera
	camera.zoom = Vector2(0.5,0.5)
	camera.offset = Vector2.ZERO
	camera.position = Vector2(180,-220)
	await create_timer(1.0).timeout
	DirAccess.make_dir_recursive_absolute("res://reports")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/environment-arrival.png")
	var samples: Array[float] = []
	var last := Time.get_ticks_usec()
	for i in 10000:
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append(float(now-last)/1000.0)
		last = now
	samples.sort()
	var sum := 0.0
	for ms in samples: sum += ms
	var report := {"utc":Time.get_datetime_string_from_system(true),"engine":Engine.get_version_info().string,"gpu":RenderingServer.get_video_adapter_name(),"resolution":str(root.size),"vsync":"disabled","frames":samples.size(),"mean_frame_ms":sum/samples.size(),"p95_frame_ms":samples[int(samples.size()*0.95)],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)}
	var file := FileAccess.open("res://reports/environment-performance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	quit()
