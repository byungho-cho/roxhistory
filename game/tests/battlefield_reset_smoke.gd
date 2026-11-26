extends SceneTree
var failed := 0
var checked := 0
func _initialize() -> void: call_deferred("run")
func ck(ok: bool, name: String) -> void:
	checked += 1
	if not ok: failed += 1
	print(("PASS " if ok else "FAIL ") + name)
func run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	ck("RoxHistory-Battlefield-Reset" in OS.get_user_data_dir(),"isolated reset save")
	app.model.start_new({},true)
	app.application_active = true
	await app.enter_game()
	for i in range(15): await process_frame
	if app.modal: app.close_modal()
	app.model.state["guided_intro"] = false
	app.open_hunt()
	for i in range(8): await process_frame
	ck(app.screen=="battlefield_reset","normal village hunt opens only rebuild 1-1")
	var field = app.stage.get_node_or_null("FirstHunt")
	if not field:
		quit(2)
		return
	field.set_process(false)
	ck(not field.art_failed and field.han_anim != null and field.deer_anim != null,"Han and deer loaded with animation players")
	ck(field.han_anim.has_animation("clear_basic") and field.deer_anim.has_animation("req046_basic_attack"),"approved animation clips available")
	var original: Vector3 = field.han.position
	field.formation_button.pressed.emit()
	ck(not original.is_equal_approx(field.han.position),"placement changes the starting slot")
	field.start_button.pressed.emit()
	for i in range(240):
		if field.phase == 2:break
		field._process(0.02)
	ck(field.phase==2 and field.han.position.distance_to(field.deer.position)<1.17,"walk to contact without overlap")
	for n in range(3):
		var before: int = field.deer_hp
		field.attack_button.pressed.emit()
		for i in range(600):
			if field.active_attacker==-1 and field.attack_gate <= 0.0:break
			field._process(0.01)
		ck(field.deer_hp == before-5,"one impact per Han attack")
	ck(field.phase==3 and field.deer_hp==0 and field.han_hp==20,"finish to victory")
	field.start_button.pressed.emit()
	ck(field.phase==0 and field.deer_hp==15 and field.han_hp==20,"retry restores initial state")
	field.start_button.pressed.emit()
	for i in range(10000):
		field._process(0.02)
		if field.phase==3:break
	ck(field.phase==3 and field.han_hp==0 and field.deer_hp==15,"finish to defeat")
	ck("hit_reaction" in field.played_clips and field.landed_hits == 7,"deer attack and hit motion executed")
	field.request_exit()
	for i in range(6): await process_frame
	ck(app.screen=="play","return to village")
	app.queue_free()
	await process_frame
	print("BATTLEFIELD_RESET ",checked-failed,"/",checked)
	quit(0 if failed==0 else 1)
