extends SceneTree

var failures:=0
func _initialize()->void:
	call_deferred("run")

func check(result:bool, label:String)->void:
	print(label,": ",result)
	if not result:failures+=1

func run()->void:
	create_timer(85.0).timeout.connect(func():quit(89))
	if not "han-motion-qa" in OS.get_user_data_dir():quit(90);return
	var app
	var viewer
	if OS.get_cmdline_user_args().has("--direct"):
		viewer=load("res://battlefield_reset/han_motion/han_motion_viewer.gd").new()
		viewer.size=Vector2(960,540)
		root.add_child(viewer)
		await process_frame
	else:
		app=load("res://scenes/main.tscn").instantiate()
		root.add_child(app)
		await process_frame
		app.application_active=true
		app.model.start_new({},true)
		await app.enter_game()
		await process_frame
		if app.modal:app.close_modal()
		app.find_child("GahuiLabEntry",true,false).pressed.emit()
		await process_frame
		await process_frame
		app.parry_lab.find_child("OneOnOneEntry",true,false).pressed.emit()
		await process_frame
		await process_frame
		var previous=app.parry_lab
		previous.set_process(false)
		previous._render_actors()
		var han=previous.han_ultra
		check(is_instance_valid(han) and han.duel_model.is_visible_in_tree() and han.rig.get_bone_count()==24,"Actual 1:1 uses visible Ultra rig")
		var visited:Dictionary={}
		for k in 720:
			previous.advance(1./120.)
			if is_instance_valid(han):visited[han.duel_active_key]=true
			if previous.rules.hp[1]<previous.rules.full_hp(1):break
		check(previous.rules.hp[1]<previous.rules.full_hp(1) and visited.has("clear_basic"),"Actual Ultra basic displays during real collision damage")
		var entry=previous.find_child("HanMotionEntry",true,false)
		check(is_instance_valid(entry),"Main → Gahui → actual 1:1 → Han motion")
		if not is_instance_valid(entry):quit(1);return
		entry.pressed.emit()
		await process_frame
		await process_frame
		viewer=app.parry_lab
	check(viewer.setup_ok and viewer.rig.get_bone_count()==24 and viewer.ap.has_animation("idle_02_11"),"Ultra rig and native Idle_02")
	check(viewer.action_buttons.size()==18 and viewer.group_buttons.size()==3,"18 actions, 3 touch groups")
	for g in 3:
		viewer._set_group(g)
		var shown:=0
		for i in viewer.action_buttons:
			if i.visible:shown+=1
		check(shown==6,"group %d contains 6 actions"%g)
	for n in range(1,19):
		await viewer._pick(n)
		check(viewer.selected==n and not viewer.busy,"Select and complete motion %02d"%n)
	check(viewer.grip_samples>=2 and viewer.max_grip_error<.001 and viewer.max_09_grip_error<.001,"09/10 real grip checks")
	if is_instance_valid(app):
		viewer.field.exit_requested.emit()
		await process_frame
		await process_frame
		check(is_instance_valid(app.parry_lab) and app.parry_lab!=viewer and app.parry_lab.rules.ally_id=="hangyeol","Viewer returns to original 1:1")
		app.go_back()
		await process_frame
		check(not is_instance_valid(app.parry_lab) and app.screen=="play","Back restores village")
	print("HAN 1:1 MOTION failures=",failures)
	quit(failures)
