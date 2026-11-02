extends SceneTree
var app:Node
func _initialize() -> void:call_deferred("run")
func shot(name:String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/"+name+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://reports")
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await process_frame
	app.settings.set_value("app","sound",true);app.show_screen("region")
	app.audio.bird_wait=9.5
	var recorder:=AudioEffectRecord.new();recorder.format=AudioStreamWAV.FORMAT_16_BITS
	var index:=AudioServer.get_bus_effect_count(0);AudioServer.add_bus_effect(0,recorder)
	recorder.set_recording_active(true)
	await create_timer(1.2).timeout
	await shot("a303-audio-amsa")
	for key in ["jeongok","dongsam","amsa"]:
		app.region_selection.select_region(key);await create_timer(.1).timeout
		await shot("a303-audio-"+key+"-impact")
		await create_timer(1.9).timeout
		await shot("a303-audio-"+key)
	await create_timer(6).timeout
	app.region_selection.ambience.clock=6
	app.region_selection.ambience.queue_redraw();await shot("a303-audio-living-map")
	recorder.set_recording_active(false)
	var recording:=recorder.get_recording();recording.save_to_wav("res://reports/a303-game-mix.wav")
	AudioServer.remove_bus_effect(0,index)
	print("A303_GAME_MIX "+JSON.stringify({"seconds":recording.get_length(),"rate":recording.mix_rate,"frames":Engine.get_frames_drawn()}))
	app.queue_free();await process_frame;await process_frame
	quit()
