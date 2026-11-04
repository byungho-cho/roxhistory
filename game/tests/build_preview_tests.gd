extends SceneTree
var app:Node
var checks:=0
var failed:Array[String]=[]
var measurements:Array=[]
func _initialize()->void:root.unfocusable=true;call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failed.append(message);push_error(message)
func frames(n:int=3)->void:
	for i in n:await physics_frame;await process_frame
func select(id:int)->void:
	app.choosing_plot=true;app.world.show_candidates=true
	app.world_tap(app.world.get_global_transform_with_canvas()*DemoConfig.BUILD_SITES[id])
func snap(name:String)->void:
	await frames();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/preview-"+name+".png")
func run()->void:
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames()
	app.start_region();await frames()
	for a in app.world.animals:a.set_physics_process(false)
	for r in app.world.residents:r.set_physics_process(false)
	var next:Dictionary=app.model.state.duplicate(true);next.wood=4;next.stone=4;app.model.commit(next)
	var saved:String=JSON.stringify(app.model.state)
	select(3);await frames()
	check(app.build_preview.visible and app.task=="","Candidate opens preview without building")
	check(JSON.stringify(app.model.state)==saved,"Preview changes no stored state or resource")
	var y:float=app.build_preview.ghost.position.y;await frames(12)
	check(absf(y-app.build_preview.ghost.position.y)>.1,"Preview has subtle vertical motion")
	check(app.build_preview.ghost.find_children("*","StaticBody2D",true,false).is_empty(),"Ghost has no collision")
	await snap("open")
	app.toggle_menu();await frames()
	check(not app.gather_button.visible and app.build_button.visible and app.menu_toggle.visible,"Compact menu keeps build and expand available")
	await snap("closed")
	for i in 10:app.toggle_menu()
	check(not app.menu_expanded and app.build_preview.site_id==3,"Repeated fold leaves preview intact")
	app.toggle_menu();await frames()
	select(4);check(app.build_preview.site_id==4 and JSON.stringify(app.model.state)==saved,"Reselect is ephemeral")
	app.cancel_build_preview();check(not app.build_preview.visible and not app.choosing_plot and JSON.stringify(app.model.state)==saved,"Cancel leaves no saved changes")
	select(3);app.confirm_build_preview();app.confirm_build_preview()
	check(app.task=="build" and app.task_site==3 and app.model.built_count()==0,"Confirm starts exactly one remote build")
	select(4);check(app.pending_action.is_empty(),"Unconfirmed candidate is not queued")
	app.confirm_build_preview();check(app.pending_action.get("id",-1)==4 and app.task_site==3,"Confirmed second plot queues without moving active build")
	select(5);app.cancel_build_preview();check(app.pending_action.get("id",-1)==4,"Cancelled preview preserves prior valid reservation")
	while app.task!="" or not app.pending_action.is_empty():await frames(1)
	check(app.model.built_count()==2 and app.model.state.wood==2,"Two confirmed builds spend once each")
	select(5);app._notification(Node.NOTIFICATION_APPLICATION_PAUSED);app._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(not app.build_preview.visible and app.pending_action.is_empty() and app.model.built_count()==2,"Pause discards preview and reservation")
	select(5);app.confirm_build_preview()
	while app.task!="":await frames(1)
	check(app.objective.text.contains("씨앗을 받아"),"Unclaimed reward guidance shown")
	for i in 3:app.claim_home(i)
	var tokens:int=app.model.state.tokens
	check(app.objective.text.contains("모두 받았"),"Claimed reward guidance corrected")
	for i in 3:app.claim_home(i)
	check(app.model.state.tokens==tokens,"Repeated reward tap grants nothing")
	var reload:=GameState.new(app.model.store)
	check(reload.state.tokens==tokens and not reload.reward_pending(2),"Reward status survives reload")
	app.show_screen("title");await frames()
	var horn:Control=app.stage.get_node("SoundToggle")
	for child in horn.find_children("*","TextureRect",true,false):
		if child is TextureRect and child.name!="HornShadow":
			check(is_equal_approx(child.size.x,176*.54*2*.7*minf(app.w/1600,app.h/900)),"Horn visual exactly 0.7 of v32")
			measurements.append({"horn_visual_logical":child.size.x,"horn_touch_logical":horn.size.x})
	await snap("title")
	app.enter_game();await frames()
	check(app.objective.text.contains("모두 받았"),"Reentry retains correct reward guidance")
	for size in [Vector2i(896,370),Vector2i(816,616),Vector2i(540,960)]:
		root.size=size;await frames(10)
		for expanded in [true,false]:
			app.menu_expanded=expanded;app.apply_menu_state();await frames()
			var previous:=Rect2()
			for b in app.action_row.get_children():
				if not b.visible:continue
				check(b.size.x>=44 and b.size.y>=44,"Touch minimum "+str(size)+b.text)
				check(not b.get_global_rect().intersects(previous),"Distinct menu targets "+b.text)
				check(Rect2(Vector2.ZERO,Vector2(app.w,app.h)).encloses(b.get_global_rect()),"Menu within viewport "+b.text)
				previous=b.get_global_rect()
			measurements.append({"viewport":str(size),"expanded":expanded,"menu":str(app.action_row.get_global_rect())})
			await snap(str(size.x)+"-"+str(expanded))
	FileAccess.open("res://reports/build-preview-tests.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"measurements":measurements},"  "))
	print("BUILD_PREVIEW ",checks," ",failed);quit(0 if failed.is_empty() else 1)
