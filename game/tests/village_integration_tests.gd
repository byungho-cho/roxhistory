extends SceneTree
var app:Node
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:root.unfocusable=true;call_deferred("run")
func frames(n:int=3)->void:
	for i in n:await physics_frame;await process_frame
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures.append(message);push_error(message)
func run()->void:
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames()
	app.start_region();await frames(8)
	app.set_process(false)
	check(app.model.chief_level()==1 and app.model.home_limit()==1,"Fresh HQ1 has one home allowance")
	check(app.model.debug_unlimited_builders,"Unlimited builder testing starts on")
	var before:Dictionary=app.model.state.duplicate(true)
	app.build_kind="hut";app.world.select_site(0);app.build_action()
	check(app.task=="build" and app.model.construction_busy,"Construction reserves the single builder")
	check(app.building_workflow.upgrade_block_reason(2).is_empty(),"Default test mode allows HQ upgrade while construction uses one builder")
	app.show_development_settings()
	var restriction:CheckBox=app.overlay.find_child("UnlimitedBuildersToggle",true,false)
	check(restriction!=null and restriction.button_pressed,"Settings checkbox reflects the enabled default")
	if restriction:restriction.button_pressed=false
	check(not app.model.debug_unlimited_builders,"Settings checkbox enables the real one-builder limit")
	app.close_modal()
	check(not app.building_workflow.upgrade_block_reason(2).is_empty(),"Enabled restriction blocks simultaneous HQ upgrade")
	app.cancel_task();check(not app.model.construction_busy,"Cancel releases builder")
	check(app.model.state==before,"Cancelled construction spends nothing")
	app.world.select_site(0);app.set_process(true);app.build_action()
	var build_ticks:=0
	while app.task!="" and build_ticks<180:await frames(1);build_ticks+=1
	app.set_process(false)
	check(app.task=="" and app.model.built_count()==1,"Timed first construction completes through main workflow")
	check(not app.model.construction_busy,"Successful completion releases builder")
	check(app.model.resident_capacity()==1 and app.model.resident_count()==0,"HUD capacity excludes HQ and hero")
	check(not app.model.can_build(),"HQ1 refuses a second home")
	check(app.building_workflow.upgrade_block_reason(2).is_empty(),"HQ2 can be reached without outpost deadlock")
	app.building_workflow.request_upgrade()
	check(app.modal,"HQ upgrade asks in existing confirmation UI")
	check(app.building_workflow.confirm_upgrade(2),"Confirmed HQ upgrade starts")
	check(app.model.finish_chief_upgrade(float(app.model.state.chief_upgrade.finishes_at)),"HQ upgrade completes durably")
	check(app.model.home_limit()==2 and app.world.boundary_level==2,"HQ completion updates home limit and boundary")
	check(app.toast_label.text.contains("70%"),"HQ expansion explains new boundary")
	var key:String=app.model.home_key(0)
	check(app.building_workflow.owned_upgrade_reason(key).is_empty(),"HQ2 permits home upgrade to2")
	var family_fixture:Dictionary=app.model.state.duplicate(true);family_fixture.family_joined=true;family_fixture.family_unlocked=true
	app.model.commit(family_fixture);await frames()
	app.resident_panel.show_summary();check(app.modal,"Resident counter opens roster")
	var saved:Dictionary=app.model.state.duplicate(true)
	app.close_modal();check(app.model.state==saved,"Closing roster does not assign jobs")
	app.resident_panel.show_assignment(0)
	var assigned:=false
	for b in app.overlay.find_children("*","Button",true,false):
		if b.text=="나무꾼":b.pressed.emit();assigned=true;break
	check(assigned and not app.modal,"Job choice works through actual roster button")
	check(ResidentJobs.new(app.model).entry("resident-0").job=="wood","Assignment persists to stable resident ID")
	app.resident_panel.show_assignment(0);app.close_modal()
	check(ResidentJobs.new(app.model).entry("resident-0").job=="wood","Cancel picker preserves assignment")
	for dimensions in [Vector2i(1280,720),Vector2i(540,960),Vector2i(1920,720)]:
		root.size=dimensions;await frames(12)
		var previous:=Rect2()
		for kind in ["wood","stone","tokens","residents"]:
			var rect:Rect2=app.chrome.slot(kind)
			check(Rect2(Vector2.ZERO,Vector2(app.w,app.h)).encloses(rect),"Resource slot stays on screen: "+kind+str(dimensions))
			check(previous.size==Vector2.ZERO or not previous.intersects(rect),"Resource slots do not overlap: "+kind)
			previous=rect
		check(app.resident_panel.counter_button.size.y>=44,"Resident touch target is at least44px")
		check(ResidentJobs.new(app.model).entry("resident-0").job=="wood","Resize preserves job assignment")
		app.resident_panel.show_summary();app.close_modal();check(not app.modal,"Repeated roster open/close clears modal")
		app.resident_panel.show_assignment(0);await frames(3)
		for b in app.overlay.find_children("*","Button",true,false):
			check(Rect2(Vector2.ZERO,Vector2(app.w,app.h)).encloses(b.get_global_rect()),"Roster job button stays in viewport: "+b.text)
		app.close_modal()
	app.show_development_settings()
	var unlimited:CheckBox=app.overlay.find_child("UnlimitedBuildersToggle",true,false)
	check(unlimited!=null and not unlimited.button_pressed,"Reopening settings keeps the current checkbox state")
	if unlimited:unlimited.button_pressed=true
	check(app.model.debug_unlimited_builders,"Settings checkbox restores unlimited test mode")
	app.close_modal()
	app.model.debug_unlimited_builders=false
	check(GameState.new(app.model.store).debug_unlimited_builders,"Reload returns to unlimited test default")
	var result:={"checks":checks,"failures":failures,"environment":"Godot4.5.1 headless; geometry/input/state only; pixels and Android unverified"}
	FileAccess.open("res://reports/village-integration-tests.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print(JSON.stringify(result));app.queue_free();await frames();quit(0 if failures.is_empty() else 1)
