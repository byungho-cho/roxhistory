extends SceneTree
var checks:=0
var failures:Array[String]=[]
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures.append(message);push_error(message)
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
	for i in n:await process_frame
func run()->void:
	var app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames(5)
	app.model=GameState.new(SaveStore.new("user://recorded_audio_%s"%Time.get_ticks_usec()));app.model.start_new();app.enter_game();await frames(12);app.set_process(false)
	app.settings.set_value("app","sound",true)
	var audio:DemoSoundscape=app.audio;audio.configure(true,true,true,false)
	for key in ["wood","stone","build","demolish"]:
		var stream:AudioStreamWAV=audio.streams["recorded_"+key]
		check(stream.mix_rate==48000 and not stream.stereo and stream.get_length()<1,"Approved short PCM interval loaded")
		check(stream.loop_mode==AudioStreamWAV.LOOP_DISABLED,"No automatic loops")
		audio.cue(key);check(audio.recorded_work.playing and audio.recorded_work.stream==stream,"Correct approved selection plays")
		check(audio.recorded_work.pitch_scale==1.0,"No pitch resynthesis")
	for i in 20:audio.cue("wood")
	check(audio.recorded_work.playing and audio.voices.filter(func(v):return v.get_meta("work",false) and v.playing).is_empty(),"Rapid work cues share one voice, no pool stacking")
	audio.stop_work();check(not audio.recorded_work.playing,"Cancel/completion stops work tail")
	audio.cue("stone");audio.configure(false,true,true,false);check(not audio.recorded_work.playing,"Sound off stops current work")
	var count:=audio.events.size();audio.cue("wood");check(audio.events.size()==count,"Sound off suppresses new cues")
	audio.configure(true,true,true,false);check(not audio.recorded_work.playing,"Sound on does not replay old cue")
	audio.cue("build");audio.configure(true,false,true,false);check(not audio.recorded_work.playing,"Background stops work")
	audio.configure(true,true,true,false);check(not audio.recorded_work.playing,"Foreground does not duplicate prior work")
	audio.cue("wood");audio.configure(true,true,true,true);check(not audio.recorded_work.playing,"Popup stops work tail")
	audio.configure(true,true,true,false)
	app.world.selected_site=0;app.world.site.position=DemoConfig.BUILD_SITES[0]
	for duration in [2.0,16.0]:
		audio.events.clear();app.world.feedback.begin("build")
		for tick in int(duration*10):app.world.feedback.update_work((tick+1)*.1,duration)
		var phrases:=audio.events.filter(func(e):return e=="recorded_build").size()
		check(phrases>=1 and phrases<=2 if duration==2 else phrases>=3 and phrases<=5,"Build uses sparse short/long cadence")
		app.cancel_task();check(not audio.recorded_work.playing,"Finishing build clears playback")
	check(app.model.build(Vector2.ZERO,0),"Demolition fixture built")
	app.model.claim_home(0) if app.model.has_method("claim_home") else app.model.claim_reward()
	var key:String=app.model.home_key(0)
	app.show_demolition_confirmation(key);audio.events.clear();app.confirm_demolition(key)
	check("recorded_demolish" in audio.events and not "recorded_build" in audio.events,"Actual demolition uses approved building-one source")
	print(JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
