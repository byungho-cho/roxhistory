extends SceneTree
var app
var scene
var errors:=0
var do_movie:=false
func _initialize() -> void:
	call_deferred("_run")
func ck(ok:bool,message:String)->void:
	print("CHECK ",ok," ",message)
	if not ok:errors+=1
func frames(count:int)->void:
	for i in count:await process_frame
func get_button(node:Node,key:String)->Control:
	return node.find_child(key,true,false) as Control
func tap(control:Control)->void:
	var pos:=control.get_global_rect().get_center()
	var event:=InputEventScreenTouch.new()
	event.index=0
	event.position=pos
	event.pressed=true
	root.push_input(event,true)
	await process_frame
	event=InputEventScreenTouch.new()
	event.index=0
	event.position=pos
	event.pressed=false
	root.push_input(event,true)
	await process_frame
func open(stage_id:int,cleared:int)->void:
	app.model.state.hunt_cleared=cleared
	app.hunt_stage=stage_id
	app.show_screen("hunt_select")
	await frames(20)
	app.prepare_selected_hunt()
	for i in 1500:
		await process_frame
		if is_instance_valid(app.hunt) and app.hunt.arrival_finished:
			scene=app.hunt
			break
		OS.delay_usec(900)
	await frames(15)
func force_outcome(hunt:Node,state:String)->void:
	hunt.rules.outcome=state
	hunt.rules.hunter_hp=20 if state=="win" else 0
	hunt.show_result()
	await frames(10)
