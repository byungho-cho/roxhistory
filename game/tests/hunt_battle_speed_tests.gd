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

func run()->void:
	app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.model.start_new({},true)
	await app.enter_game()
	await frames(30)
	var h=await enter(0)
	if not is_instance_valid(h):quit(91);return
	check(h.speed==1.0 and not h.speed_button.visible and h.speed_button.disabled,"1-1 opens at true 1x and X2 remains locked")
	var started:=0.0
	var deer_started:=0.0
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
	h=await enter(1)
	if not is_instance_valid(h):quit(92);return
	var squad=h.chapter_story_battle
	check(h.speed==1.0 and not h.speed_button.visible and squad.story_encounter.seconds==50,"1-2 uses 1x, locked X2 and original time limit")
	before=squad.elapsed
	var sp_before:float=squad.units[0].sp
	await frames(60)
	check(absf(squad.elapsed-before-2.0)<.05 and absf((50.0-before)-(50.0-squad.elapsed)-2.0)<.05,"1-2 existing 50s fight timer drains two seconds in two real seconds")
	check(absf(float(squad.units[0].sp)-sp_before-2.0/3.1)<.04,"1-2 retains existing SP charge per simulation second at real 1x")
	h=await enter(3)
	if not is_instance_valid(h):quit(93);return
	squad=h.chapter_story_battle
	check(h.speed==1.0 and h.speed_button.visible and not h.speed_button.disabled,"1-4 retains the existing X2 unlock")
	await tap(h.speed_button.get_global_rect().get_center())
	check(h.speed==2.0,"real X2 touch sets exactly 2x, not 3x")
	before=squad.elapsed
	sp_before=squad.units[0].sp
	await frames(30)
	check(absf(squad.elapsed-before-2.0)<.05,"1-4 X2 advances about two simulation seconds per real second")
	check(absf(float(squad.units[0].sp)-sp_before-2.0/3.1)<.04,"1-4 X2 still advances the same SP rate in simulation time")
	await tap(h.speed_button.get_global_rect().get_center())
	check(h.speed==1.0,"second X2 touch restores 1x in the same battle")
	before=squad.elapsed
	await frames(25)
	check(absf(squad.elapsed-before-25.0/30.0)<.06,"combat clocks really revert to 1x, not just the UI")
	app.queue_free()
	await frames(7)
	print("RESULT ",checks-failures,"/",checks)
	quit(failures)
