extends SceneTree
var app
var checks:=0
var failures:=0
var evidence={}
var out="D:/workspace/roxhistory/build/d0070-282/"
func _initialize():call_deferred("run")
func check(ok:bool,why:String):
 checks+=1
 if not ok:failures+=1;push_error(why)
func wait_for(predicate:Callable,limit:float)->bool:
 var deadline=Time.get_ticks_msec()+limit*1000
 while not predicate.call() and Time.get_ticks_msec()<deadline:await process_frame
 return predicate.call()
func run():
 app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await process_frame
 app.settings.set_value("app","intro_bgm",9)
 check(app.intro_track_index()==0,"invalid saved music falls back to default1")
 app.settings.erase_section_key("app","intro_bgm")
 check(app.intro_track_index()==0,"first execution defaults to approved1")
 app.settings.set_value("app","sound",true);app.settings.set_value("app","bgm",true);app.settings.set_value("app","sfx",true)
 app.settings.set_value("app","bgm_volume",100);app.settings.set_value("app","sfx_volume",100)
 app.cover_intro(app.prepare_intro,true)
 check(await wait_for(func():return app.screen=="intro" and not app.intro_preparing and is_instance_valid(app.intro_audio),8),"actual intro cover/preparation/first frame completes")
 if not is_instance_valid(app.intro_audio):quit(1);return
 var timeline=app.intro_audio
 check(app.intro_player.stream.resource_path==app.INTRO_VIDEO_PATH,"new silent visual selected")
 check(timeline.players.size()==2 and app.stage.find_children("*","AudioStreamPlayer",true,false).size()==2,"only two stem voices, no legacy music")
 check(timeline.players[0].stream.resource_path==app.INTRO_BGM_PATHS[0] and timeline.players[1].stream.resource_path==app.INTRO_SFX_PATH,"provided stems are the active players")
 check(app.stage.find_child("IntroMusicChoice",true,false)!=null and app.intro_track_index()==0,"approved music selector restored with default1")
 check(await wait_for(func():return timeline.players[0].playing and timeline.players[1].playing,2),"both stems start on first playback")
 app.audio.scene_music_players["title"].play();app.sync_audio()
 check(not app.audio.scene_music_players["title"].playing and not app.audio.bgm.playing,"old title/region music cannot overlap candidate")
 var sfx_starts=timeline.starts[1]
 for wanted in [1,0]:
  var before=app.intro_player.stream_position
  app.cycle_intro_music();await create_timer(.15).timeout
  check(app.intro_track_index()==wanted and timeline.players[0].stream.resource_path==app.INTRO_BGM_PATHS[wanted],"music 1→2→1 selects exact approved WAV")
  check(app.intro_player.stream_position>=before and timeline.starts[1]==sfx_starts,"music selection never resets video or effects")
  check(absf(timeline._audible_seconds(0)-app.intro_player.stream_position)<.12,"new BGM starts at current video position")
 var mix=db_to_linear(timeline.players[0].volume_db+AudioServer.get_bus_volume_db(AudioServer.get_bus_index("BGM")))
 check(absf(mix-1.0)<.001,"default intro gain matches authored reference instead of applying scene attenuation again")
 var starts=timeline.starts.duplicate()
 app.settings.set_value("app","bgm_volume",0);app.settings.set_value("app","sfx_volume",37);app.sync_audio();await create_timer(.2).timeout
 var bgm=AudioServer.get_bus_index("BGM");var sfx=AudioServer.get_bus_index("SFX")
 check(AudioServer.is_bus_mute(bgm) and not AudioServer.is_bus_mute(sfx),"BGM mute independent from effects")
 check(absf(db_to_linear(AudioServer.get_bus_volume_db(sfx))-.37)<.001,"effects volume follows existing slider")
 app.settings.set_value("app","sound",false);app.sync_audio();await create_timer(.2).timeout
 check(AudioServer.is_bus_mute(bgm) and AudioServer.is_bus_mute(sfx),"master mute covers both streams")
 check(timeline.starts==starts,"changing mute/volume does not restart audio")
 app.settings.set_value("app","sound",true);app.settings.set_value("app","bgm_volume",100);app.settings.set_value("app","sfx_volume",100);app.sync_audio()
 app._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED);await create_timer(.2).timeout
 var paused_time=app.intro_player.stream_position
 check(not timeline.players[0].playing and not timeline.players[1].playing and app.intro_player.paused,"background pauses video and stops both stems")
 await create_timer(.3).timeout
 check(absf(app.intro_player.stream_position-paused_time)<.02,"video time frozen in background")
 app._notification(MainLoop.NOTIFICATION_APPLICATION_RESUMED);await create_timer(.25).timeout
 check(timeline.players[0].playing and timeline.players[1].playing and not app.intro_player.paused,"resume restarts both at frozen video time")
 var points=[]
 for at in [6.0,12.0,17.0]:
  check(await wait_for(func():return app.intro_player.stream_position>=at,20),"reference landmark reached at "+str(at))
  var video=app.intro_player.stream_position
  var cursors=[timeline._audible_seconds(0),timeline._audible_seconds(1)]
  var errors=[absf(cursors[0]-video),absf(cursors[1]-video)]
  points.append({"landmark":at,"video":video,"audio":cursors,"absolute_error":errors})
  check(maxf(errors[0],errors[1])<.12,"both audio clocks within 120ms of video landmark")
  await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"intro-%d.png"%at)
 var start_counts=timeline.starts.duplicate()
 check(await wait_for(func():return timeline.starts[0]>start_counts[0] and app.intro_player.stream_position<1,18),"full video loop restarts both stems")
 check(timeline.starts[0]-start_counts[0]==1 and timeline.starts[1]-start_counts[1]==1,"repeat starts both streams together")
 app.cycle_intro_music()
 var stored=ConfigFile.new();check(stored.load(app.prefs_path)==OK and stored.get_value("app","intro_bgm")==1,"music2 persisted to preferences")
 var before_state=JSON.stringify(app.model.state)
 app.finish_intro(true)
 check(not timeline.players[0].playing and not timeline.players[1].playing,"skip stops both audio voices immediately")
 check(await wait_for(func():return app.screen=="title" and not app.intro_leaving,4),"skip returns to existing title flow")
 check(JSON.stringify(app.model.state)==before_state,"intro and skip do not change gameplay state")
 # The default skip still uses the existing post-intro chapter/village route.
 app.model=load("res://scripts/game_state.gd").new(load("res://scripts/save_store.gd").new("user://qa-d0070-empty-route"))
 app.cover_intro(app.prepare_intro,true)
 check(await wait_for(func():return app.screen=="intro" and not app.intro_preparing,6),"second entry prepares a fresh candidate playback")
 var second=app.intro_audio
 check(second.players[0].stream.resource_path==app.INTRO_BGM_PATHS[1],"reentry retains explicitly selected music2")
 check(second.players.size()==2 and app.stage.find_children("*","AudioStreamPlayer",true,false).size()==2,"re-entry does not accumulate voices")
 app.finish_intro()
 check(not second.players[0].playing and not second.players[1].playing,"default skip also stops both stems immediately")
 check(await wait_for(func():return app.screen=="chapter" and not app.intro_leaving,6),"default skip reaches existing chapter selection with empty progress")
 evidence={"checks":checks,"failures":failures,"points":points,"audio_starts":start_counts,"device":"Windows source runtime, Dummy driver and simulated Android lifecycle; no physical Android device"}
 FileAccess.open(out+"intro-integration.json",FileAccess.WRITE).store_string(JSON.stringify(evidence,"  "))
 print("D0070 actual intro: ",checks," checks, ",failures," failures")
 # Let title preloads finish before shutting down the GUI test process.
 for path in app.intro_preload_paths.duplicate():
  await wait_for(func():return ResourceLoader.load_threaded_get_status(path)!=ResourceLoader.THREAD_LOAD_IN_PROGRESS,5)
 app.preload_intro_assets()
 await RenderingServer.frame_post_draw
 app.queue_free();await process_frame;await create_timer(.4).timeout
 call_deferred("quit",1 if failures else 0)