func _run()->void:
	do_movie="--movie" in OS.get_cmdline_user_args()
	app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.model.start_new({},true)
	await app.enter_game()
	await frames(35)
	await open(0,0)
	var h=scene
	if not is_instance_valid(h):
		ck(false,"closed before first preparation")
		quit(1)
		return
	ck(h.preparation.is_visible_in_tree() and h.placement_grid.is_visible_in_tree(),"legitimate preparation before start")
	h.start_combat()
	ck(h.branch_video.visible and not h.preparation.visible and not h.placement_grid.visible,"synchronous initial cover")
	var frame_count:=0
	var prep_flash:=false
	var transition_gap:=false
	var played_flame:=false
	while frame_count<250 and not h.running:
		prep_flash=prep_flash or (h.preparation.is_visible_in_tree() and h.preparation.modulate.a >0) or (h.placement_grid.is_visible_in_tree() and h.placement_grid.modulate.a>0)
		transition_gap=transition_gap or not h.branch_video.visible or h.branch_video.background.modulate.a<.99
		if h.branch_video.clock>1.3 and h.branch_video.clock<3.0:played_flame=played_flame or h.branch_video.title_sprite.visible or (not do_movie and h.branch_video.flame_layer.visible)
		frame_count+=1
		await process_frame
	print("MEASURE start->live frames=",frame_count," wall at 30fps=",frame_count/30.0)
	ck(not prep_flash and not transition_gap,"no prep flash or unowned vs-to-live render frame")
	ck(h.running and h.combat_layout and not h.branch_video.visible and h.combat.is_visible_in_tree() and is_equal_approx(h.combat.modulate.a,1.0) and is_equal_approx(h.approach,1.0),"first post-VS frame is fully dressed live combat")
	ck(frame_count in [103,104,105] and played_flame,"VS 3.45 seconds with visible approved title or fallback")
	ck(is_equal_approx(h.speed,1.5) and not h.battle_toggles_unlocked,"1-1 active 1.5x and X2 still locked")
	var t:float=h.manual_combat_clock
	var deer_fx:=false
	var hit_seen:=false
	for i in 60:
		await process_frame
		deer_fx=deer_fx or not h.prey_dust.is_empty() or not h.prey_wake.is_empty() or h.prey_charge_progress>=0.0 or h.manual_effects.any(func(fx): return fx.kind=="prey_hit")
		hit_seen=hit_seen or (h.hit_on_hunter and h.hit_damage>0)
	ck(absf(h.manual_combat_clock-t-3.0)<.07, "two real seconds produce three live combat seconds")
	for i in 110:
		await process_frame
		deer_fx=deer_fx or not h.prey_dust.is_empty() or not h.prey_wake.is_empty() or h.prey_charge_progress>=0.0 or h.manual_effects.any(func(fx): return fx.kind=="prey_hit")
		hit_seen=hit_seen or (h.hit_on_hunter and h.hit_damage>0)
	ck(not deer_fx and hit_seen,"deer basic still hits, dedicated attacker visuals removed")
	await force_outcome(h,"win")
	var left:=get_button(h,"ResultStageSelect")
	var next:=get_button(h,"ResultNextStage")
	var back:=get_button(h,"ResultBackToVillage")
	ck(is_instance_valid(left) and is_instance_valid(next) and is_instance_valid(back),"win exposes selector, next and village back")
	var fill:=get_button(h,"ResultViewportBackdrop")
	ck(is_instance_valid(fill) and fill.get_global_rect().size.is_equal_approx(root.get_visible_rect().size),"transparent shade covers the real battlefield viewport")
	var shade := fill as ColorRect
	ck(h.ground.visible and h.ground.texture.resource_path.ends_with("/clearing-dirt.png") and h.ground.get_global_rect().grow(1.0).encloses(root.get_visible_rect()) and shade.color.a < 0.35 and not shade.get_child_count(),"original battlefield under a translucent shade; no extended scenery or cached plate")
	var motion := get_button(h,"ConfirmedResultMotion") as VideoStreamPlayer
	ck(is_instance_valid(motion) and motion.material is ShaderMaterial and motion.stream != null,"success uses foreground-only motion")
	var details := get_button(h,"ResultDetails")
	ck(is_instance_valid(details) and left.get_parent()==details and motion.position.x<0.0 and motion.scale.x>0.0 and left.get_global_rect().position.x>root.get_visible_rect().get_center().x and root.get_visible_rect().encloses(next.get_global_rect()),"success motion is shifted left without mirroring; right-side buttons fit the viewport")
	if do_movie:
		await frames(55)
		if fill:
			var im:=root.get_texture().get_image()
			im.save_png(OS.get_environment("APPDATA").path_join("RoxHistory-Hunt-Result-4x3.png"))
		await frames(42)
		root.get_texture().get_image().save_png(OS.get_environment("APPDATA").path_join("RoxHistory-Hunt-Result-Final-4x3.png"))
	var prior:int=app.hunt_stage
	await tap(next)
	var selector_flash:=false
	for i in 700:
		selector_flash=selector_flash or app.screen=="hunt_select"
		if app.screen=="hunt" and app.hunt_stage==prior+1 and app.hunt!=h and app.hunt.arrival_finished:break
		await process_frame
	print("NEXT observed ",app.screen," ",app.hunt_stage," ready=",app.hunt_preparing)
	ck(not selector_flash and app.hunt_stage==1 and app.hunt.preparation.visible and not app.hunt.running,"next touch enters 1-2 preparation directly; no selector or auto-start")
	if do_movie:await frames(45)
	h=app.hunt
	await force_outcome(h,"loss")
	ck(get_button(h,"ResultNextStage")==null and get_button(h,"ResultRetry")!=null,"loss never offers next and preserves retry")
	motion = get_button(h,"ConfirmedResultMotion") as VideoStreamPlayer
	ck(is_instance_valid(motion) and motion.material is ShaderMaterial and motion.stream != null,"failure uses foreground-only motion")
	var retry := get_button(h,"ResultRetry")
	ck(motion.position.x<0.0 and motion.scale.x>0.0 and retry.get_global_rect().position.x>root.get_visible_rect().get_center().x and root.get_visible_rect().encloses(retry.get_global_rect()),"failure uses the same left actor and right controls inside the safe layout")
	if do_movie:
		await frames(58)
		root.get_texture().get_image().save_png(OS.get_environment("APPDATA").path_join("RoxHistory-Hunt-Loss-4x3.png"))
		await frames(43)
		root.get_texture().get_image().save_png(OS.get_environment("APPDATA").path_join("RoxHistory-Hunt-Loss-Final-4x3.png"))
	await tap(get_button(h,"ResultBackToVillage"))
	await frames(8)
	ck(app.screen=="play" and is_instance_valid(app.world) and app.world.visible,"upper left back returns to village on touch")
	if not do_movie:
		await open(3,4)
		h=scene
		ck(h.battle_toggles_unlocked and h.speed==1.5,"1-4 default 1.5 and button unlocked")
		h.toggle_speed()
		ck(h.speed==2.0,"X2 means exactly 2x, not 3x")
		h.toggle_speed()
		ck(h.speed==1.5,"turning X2 off restores default 1.5x")
		await force_outcome(h,"win")
		await tap(get_button(h,"ResultStageSelect"))
		await frames(8)
		ck(app.screen=="hunt_select" and app.hunt_stage==3,"bottom left opens selector and keeps current selection")
		await open(4,6)
		h=scene
		await force_outcome(h,"win")
		ck(get_button(h,"ResultNextStage")==null and get_button(h,"ResultStageSelect")!=null,"next does not skip unavailable visual slots")
		await open(11,12)
		h=scene
		await force_outcome(h,"win")
		ck(get_button(h,"ResultNextStage")==null and get_button(h,"ResultStageSelect")!=null,"last stage has safe selector fallback")
	await frames(4)
	app.queue_free()
	await frames(6)
	print("RESULT errors=",errors)
	quit(errors)

