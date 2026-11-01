extends SceneTree
var checks:=0
var failed:Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:failed.append(message);push_error(message)
func capture(name:String) -> Image:
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var img:=root.get_texture().get_image();img.save_png("res://reports/"+name+".png");return img
func run() -> void:
	var app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await process_frame;app.show_screen("region")
	await create_timer(.6).timeout
	var map:RegionSelection=app.region_selection
	map.ambience.set_process(false);map.markers.set_process(false)
	var panel:=map.details;panel.finish_motion()
	var save_before:String=JSON.stringify(app.model.state)
	await capture("panel-open")
	panel.surface.modulate.a=.01
	var transparent:=await capture("panel-zero-alpha")
	panel.hide()
	var hidden:=await capture("panel-hidden")
	var different_pixels:=0
	for y in transparent.get_height():
		for x in transparent.get_width():
			var a:=transparent.get_pixel(x,y);var b:=hidden.get_pixel(x,y)
			if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))>.035:different_pixels+=1
	check(different_pixels==0,"Near-transparent panel leaves no opaque shadow or icon residue")
	panel.set_shown(true,false)
	map.select_region("jeongok");await create_timer(.06).timeout
	var outgoing_alpha:=panel.content.modulate.a
	var outgoing_position:=panel.content.position
	map.select_region("dongsam")
	check(is_instance_valid(panel.ghost) and is_equal_approx(panel.ghost.modulate.a,outgoing_alpha),"Rapid selection does not flash outgoing content back to opaque")
	check(is_instance_valid(panel.ghost) and panel.ghost.position.is_equal_approx(outgoing_position),"Rapid selection preserves outgoing visual position")
	await create_timer(.3).timeout
	for key in ["jeongok","dongsam","amsa"]:
		map.select_region(key);await create_timer(.05).timeout
		map.panel_visible=false;panel.set_shown(false)
		check(not panel.shown and panel.current_key==key,"Closing preserves latest region and dismissed state: "+key)
		check(panel.start_button.disabled and panel.start_button.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Closing panel cannot receive start input: "+key)
		await create_timer(.06).timeout
		map.select_region("amsa");await create_timer(.3).timeout
		check(panel.visible and panel.surface.modulate.a==1 and panel.surface.position==Vector2.ZERO,"Interrupted close reopens without stale hide or offset: "+key)
		check(panel.title_label.text=="암사동" and not is_instance_valid(panel.ghost),"Reopened content has only latest region: "+key)
	map.panel_visible=false;panel.set_shown(false);await create_timer(.25).timeout
	check(not panel.visible,"Close finishes completely")
	map.select_region("amsa");await create_timer(.25).timeout
	check(panel.visible and not panel.start_button.disabled,"Normal reopen restores playable region")
	check(JSON.stringify(app.model.state)==save_before,"Panel transitions never change game progress")
	app.queue_free();await process_frame
	var report:={"checks":checks,"failed":failed,"near_zero_alpha_residual_pixels":different_pixels,"utc":Time.get_datetime_string_from_system(true)}
	FileAccess.open("res://reports/panel-transition-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failed.is_empty() else 1)
