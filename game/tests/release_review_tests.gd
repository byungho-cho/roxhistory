extends SceneTree
var failed:Array[String]=[]
var checks:=0
var app:Node
func _initialize()->void:
	root.unfocusable=true
	call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failed.append(label);push_error(label)
func snap(name:String)->void:
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/release-"+name+".png")
func run()->void:
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await process_frame
	app.settings.set_value("app","sound",true);app.show_screen("title");await create_timer(.4).timeout
	var horn:DemoButton=app.stage.get_node("SoundToggle")
	for state in ["normal","hover","pressed","focus"]:check(horn.get_theme_stylebox(state) is StyleBoxEmpty,"Horn has no background/border in "+state)
	check(horn.tooltip_text.is_empty() and horn.art_feedback!=null,"Horn keeps press feedback without PC tooltip")
	await snap("title")
	var music:AudioStreamPlayer=app.audio.bgm
	check(music.playing and not app.audio.play_bgm.playing,"Title plays selected region music, without second BGM")
	for i in 3:
		var before:=music.get_playback_position()
		app.show_screen("region");await create_timer(.2).timeout
		check(music.playing and music.get_playback_position()>before,"Title to region does not restart: "+str(i))
		before=music.get_playback_position();app.show_screen("title");await create_timer(.2).timeout
		check(music.playing and music.get_playback_position()>before,"Region to title does not restart: "+str(i))
	app._notification(Node.NOTIFICATION_APPLICATION_PAUSED);var paused:=music.get_playback_position();await create_timer(.2).timeout
	check(music.stream_paused and absf(music.get_playback_position()-paused)<.06,"Title background pauses music")
	app._notification(Node.NOTIFICATION_APPLICATION_RESUMED);await create_timer(.2).timeout
	check(not music.stream_paused and music.get_playback_position()>paused,"Title foreground resumes music position")
	app.settings.set_value("app","sound",false);app.sync_audio();check(music.stream_paused,"Title mute pauses music")
	app.show_screen("region");check(music.stream_paused,"Muted screen switch stays muted")
	var map:RegionSelection=app.region_selection
	var ground:=Vector2(app.w*.65,app.h*.18)
	check(not map.ui_hit(ground),"Test taps actual background")
	map.begin_pointer(0,ground);map.end_pointer(0,ground);await create_timer(.3).timeout
	check(map.panel_visible and map.details.visible,"Background tap keeps region card")
	var close:DemoButton=map.details.surface.get_node("CloseRegionDetails");close.pressed.emit();await create_timer(.3).timeout
	check(not map.panel_visible and not map.details.visible,"Explicit region close still works")
	map.select_region("amsa");await create_timer(.3).timeout
	check(map.panel_visible and map.details.visible,"Reselect reopens the card")
	for child in map.find_children("*","Control",true,false):check(child.tooltip_text.is_empty(),"No PC tooltip: "+child.name)
	await snap("region")
	app.start_region();app.close_modal();await process_frame
	app.model.gather("wood_1");app.model.gather("stone_1");app.model.build();await process_frame
	var box:Rect2=app.world.reward_marker_rect(0)
	check(box.get_center().x>app.world.homes[0].position.x,"Reward bubble sits right of hut")
	check(app.world.reward_hit(0,box.get_center()),"Offset bubble is inside reward touch target")
	await process_frame;await snap("reward-menu")
	app.world_tap(app.world.get_global_transform_with_canvas()*box.get_center())
	app.world_tap(app.world.get_global_transform_with_canvas()*box.get_center())
	check(app.model.state.tokens==10 and not app.model.reward_pending(0),"Bubble double tap claims once")
	app._notification(Node.NOTIFICATION_APPLICATION_PAUSED);app._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	var reload:=GameState.new(app.model.store)
	check(reload.state.tokens==10 and not reload.reward_pending(0),"Interrupted reward flight cannot lose or duplicate payout")
	var result:Dictionary={"checks":checks,"failed":failed,"runtime":"Windows Godot real mixer/render + synthetic input; not direct listening"}
	FileAccess.open("res://reports/release-review-tests.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print(JSON.stringify(result));quit(0 if failed.is_empty() else 1)
