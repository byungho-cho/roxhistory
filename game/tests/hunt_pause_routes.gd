extends SceneTree
## Private regression utility: run against an isolated APPDATA, never the active save.

var app
var total := 0
var errors := 0

func _initialize() -> void:
	call_deferred("_run")

func ck(ok:bool,message:String)->void:
	total += 1
	print(("PASS " if ok else "FAIL ")+message)
	if not ok:errors+=1

func frames(count:int)->void:
	for i in count:await process_frame

func touch(at:Vector2, down:bool, pointer:=0, canceled:=false)->void:
	var event:=InputEventScreenTouch.new()
	event.index=pointer
	event.position=at
	event.pressed=down
	event.canceled=canceled
	root.push_input(event,true)

func tap(control:Control,pointer:=0)->void:
	var pos:=control.get_global_rect().get_center()
	touch(pos,true,pointer)
	await process_frame
	touch(pos,false,pointer)
	await process_frame

func find(node:Node,key:String)->Control:
	return node.find_child(key,true,false) as Control

func stage(stage_id:int)->Node:
	app.hunt_stage=stage_id
	app.show_screen("hunt_select")
	await frames(20)
	app.prepare_selected_hunt()
	for i in 1500:
		await process_frame
		if is_instance_valid(app.hunt) and app.hunt.arrival_finished:return app.hunt
		OS.delay_usec(900)
	return null

func live(hunt:Node)->bool:
	var start := find(hunt,"StartBattle")
	if start==null:return false
	await tap(start)
	for i in 10:
		if hunt.transition_elapsed>=0.: break
		await process_frame
	var middle:=root.get_visible_rect().get_center()
	touch(middle,true)
	await process_frame
	touch(middle,false)
	await frames(7)
	return hunt.running

func snapshot(hunt:Node)->Array:
	var state: Array=[hunt.manual_combat_clock,hunt.pose_clock,hunt.rules.party_hp.duplicate(),hunt.rules.deer_hp,hunt.rules.charges.duplicate(),hunt.zoom,hunt.pan,hunt.manual_pending.duplicate(true)]
	if is_instance_valid(hunt.chapter_story_battle):
		var squad = hunt.chapter_story_battle
		state.append([squad.elapsed,squad.story_entry_clock,squad.units.map(func(u):return [u.hp,u.sp,u.age,u.feet,u.move])])
	return state

func frame_image(file:String)->void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	var im := root.get_texture().get_image()
	ck(im.save_png(OS.get_environment("QA_T43").path_join(file+".png"))==OK,"native capture "+file)

func marker(name:String)->void:
	print("MOVIE ",name," frame=",Engine.get_frames_drawn())

