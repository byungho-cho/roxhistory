extends SceneTree
## Real Main-route touch inputs and fixed real-frame timing; use a disposable save.
var app
var failures:=0
var checks:=0

func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1
	print(("PASS " if ok else "FAIL ")+label)
func frames(n:int)->void:
	for i in n:await process_frame
func touch(at:Vector2,down:bool)->void:
	var e:=InputEventScreenTouch.new()
	e.position=at
	e.pressed=down
	root.push_input(e,true)
func tap(at:Vector2)->void:
	touch(at,true)
	await process_frame
	touch(at,false)
	await process_frame

func enter(stage_id:int)->Node:
	app.model.state.hunt_cleared=stage_id
	app.hunt_stage=stage_id
	app.show_screen("hunt_select")
	await frames(20)
	app.prepare_selected_hunt()
	for i in 1500:
		await process_frame
		if is_instance_valid(app.hunt) and app.hunt.arrival_finished:break
		OS.delay_usec(900)
	var h=app.hunt
	if not is_instance_valid(h) or not h.arrival_finished:return null
	var start:=h.find_child("StartBattle",true,false) as Control
	await tap(start.get_global_rect().get_center())
	await tap(root.get_visible_rect().get_center())
	for i in 220:
		if h.running:return h
		await process_frame
	return null

func contains_speed_button(node:Node)->bool:
	if node is BaseButton and (node.get_meta("toggle_name","")=="X2" or node.tooltip_text=="X2"):return true
	for c in node.get_children():
		if contains_speed_button(c):return true
	return false

func run()->void:
	app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.model.start_new({},true)
	await app.enter_game()
	await frames(30)
	var h=await enter(0)
	if not is_instance_valid(h):quit(91);return
	check(h.speed==1.0 and not contains_speed_button(h),"1-1 opens at true 1x without an X2 control")
	var started:=0.0
	var deer_started:=0.0
	# The visible approach is now part of the live scene, but not its combat clock.
	for i in 90:
		if h.solo_deploy_clock<0.0:break
		await process_frame
	var before:float=h.manual_combat_clock
	var real_before:float=h.manual_input_clock
	for i in 61:
		await process_frame
		if started<=0.0 and h.pose=="auto_thrust":started=h.manual_input_clock
		if deer_started<=0.0 and h.first_hunt_deer_hit_pending:deer_started=h.manual_input_clock
	# One process_frame at the beginning of each sample brackets the same number of ticks.
	var advanced:float=h.manual_combat_clock-before
	var real:float=h.manual_input_clock-real_before
	check(absf(advanced-real)<.01 and absf(real-2.0)<.09,"1-1 simulation tracks about two real seconds without acceleration")
	print("MEASURE lead-in ",deer_started-started," (Han ",started,", deer ",deer_started,")")
	check(started>0.0 and absf(deer_started-started-.50)<=.035,"deer begins about .50 real seconds after Han")
	# Use the actual bottom HUD after a live hit, while a basic is active.
	var hud=h.party_cards[0].hud
	var waited:=0
	while not h._is_first_hunt_han_basic() and waited<80:
		await process_frame
		waited+=1
	check(h._is_first_hunt_han_basic(),"1-1 real ordinary thrust active before manual input")
	h.rules.charges[0]=2.0
	h.rules.resolve_independent_prey_basic(0)
	h.update_combat_ui()
	check(float(hud.portrait_feedback_material.get_shader_parameter("wound"))>.90 and not hud.portrait_button.disabled,"wounded portrait does not block charged 2SP input")
	var fight_clock:float=h.manual_combat_clock
	var foe_health:int=h.rules.deer_hp
	var actual_tap:Vector2=hud.portrait_button.get_global_rect().get_center()
	touch(actual_tap,true)
	touch(actual_tap,false)
	check(h.pose=="han_spear_2" and h.pose_clock==0.0 and h.rules.charges[0]==0.0 and h.manual_combat_clock==fight_clock,"1-1 visible wounded HUD touch begins Han 2SP in the same frame")
	check(h.rules.deer_hp==foe_health and h.impact_pending,"interrupted basic has not left a second impact")

	h=await enter(1)
	if not is_instance_valid(h):quit(92);return
	var squad=h.chapter_story_battle
	check(h.speed==1.0 and not contains_speed_button(h) and squad.story_encounter.seconds==50,"1-2 uses 1x, no X2 and original time limit")
	before=squad.elapsed
	var sp_before:float=squad.units[0].sp
	await frames(60)
	check(absf(squad.elapsed-before-2.0)<.05 and absf((50.0-before)-(50.0-squad.elapsed)-2.0)<.05,"1-2 existing 50s fight timer drains two seconds in two real seconds")
	check(absf(float(squad.units[0].sp)-sp_before-2.0/3.1)<.04,"1-2 retains existing SP charge per simulation second at real 1x")
	for stage_id in [2,3,4]:
		h=await enter(stage_id)
		if not is_instance_valid(h):quit(93);return
		squad=h.chapter_story_battle
		check(h.speed==1.0 and not contains_speed_button(h),"1-"+str(stage_id+1)+" opens at 1x with no X2 button")
		if stage_id>=3:check(h.auto_button.visible and not h.auto_button.disabled,"AUTO remains active from 1-4")
		h.speed=2.0
		await tap(h.auto_button.get_global_rect().get_center()+Vector2(0,57))
		check(h.speed==1.0,"old X2 target and stale 2x value cannot change the rate")
		before=squad.elapsed
		sp_before=squad.units[0].sp
		await frames(30)
		check(absf(squad.elapsed-before-1.0)<.05,"later actual combat countdown ticks one second per 30 real frames")
		check(absf(float(squad.units[0].sp)-sp_before-1.0/3.1)<.04,"later story still charges SP at the same 1x clock")
	app.queue_free()
	await frames(7)
	print("RESULT ",checks-failures,"/",checks)
	quit(failures)
