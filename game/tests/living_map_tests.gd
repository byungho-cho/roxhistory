extends SceneTree
var checks:=0
var failed:Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:failed.append(message);push_error(message)
func snap(file:String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/"+file+".png")
func run() -> void:
	var app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await process_frame;app.show_screen("region")
	var map:RegionSelection=app.region_selection
	var initial_save:String=JSON.stringify(app.model.state)
	var initial_pan:=map.pan
	var ambience:=map.ambience
	check(ambience.get_index()<map.markers.get_index() and map.markers.get_index()<map.ui_root.get_index(),"Environment stays beneath every marker and UI")
	check(not ambience.is_processing_input() and not ambience.is_processing_unhandled_input(),"Decoration owns no gameplay or map input")
	check(ambience.glints.size()>=12 and ambience.glints.size()<=34,"Water sparkle population is bounded and nonempty")
	check(ambience.glints.all(func(point):return ambience.is_water(point)),"Every glint is on sampled blue water, not land")
	var fish_samples:=0
	for i in 3:
		for second in 20:
			var pose:=ambience.fish_pose(i,float(second))
			if pose.alpha>.1 and ambience.is_water(pose.at):fish_samples+=1
	check(fish_samples>=12,"Fish have visible water trajectories across staggered cycles")
	for key in RegionCatalog.REGIONS:
		map.select_region(key);await create_timer(.08).timeout
		var rect:=map.markers.artifact_rect(key)
		check(rect.end.y<map.map_point(key).y,"Selection lifts icon briefly: "+key)
		check(map.pan==initial_pan and map.zoom==1,"Selection leaves overview camera fixed: "+key)
		await create_timer(.25).timeout
		check(is_equal_approx(map.markers.artifact_rect(key).end.y,map.map_point(key).y),"Selected icon settles on its geographic pedestal: "+key)
		check(map.details.title_label.text==RegionCatalog.REGIONS[key].name and not is_instance_valid(map.details.ghost),"Latest panel content settles without stale layer: "+key)
		await snap("living-"+key)
	# Rapid input must not accumulate ghosts or allow an earlier close to hide a new selection.
	for i in 24:
		map.select_region(["jeongok","amsa","dongsam"][i%3])
		check(map.details.surface.find_children("PreviousRegionVisuals","Control",false,false).size()<=1,"Rapid selection has at most one outgoing layer #"+str(i))
	map.select_region("amsa");await create_timer(.3).timeout
	var empty:=Vector2(250,350)
	map.begin_pointer(0,empty);map.end_pointer(0,empty)
	check(not map.panel_visible and map.details.visible,"Close starts a visible fade with logical selection dismissed")
	check(not map.ui_hit(map.start_button.get_global_rect().get_center()) and map.start_button.mouse_filter==Control.MOUSE_FILTER_IGNORE and map.start_button.disabled,"Closing panel releases start-button touch immediately")
	await create_timer(.08).timeout;map.select_region("dongsam");await create_timer(.3).timeout
	check(map.details.visible and map.details.surface.modulate.a==1 and map.details.title_label.text=="동삼동","Reopen cancels old hide callback and displays latest region")
	map.select_region("amsa");map.cancel_input();await process_frame
	check(map.details.surface.position==Vector2.ZERO and not is_instance_valid(map.details.ghost) and map.fingers.is_empty(),"Input cancellation settles transitions without orphaned visuals")
	var time_before:=ambience.clock;var age_before:=map.markers.selection_age
	app.application_active=false;await create_timer(.25).timeout
	check(ambience.clock==time_before and map.markers.selection_age==age_before,"Inactive app freezes map decoration and selection pulse")
	app.application_active=true;await create_timer(.1).timeout
	check(ambience.clock>time_before and ambience.clock-time_before<.2,"Resume advances normally without a time jump")
	app.show_about();time_before=ambience.clock;await create_timer(.15).timeout
	check(ambience.clock==time_before,"Modal pauses decorative motion")
	app.close_modal()
	var button:DemoButton=map.ui_root.get_node("MapReset")
	var target_rect:=button.get_global_rect()
	var press:=InputEventScreenTouch.new();press.index=61;press.pressed=true;press.position=button.get_global_rect().get_center();root.push_input(press,true)
	await create_timer(.1).timeout
	check(button.art_feedback.scale.x<.99 and button.art_feedback.position.y>1,"Press visibly compresses and lowers button art")
	check(button.get_global_rect()==target_rect,"Press feedback never shrinks the touch target")
	button.clear();await process_frame
	check(button.art_feedback.scale==Vector2.ONE and button.art_feedback.position==Vector2.ZERO,"Cancel restores button art and input")
	app.settings.set_value("app","sound",true);app.sync_audio();app.audio.events.clear()
	button.pressed.emit();check(app.audio.events.count("ui")==1,"One reset press cues one existing UI sound")
	app.settings.set_value("app","sound",false);app.sync_audio();button.pressed.emit()
	check(app.audio.events.count("ui")==1,"Muted button emits no additional sound")
	await create_timer(.55).timeout
	check(JSON.stringify(app.model.state)==initial_save,"Map effects never mutate game progress or inventory")
	ambience.refresh_exclusions()
	for key in RegionCatalog.REGIONS:check(ambience.visibility_at(RegionCatalog.REGIONS[key].point)==0,"Environment avoids marker and label: "+key)
	ambience.clock=3;ambience.queue_redraw();await snap("living-overview")
	map.pose(1.7,Vector2(-330,-180)*map.factor);ambience.clock=6;ambience.queue_redraw();await snap("living-zoom")
	check(map.zoom==1.7,"Environment retains manual camera zoom")
	app.queue_free();await process_frame;await process_frame
	var report:={"checks":checks,"failed":failed,"utc":Time.get_datetime_string_from_system(true),"scope":"Native Godot; visual captures require separate review; not Android hardware"}
	FileAccess.open("res://reports/living-map-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failed.is_empty() else 1)
