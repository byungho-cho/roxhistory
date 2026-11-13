extends SceneTree
var failed:Array[String]=[]
var checks:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failed.append(label);push_error(label)
func run()->void:
	var audio:=DemoSoundscape.new();root.add_child(audio);await process_frame
	audio.configure(true,true,false,false,true);await create_timer(.65).timeout
	check(audio.bgm.playing and audio.scene_music.is_empty(),"Region selection keeps original BGM")
	var map_stream=audio.bgm.stream
	var village := audio.scene_music_players["village"]
	var world_map := audio.scene_music_players["world_map"]
	audio.configure(true,true,true,false,false);await create_timer(.65).timeout
	check(village.playing and not audio.bgm.playing,"Play transitions to new village BGM without persistent overlap")
	var stream:AudioStreamOggVorbis=village.stream
	check(absf(stream.get_length()-175.02)<.15 and stream.loop,"Village uses the full edited A09-10 track")
	check(is_equal_approx(village.volume_db,DemoSoundscape.SCENE_MUSIC_DB["village"]),"Village gain reaches configured level")
	village.seek(stream.get_length()-.4)
	await create_timer(.9).timeout
	check(village.playing and village.get_playback_position()<2,"Actual mixer crosses loop endpoint and continues")
	audio.cue("wood");audio.cue("stone")
	check(audio.events.has("recorded_wood") and audio.events.has("recorded_stone"),"Gather effects coexist with selected music")
	audio.configure(true,false,true,false);var paused:=village.get_playback_position();await create_timer(.3).timeout
	check(village.stream_paused and absf(village.get_playback_position()-paused)<.05,"Background pauses position")
	audio.configure(true,true,true,false);await create_timer(.3).timeout
	check(not village.stream_paused and village.get_playback_position()>paused,"Foreground resumes rather than restarting")
	audio.configure(false,true,true,false);check(village.stream_paused,"Mute pauses play music")
	audio.configure(true,true,true,true);await create_timer(.65).timeout
	check(is_equal_approx(village.volume_db,DemoSoundscape.SCENE_MUSIC_DB["village"]-6),"Popup ducks music")
	audio.configure(true,true,true,false,false,false,"",true);await create_timer(.65).timeout
	check(world_map.playing and not village.playing and absf(world_map.stream.get_length()-164.57)<.15,"World map uses the separate A09-11 track")
	audio.configure(true,true,false,false,true);await create_timer(.65).timeout
	check(audio.bgm.playing and audio.bgm.stream==map_stream and not village.playing,"Return to map restores unchanged selected map track")
	audio.configure(false,false,false,false)
	check(not village.playing,"Leaving while muted cannot leave background music running")
	audio.queue_free();await process_frame;await process_frame
	var report={"checks":checks,"failed":failed,"runtime":"Godot mixer; endpoint seek; automated only, not physical speaker listening"}
	FileAccess.open("res://reports/play-music-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failed.is_empty() else 1)
