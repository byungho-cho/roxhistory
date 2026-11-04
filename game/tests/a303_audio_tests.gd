extends SceneTree
class ControlledSoundscape extends DemoSoundscape:
	var now_ms:=10000
	func interface_time_ms() -> int:return now_ms

var checks:=0
var failed:Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:failed.append(message);push_error(message)
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://reports")
	var controlled:=ControlledSoundscape.new();root.add_child(controlled);await process_frame
	controlled.configure(true,true,false,false,true)
	for i in 18:controlled.cue("select")
	check(controlled.events.count("select")==1 and not controlled.events.has("ui"),"Rapid region selection makes one soft cue, without duplicate UI cue")
	controlled.cue("ui")
	check(controlled.events.size()==1,"Duplicate generic UI cue is rejected in same input window")
	controlled.now_ms+=74;controlled.cue("select")
	check(controlled.events.size()==1,"74ms burst remains inside debounce window")
	controlled.now_ms+=1;controlled.cue("select")
	check(controlled.events.count("select")==2,"Next valid input is audible at 75ms boundary")
	check(controlled.voices.filter(func(v):return v.playing).size()==1,"Accepted interface cue replaces previous tail instead of stacking")
	controlled.now_ms+=75;controlled.cue("ui")
	check(controlled.events.back()=="ui" and controlled.voices.filter(func(v):return v.playing).size()==1,"UI and region sounds share one audible slot")
	controlled.queue_free();await process_frame
	var app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await process_frame
	app.settings.set_value("app","sound",true);app.show_screen("region")
	var map:RegionSelection=app.region_selection
	var audio:DemoSoundscape=app.audio
	var before_save:String=JSON.stringify(app.model.state)
	await create_timer(.65).timeout
	check(audio.bgm.playing,"Approved music plays in A303")
	check(audio.bgm.stream.mix_rate==44100 and audio.bgm.stream.loop_end==2268000,"Approved full-quality master has exact 24-bar loop")
	check(audio.bgm.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD,"Music loops in one persistent playback")
	var music:AudioStreamWAV=audio.bgm.stream
	check(music.format==AudioStreamWAV.FORMAT_16_BITS and music.data.size()>=(music.loop_end+1)*4,"PCM loop endpoint has allocated stereo interpolation guard")
	check(music.data.slice(music.loop_end*4,music.loop_end*4+4)==music.data.slice(0,4),"Loop endpoint guard matches the next periodic frame")
	check(audio.bgm.volume_db==audio.REGION_MUSIC_DB,"Music fades to intended foreground level")
	check(audio.river.playing and not audio.wind.playing,"Region uses only one quiet water bed")
	await create_timer(1.0).timeout
	check(audio.river.volume_db<=-25,"Water remains well below music")
	var position_before:float=audio.bgm.get_playback_position()
	var stream_before:AudioStream=audio.bgm.stream
	audio.events.clear();audio.stop_effects()
	var burst_started:=Time.get_ticks_msec()
	for i in 18:
		map.select_region(["jeongok","amsa","dongsam"][i%3])
		if "--slow-selection-review" in OS.get_cmdline_user_args():OS.delay_msec(12)
	var burst_elapsed:=Time.get_ticks_msec()-burst_started
	check(audio.events.count("select")>=1 and audio.events.count("select")<=1+floori(float(burst_elapsed)/audio.INTERFACE_GAP_MS) and not audio.events.has("ui"),"Real region handler stays rate-limited without duplicate UI cue on slow or fast hosts")
	check(map.selected=="dongsam" and audio.voices.filter(func(v):return v.playing and v.stream in [audio.streams.ui,audio.streams.select]).size()<=1,"Latest region wins and interface voices never overlap")
	await create_timer(.35).timeout
	check(audio.bgm.stream==stream_before and audio.bgm.get_playback_position()>position_before,"Region changes preserve music stream and position")
	check(not is_instance_valid(map.details.ghost),"Audio-enabled rapid selection leaves no panel ghost")
	position_before=audio.bgm.get_playback_position()
	map.pose(1.4,Vector2(-130,-60)*map.factor);app.relayout();map=app.region_selection
	await create_timer(.15).timeout
	check(audio.bgm.get_playback_position()>position_before,"Relayout and zoom do not restart music")
	map.restore();await create_timer(.55).timeout
	check(audio.bgm.get_playback_position()>position_before,"Explicit map reset retains music")
	audio.bird_wait=0;audio.events.clear();await process_frame;await process_frame
	check(audio.events.count("bird")==1,"Quiet bird cue is scheduled in A303")
	check(audio.bird_wait>=21.9 and audio.bird_wait<=36,"Bird calls are sparse and irregular")
	var bird_voices:=audio.voices.filter(func(v):return v.playing and v.stream==audio.streams.bird)
	check(bird_voices.size()==1 and bird_voices[0].volume_db==-20,"Bird cue is bounded below the music")
	app.show_about();audio.bird_wait=0;audio.events.clear();await create_timer(.2).timeout
	check(not audio.events.has("bird") and audio.bgm.playing,"Modal holds new bird calls while preserving music")
	app.close_modal();await process_frame
	var paused_at:float=audio.bgm.get_playback_position()
	app._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
	var wait_before:float=audio.bird_wait
	await create_timer(.2).timeout
	check(audio.bgm.stream_paused,"Background pauses music instead of restarting it")
	check(absf(audio.bgm.get_playback_position()-paused_at)<.12,"Background preserves playback position")
	check(not audio.river.playing and not audio.wind.playing and audio.voices.all(func(v):return not v.playing),"Background silences all ambience and effects")
	check(audio.bird_wait==wait_before,"Background freezes bird schedule")
	app._notification(MainLoop.NOTIFICATION_APPLICATION_RESUMED);await create_timer(.2).timeout
	check(not audio.bgm.stream_paused and audio.bgm.get_playback_position()>paused_at,"Resume continues existing music")
	app.settings.set_value("app","sound",false);app.sync_audio();audio.events.clear();map.select_region("amsa");await create_timer(.1).timeout
	check(audio.bgm.stream_paused and not audio.river.playing and audio.events.is_empty(),"Sound setting silences music, water and selection")
	app.settings.set_value("app","sound",true);app.sync_audio();await create_timer(.1).timeout
	audio.bgm.seek(audio.bgm.stream.get_length()-.12);await create_timer(.35).timeout
	check(audio.bgm.playing and audio.bgm.get_playback_position()<audio.bgm.stream.get_length()*.5,"Music wraps its real playback boundary without stopping")
	var title_position:float=audio.bgm.get_playback_position()
	app.show_screen("title");await create_timer(.65).timeout
	check(audio.bgm.playing and audio.bgm.get_playback_position()>title_position,"Title preserves the same advancing region BGM player")
	check(not audio.river.playing and not audio.wind.playing,"Title stops region-only ambience")
	audio.configure(true,true,false,false,false);await create_timer(.65).timeout
	check(not audio.bgm.playing and not audio.river.playing and not audio.wind.playing,"Leaving both menu screens fades music out and stops region ambience")
	check(JSON.stringify(app.model.state)==before_save,"Music and decoration never change game progress")
	app.queue_free();await process_frame;await process_frame
	var report:={"checks":checks,"failed":failed,"utc":Time.get_datetime_string_from_system(true),"scope":"Engine playback/lifecycle regression; user listening and device checks remain separate"}
	FileAccess.open("res://reports/a303-audio-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report));quit(0 if failed.is_empty() else 1)
