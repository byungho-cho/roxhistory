extends SceneTree
var app:Node
var failed:Array[String]=[]
var checks:=0
func _initialize()->void:root.unfocusable=true;call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failed.append(message);push_error(message)
func frames(n:int=3)->void:
	for i in n:await physics_frame;await process_frame
func tap(at:Vector2)->void:app.world_tap(app.world.get_global_transform_with_canvas()*at)
func run()->void:
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames()
	app.start_region();await frames()
	for a in app.world.animals:a.set_physics_process(false)
	for r in app.world.residents:r.set_physics_process(false)
	var state:Dictionary=app.model.state.duplicate(true);state.wood=3;state.stone=3;app.model.commit(state)
	check(not app.world.show_candidates,"Candidates hidden until hut choice")
	app.construction_menu();check(app.modal,"Build opens hut chooser")
	var choices=app.overlay.find_children("*","Button",true,false)
	for b in choices:
		if b.text=="움집 선택":b.pressed.emit();break
	check(app.choosing_plot and app.world.show_candidates and not app.modal,"Hut choice reveals candidates")
	var before:Vector2=app.world.player.position
	tap(DemoConfig.BUILD_SITES[3]);check(app.task=="build" and app.navigation.action=="","Remote construction begins without travel")
	await frames(12)
	check(app.world.player.position.distance_to(before)<1,"Hero remains still during construction")
	check(app.world.feedback.preview.visible,"Construction scaffold retained")
	app.navigation.start("move","",Vector2(1150,900))
	check(app.task=="build" and app.pending_action.kind=="move","Movement queues without cancelling build")
	app.navigation.start("move","",Vector2(1080,980))
	check(app.pending_action.at==Vector2(1080,980),"Latest destination replaces reservation")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/queue-building.png")
	while app.task!="":await frames(1)
	await frames()
	check(app.model.built_count()==1 and app.model.state.wood==2,"Build commits once")
	check(app.navigation.action=="move" and app.pending_action.is_empty(),"Reserved move starts after commit")
	app.cancel_task()
	var target:Vector2=app.world.art_nodes.wood_1.position
	app.world.player.position=target+Vector2(0,35);await frames()
	app.gather_action("wood_1");check(app.task=="gather","Gather starts")
	app.navigation.start("move","",Vector2(1150,900))
	var accepted:Dictionary=app.pending_action.duplicate(true)
	check(app.task=="gather" and accepted.has("path"),"Gather retains work and shows planned path")
	tap(Vector2(1200,450))
	check(app.task=="gather" and app.pending_action==accepted,"Invalid water tap preserves accepted reservation")
	while app.task!="":await frames(1)
	await frames()
	check(app.model.state.wood==3 and app.navigation.action=="move","Gather commits once then travels")
	app.cancel_task();app.world.player.position=Vector2(1150,900);await frames()
	app.gather_action();check(app.navigation.action=="gather" or app.task=="gather","Gather button finds local resource")
	app.cancel_task();app.world.select_site(4);app.build_action()
	app.reserve_action({"kind":"move","at":Vector2(1150,900)})
	app.joystick.value=Vector2.RIGHT;await frames(2);app.joystick.clear()
	check(app.task=="" and app.pending_action.is_empty() and app.navigation.action=="","Joystick cancels work and reservation")
	check(app.model.built_count()==1 and app.model.state.stone==2,"Cancelled build spends nothing")
	app.world.select_site(4);app.build_action();app.reserve_action({"kind":"gather","id":"missing-resource"})
	while app.task!="":await frames(1)
	await frames()
	check(app.task=="" and app.pending_action.is_empty() and app.toast_label.text.contains("사라"),"Missing queued target clears with explanation")
	var reload:=GameState.new(app.model.store)
	check(reload.built_count()==2 and reload.state.stone==1,"Completed work survives reload")
	app.world.select_site(5);app.build_action();app.reserve_action({"kind":"move","at":Vector2(1150,900)})
	app._notification(Node.NOTIFICATION_APPLICATION_PAUSED);app._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(app.task=="" and app.pending_action.is_empty() and app.model.built_count()==2,"Lifecycle cancels transient work without duplicate commit")
	for rock in SceneStyle.PAINTED_ROCKS:
		var pose:Transform2D=app.world.player.transform;pose.origin=rock+Vector2(0,-8)
		check(app.world.player.test_move(pose,Vector2.ZERO,null,.08,true),"Painted rock blocks movement "+str(rock))
	for side in ["behind","front"]:
		app.world.player.position=Vector2(1780,850)+Vector2(38,-30 if side=="behind" else 45)
		app.world.player.resume_camera();await frames(20)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://reports/queue-tree-"+side+".png")
	app.toast("자원 안내",2);app._process(.01)
	for kind in ["wood","stone","tokens"]:check(not app.toast_panel.get_global_rect().intersects(app.chrome.slot(kind)),"Toast does not cover "+kind)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/queue-hud.png")
	app.cancel_task();app.start_region();await frames()
	state=app.model.state.duplicate(true);state.wood=3;state.stone=3;app.model.commit(state)
	app.world.select_site(3);app.build_action();app.choosing_plot=true;tap(DemoConfig.BUILD_SITES[4])
	check(app.task_site==3 and int(app.pending_action.id)==4,"Second plot queues without moving the active scaffold")
	var limit:=320
	while (app.task!="" or not app.pending_action.is_empty()) and limit>0:await frames(1);limit-=1
	check(limit>0 and app.model.built_count()==2 and app.model.state.wood==1,"Queued construction starts after first and charges independently once")
	check(app.model.home_position(0)==DemoConfig.BUILD_SITES[3] and app.model.home_position(1)==DemoConfig.BUILD_SITES[4],"Both queued builds retain chosen plot")
	FileAccess.open("res://reports/action-queue-tests.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("ACTION_QUEUE ",checks," ",failed);quit(0 if failed.is_empty() else 1)