func _run()->void:
	var safe:=OS.get_environment("APPDATA").replace("\\","/").to_lower()
	if not safe.contains("hunt-pause-qa") or not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(safe+"/"):
		quit(90)
		return
	var gfx := DisplayServer.get_name()!="headless"
	app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.model.start_new({},true)
	await app.enter_game()
	await frames(28)
	var h = await stage(0)
	if h==null:quit(91);return
	ck(not find(h,"HuntPause").is_visible_in_tree() and not find(h,"HuntRemainingTime").is_visible_in_tree(),"1-1 prep does not show combat pause and clock")
	app.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	app.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	ck(h.exit_popup==null and not h.running,"background during preparation shows no battle overlay")
	if not await live(h):quit(92);return
	var pause:=find(h,"HuntPause")
	var countdown:=find(h,"HuntRemainingTime") as Label
	ck(pause.is_visible_in_tree() and countdown.is_visible_in_tree() and countdown.text=="시간 제한 없음","real stage 1-1 explicitly has no time limit")
	var simulated:=Rect2(Vector2(49,17),h.size-Vector2(103,35))
	h._fit_hunt_chrome(simulated)
	ck(simulated.encloses(pause.get_global_rect()) and simulated.encloses(countdown.get_global_rect()) and countdown.get_global_rect().end.x<pause.get_global_rect().position.x,"time and pause fit within asymmetric mobile safe area")
	h.fit_layout()
	marker("solo-start")
	await frames(28 if gfx else 4)
	await frame_image("RoxHistory-308-1-1-Live")
	var p:=pause.get_global_rect().get_center()
	touch(p,true,0)
	touch(p,false,0,true)
	ck(h.exit_popup==null,"cancelled mobile pause touch opens nothing")
	var skill:Control=h.party_cards[0].hud.portrait_button
	var aimed:=skill.get_global_rect().get_center()
	touch(aimed,true,5)
	await tap(pause,1)
	if not is_instance_valid(h.exit_popup):quit(93);return
	var shade:=find(h,"BattlePauseDim") as ColorRect
	var resume:=find(h.exit_popup,"ContinueBattle")
	var end:=find(h.exit_popup,"ExitBattle")
	var frozen:=snapshot(h)
	marker("solo-overlay")
	touch(aimed,false,5)
	ck(h.exit_popup.z_index > 2000 and shade.get_global_rect().is_equal_approx(h.get_global_rect()) and absf(shade.color.a-.33)<.001,"dim at 33% covers whole real viewport above HUD and join layers")
	var bottom_anchor:Rect2=h.party_cards[0].hud.portrait_button.get_global_rect()
	var actual_exit:=end.get_global_rect()
	var actual_resume:=resume.get_global_rect()
	ck(resume.size.is_equal_approx(Vector2(134,44)) and end.size.is_equal_approx(resume.size) and is_equal_approx(actual_exit.position.y,actual_resume.position.y) and actual_exit.end.x<actual_resume.position.x and is_equal_approx(actual_exit.end.y,bottom_anchor.position.y-8.0*h.canvas.scale.y),"Exit and Continue side by side, 8px above the actual bottom portrait")
	ck(is_equal_approx((actual_exit.position.x+actual_resume.end.x)*.5,bottom_anchor.get_center().x),"button row centered on actual bottom HUD")
	app.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	app.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await frames(20)
	ck(not quit_on_go_back and h.exit_popup!=null and snapshot(h)==frozen,"repeated actual WM_BACK event does not dismiss, advance or quit; held skill discarded")
	var at := resume.get_global_rect().get_center()
	touch(at,true,3)
	touch(at,false,3,true)
	ck(h.exit_popup!=null,"cancelled continue does not resume")
	await frame_image("RoxHistory-Mini-Pause-Above-Solo-HUD")
	await frames(24 if gfx else 1)
	await tap(resume)
	await frames(15)
	ck(h.exit_popup==null and h.manual_combat_clock>float(frozen[0]),"only gold Continue resumes same real 1-1")
	app.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	var by_back:Variant=h.exit_popup
	ck(is_instance_valid(by_back),"first Android Back uses same overlay as pause touch")
	var held_continue := find(by_back,"ContinueBattle").get_global_rect().get_center()
	touch(held_continue,true,6)
	app.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	ck(not app.application_active and h.exit_popup==by_back,"background event reuses already-open overlay")
	app.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	touch(held_continue,false,6)
	ck(h.exit_popup==by_back,"Continue pressed before leaving app cannot resume on stale release")
	var background_frozen:=snapshot(h)
	await frames(15)
	ck(app.application_active and h.exit_popup==by_back and snapshot(h)==background_frozen,"return does not auto-resume or catch up")
	await tap(find(by_back,"ContinueBattle"))
	app.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var auto:Variant=h.exit_popup
	ck(is_instance_valid(auto) and not app.application_active,"screen-off lifecycle opens overlay without manual pause")
	app.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	marker("solo-background")
	await frames(22 if gfx else 3)
	var back_button:=find(auto,"PauseBackToHuntSelect")
	ck(back_button.get_global_rect().is_equal_approx(h.exit_button.get_global_rect()),"pause overlay backs the real top-left arrow location")
	await tap(back_button)
	ck(app.screen=="hunt_select","paused top-left arrow returns to hunt selection on a single click")
	marker("solo-finished")
	app.model.state.hunt_cleared=1
	h=await stage(1)
	if h==null:quit(94);return
	if not await live(h):quit(95);return
	marker("timed-start")
	countdown=find(h,"HuntRemainingTime") as Label
	pause=find(h,"HuntPause")
	ck(countdown.text=="00:50","1-2 starts from the encounter's real 50 second limit")
	var start_text:=countdown.text
	await frames(35)
	ck(countdown.text!=start_text and countdown.text=="00:%02d"%ceili(50.-float(h.chapter_story_battle.elapsed)-.00001),"1-2 clock matches the running squad simulation at existing fight speed")
	await tap(pause)
	marker("timed-overlay")
	frozen=snapshot(h)
	var digits:=countdown.text
	await frames(39)
	ck(snapshot(h)==frozen and countdown.text==digits,"full second paused, same timer digits and same squad combat state")
	var timed_anchor:Rect2=h.chapter_story_battle.huds[0].portrait_button.get_global_rect()
	var timed_exit:=find(h.exit_popup,"ExitBattle")
	ck(is_equal_approx(timed_exit.get_global_rect().end.y,timed_anchor.position.y-8.0*h.canvas.scale.y),"1-2 uses the visible squad backend HUD rather than hidden tutorial placeholders")
	await frame_image("RoxHistory-Mini-Pause-Above-HUD-Countdown")
	await tap(find(h.exit_popup,"ContinueBattle"))
	await frames(35)
	ck(h.exit_popup==null and countdown.text!=digits and h.chapter_story_battle.elapsed>float(frozen[8][0]),"1-2 Continue ticks timer from frozen value and rules resume")
	marker("timed-finished")
	h.chapter_story_battle.elapsed=49.98
	await frames(6)
	ck(h.result_shown and h.rules.outcome=="loss" and not countdown.visible and not pause.visible,"actual 1-2 timeout still leads to existing defeat with no paused combat controls")
	h=await stage(1)
	if h==null:quit(96);return
	if not await live(h):quit(97);return
	await tap(find(h,"HuntPause"))
	var immediate_exit:=find(h.exit_popup,"ExitBattle")
	var area:=immediate_exit.get_global_rect().get_center()
	touch(area,true,6)
	await frames(2)
	ck(app.screen=="hunt","pressing before release does not accidentally exit")
	touch(area,false,6)
	await frames(2)
	ck(app.screen=="hunt_select","one deliberate Exit release immediately returns to stage selection without any confirmation")
	app.queue_free()
	await frames(8)
	print("RESULT ",total-errors,"/",total)
	quit(errors)
