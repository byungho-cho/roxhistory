extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var app: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(app);await process_frame
	app.model.start_new();app.start_region();app.close_modal()
	app.world.player.position=Vector2(1750,1140)
	app.world.player.camera.position=Vector2(0,-80)
	app.world.player.zoom_factor=1.7;app.world.player.fit_camera()
	var results: Array = []
	for enabled in [false,true,false,true]:
		for animal in app.world.animals:
			animal.visible=enabled;animal.set_process(enabled)
			animal.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE if enabled else SubViewport.UPDATE_DISABLED
		for i in 60: await process_frame
		var samples: Array[float] = []
		var last := Time.get_ticks_usec()
		for i in 1000:
			await process_frame
			var now := Time.get_ticks_usec()
			samples.append((now-last)/1000.0);last=now
		samples.sort()
		var total := 0.0
		for value in samples: total+=value
		results.append({"wildlife":enabled,"frames":1000,"mean_ms":total/1000,"p95_ms":samples[950]})
	var report := {"environment":"Windows native Godot, uncapped, same scene/camera; alternate animal render off/on twice; not Android performance","gpu":RenderingServer.get_video_adapter_name(),"resolution":str(root.size),"samples":results}
	FileAccess.open("res://reports/worldlife-performance.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report));quit()
