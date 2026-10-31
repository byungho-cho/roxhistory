extends SceneTree
var app: Node
var checks := 0
var failed: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failed.append(message); push_error(message)
func frames(n: int) -> void:
	for i in n: await physics_frame; await process_frame
func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/p4-"+name+".png")
func wait_positioning() -> void:
	for tick in 120:
		if not app.gather_approach:break
		await frames(1)
	check(app.task=="gather" and not app.gather_approach,"Contact positioning finishes before testing the work sound timeline")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://reports")
	app = load("res://scenes/main.tscn").instantiate(); root.add_child(app); await frames(2)
	var audio: DemoSoundscape = app.audio
	var font: FontVariation = DemoArt.theme().default_font
	var weight := TextServerManager.get_primary_interface().name_to_tag("wght")
	check(font.variation_opentype.get(weight,0) == 600,"Numeric OpenType weight selects readable semibold instead of thin default")
	check(audio.voices.size() == 6,"Effect voice pool is bounded")
	for key in audio.streams:
		check(audio.streams[key].get_length() > 0.05,"Playable authored stream: "+key)
	app.settings.set_value("app","sound",true)
	app.show_screen("title"); await frames(24); await snap("title")
	check(not audio.river.playing,"No ambience on title")
	app.start_region(); app.close_modal(); app.world.player.set_character_3d(true); await frames(25)
	check(audio.river.playing and audio.wind.playing,"Single river and wind loops start in play")
	check(audio.river.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD,"River loops without queue/restart")
	var count := audio.get_child_count()
	for i in 8: app.sync_audio()
	check(audio.get_child_count() == count,"Repeated sync does not create duplicate players")
	var p: DemoPlayer = app.world.player
	p.position = Vector2(1360,830)
	p.position=app.world.gather_stand(Vector2(1420,830),"wood"); p.camera.reset_smoothing(); await frames(30)
	await snap("gather-ready")
	app.gather_action(); await frames(20)
	check(audio.events.any(func(e): return e.begins_with("wood_")),"Wood impact is synchronized to work phase")
	check(not audio.events.has("gain") and app.model.state.wood == 0,"No gain sound or inventory before commit")
	await snap("gather-impact")
	app.cancel_task()
	check(audio.voices.all(func(v): return not v.get_meta("work",false) or not v.playing),"Cancel stops in-flight work sounds")
	var after_cancel := audio.events.size(); await frames(30)
	check(audio.events.size() == after_cancel,"Cancelled work schedules no late sounds")
	audio.stop_effects(); app.gather_action(); await wait_positioning(); await frames(80)
	check(app.model.state.wood == 1 and audio.events.count("gain") == 1,"Successful committed gather cues once")
	p.position = Vector2(1360,1080); await frames(4); audio.stop_effects(); app.gather_action(); await wait_positioning(); await frames(80)
	check(audio.events.any(func(e): return e.begins_with("stone_")),"Stone has separate impact sound")
	check(app.model.state.stone == 1,"Stone commit remains one")
	p.position = Vector2(820,1060); await frames(4); app.build_action()
	app.overlay.get_child(1).get_child(0).get_child(2).get_child(1).pressed.emit()
	audio.stop_effects(); await frames(130)
	check(audio.events.any(func(e): return e.begins_with("build_")),"Construction has separate impact sound")
	check(app.model.state.built and audio.events.count("complete") == 1,"Completion sound follows one committed building")
	await snap("completion")
	var reward: DemoButton = app.overlay.get_child(1).get_child(0).get_child(2).get_child(0)
	audio.stop_effects(); reward.pressed.emit(); reward.pressed.emit(); await frames(2)
	check(app.model.state.tokens == 10 and audio.events.count("reward") == 1,"Repeated reward press has one reward cue")
	app.pause_game(); await frames(60)
	check(audio.ducked and audio.wind.volume_db <= -32,"Modal ducks ambience by at least 7dB from -25dB bed")
	app._notification(Node.NOTIFICATION_APPLICATION_PAUSED); await frames(2)
	check(not audio.river.playing and not audio.wind.playing and audio.voices.all(func(v): return not v.playing),"Background stops every audio player")
	app._notification(Node.NOTIFICATION_APPLICATION_RESUMED); app.close_modal(); await frames(30)
	check(audio.river.playing and audio.wind.playing and audio.get_child_count() == count,"Resume restarts one ambience pair")
	app.settings.set_value("app","sound",false); app.sync_audio(); var prior := audio.events.size(); audio.cue("wood")
	check(not audio.river.playing and audio.events.size() == prior,"Mute stops loops and suppresses new effects")
	app.settings.save(app.prefs_path)
	var restored := ConfigFile.new(); restored.load(app.prefs_path)
	check(not restored.get_value("app","sound",true),"Mute persists in preferences")
	# Physics camera follow, stop convergence and safe world framing.
	p.position = Vector2(1000,900); p.camera.reset_smoothing(); await frames(5)
	app.joystick.value = Vector2.RIGHT; await frames(18); app.joystick.clear()
	var target := p.position+p.camera.position
	var lag := p.camera.get_screen_center_position().distance_to(target)
	check(lag > 0.1 and lag < 70,"Smooth follow has bounded lag: "+str(lag))
	await frames(90)
	check(p.camera.get_screen_center_position().distance_to(p.position+p.camera.position)<2,"Camera settles after stop without drift")
	for size in [Vector2i(1280,720),Vector2i(896,370),Vector2i(816,616)]:
		root.size = size; await frames(15)
		var area := Rect2(Vector2.ZERO,Vector2(app.w,app.h))
		for kind in ["wood","stone","tokens"]:
			check(area.encloses(app.chrome.slot(kind)),"Resource cell fits "+kind+" "+str(size))
		check(area.encloses(app.gather_button.get_parent().get_global_rect()),"Action row fits "+str(size))
		app.toast("나무 1 · 돌 1 — 첫 보금자리 준비 완료",2); await frames(2)
		check(area.encloses(app.toast_panel.get_global_rect()),"Toast fits "+str(size))
		await snap(str(size.x)+"x"+str(size.y))
	app.show_screen("title"); await frames(2)
	check(not audio.river.playing,"Leaving world stops ambience")
	var report := {"checks":checks,"failed":failed,"utc":Time.get_datetime_string_from_system(true),"camera_lag_world_units":lag,"runtime":"Native render at fixed60 engine time; audio lifecycle/state checks, not a listening or Android test"}
	FileAccess.open("res://reports/presentation-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report)); quit(0 if failed.is_empty() else 1)
