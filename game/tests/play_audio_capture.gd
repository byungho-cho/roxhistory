extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var audio:=DemoSoundscape.new();root.add_child(audio);await process_frame
	var recorder:=AudioEffectRecord.new();recorder.format=AudioStreamWAV.FORMAT_16_BITS
	var index:=AudioServer.get_bus_effect_count(0);AudioServer.add_bus_effect(0,recorder);recorder.set_recording_active(true)
	audio.configure(true,true,false,false,true);await create_timer(2).timeout
	audio.configure(true,true,true,false);await create_timer(2).timeout
	audio.cue("wood");await create_timer(.8).timeout;audio.cue("stone");await create_timer(.8).timeout;audio.cue("gain");await create_timer(1).timeout
	var village := audio.scene_music_players["village"];village.seek(village.stream.get_length()-1);await create_timer(3).timeout
	recorder.set_recording_active(false);recorder.get_recording().save_to_wav("res://reports/play-game-mix.wav");AudioServer.remove_bus_effect(0,index)
	audio.configure(false,false,false,false);audio.queue_free();await process_frame;await process_frame;quit()
