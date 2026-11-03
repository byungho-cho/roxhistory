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
	check(audio.bgm.playing and not audio.play_bgm.playing,"Map keeps original BGM")
	var map_stream=audio.bgm.stream
	audio.configure(true,true,true,false,false);await create_timer(.65).timeout
	check(audio.play_bgm.playing and not audio.bgm.playing,"Play transitions to selected first embers without persistent overlap")
	var stream:AudioStreamWAV=audio.play_bgm.stream
	check(stream.mix_rate==48000 and stream.loop_end==3544615,"Decoded MP3 gapless frame count, not container duration")
	check(stream.data.slice(stream.loop_end*4,stream.loop_end*4+4)==stream.data.slice(0,4),"PCM guard preserves periodic interpolation")
	check(is_equal_approx(audio.play_bgm.volume_db,DemoSoundscape.PLAY_MUSIC_DB),"Play gain reaches configured level")
	audio.play_bgm.seek(stream.loop_end/48000.0-.4)
	await create_timer(.9).timeout
	check(audio.play_bgm.playing and audio.play_bgm.get_playback_position()<2,"Actual mixer crosses loop endpoint and continues")
	audio.cue("wood");audio.cue("stone")
	check(audio.events.has("wood_1") and audio.events.has("stone_0"),"Gather effects coexist with selected music")
	audio.configure(true,false,true,false);var paused:=audio.play_bgm.get_playback_position();await create_timer(.3).timeout
	check(audio.play_bgm.stream_paused and absf(audio.play_bgm.get_playback_position()-paused)<.05,"Background pauses position")
	audio.configure(true,true,true,false);await create_timer(.3).timeout
	check(not audio.play_bgm.stream_paused and audio.play_bgm.get_playback_position()>paused,"Foreground resumes rather than restarting")
	audio.configure(false,true,true,false);check(audio.play_bgm.stream_paused,"Mute pauses play music")
	audio.configure(true,true,true,true);await create_timer(.65).timeout
	check(is_equal_approx(audio.play_bgm.volume_db,DemoSoundscape.PLAY_MUSIC_DB-3),"Popup ducks music")
	audio.configure(true,true,false,false,true);await create_timer(.65).timeout
	check(audio.bgm.playing and audio.bgm.stream==map_stream and not audio.play_bgm.playing,"Return to map restores unchanged selected map track")
	audio.configure(false,false,false,false)
	check(not audio.play_bgm.playing,"Leaving while muted cannot leave background music running")
	audio.queue_free();await process_frame;await process_frame
	var report={"checks":checks,"failed":failed,"runtime":"Godot mixer; endpoint seek; automated only, not physical speaker listening"}
	FileAccess.open("res://reports/play-music-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failed.is_empty() else 1)
