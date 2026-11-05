extends SceneTree
var app:Node
var checks:=0
var failures:Array[String]=[]
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures.append(message);push_error(message)
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
	for i in n:await process_frame
func run()->void:
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames(5)
	var store:=SaveStore.new("user://asset_flow_%s"%Time.get_ticks_usec())
	app.model=GameState.new(store);app.model.start_new();app.enter_game();await frames(10)
	app.set_process(false)
	var state:Dictionary=app.model.state.duplicate(true);state.wood=300;state.stone=300;app.model.commit(state)
	app.build_side.select_outpost();check(not app.choosing_plot,"Locked outpost cannot enter placement")
	for site in [0,1,2]:check(app.model.build(Vector2.ZERO,site),"Completed fixture hut")
	app.build_side.select_outpost();check(app.choosing_plot and app.build_kind=="outpost","Fourth total hut unlocks outpost selection")
	app.build_preview.select(3)
	check(app.build_preview.ghost.sprite.texture==BuildingWorkflow.approved_texture("BLD-OUTPOST-L1"),"Outpost ghost uses supplied PNG")
	var before:Dictionary=app.model.state.duplicate(true)
	app.cancel_build_preview();check(app.model.state==before,"Cancel placement does not charge")
	await physics_frame
	check(app.world.site_available(3),"Chosen outpost plot is physically clear")
	app.build_side.select_outpost();app.build_preview.select(3);app.confirm_build_preview()
	check(app.task=="build" and app.task_build_kind=="outpost","Confirmation starts outpost construction")
	app.finish_task();await frames(3)
	check(app.model.outposts().size()==1 and app.model.built_count()==3,"Outpost completion separate from homes")
	check(app.model.state.wood==before.wood-15 and app.model.state.stone==before.stone-10,"Only exact outpost cost charged")
	var outpost:Node=app.world.get_node_or_null("Outpost_"+str(app.model.outposts()[0].uid)) if not app.model.outposts().is_empty() else null
	check(outpost!=null,"Completed outpost rendered")
	if outpost:
		check(outpost.visibility_layer==2 and outpost.get_child(0).visibility_layer==2,"Outpost excluded from natural-only GPS")
		check(outpost.get_child(1) is CollisionShape2D,"Outpost owns existing building footprint collision")
	check(not app.world.site_available(3),"Completed outpost occupies plot")
	for level in [2,3,4]:
		app.building_workflow.request_upgrade();check(app.modal,"Real stage asset opens upgrade confirmation")
		var paid:int=app.model.state.wood
		check(app.building_workflow.confirm_upgrade(level),"Upgrade starts")
		check(app.model.state.wood==paid-20,"Upgrade charges same 20 wood")
		var job:Dictionary=app.model.state.chief_upgrade
		check(job.finishes_at-job.started_at==pow(2,level),"Stage duration 4/8/16 seconds")
		check(not app.building_workflow.confirm_upgrade(level),"Duplicate confirmation rejected")
		state=app.model.state.duplicate(true);state.chief_upgrade.started_at=Time.get_unix_time_from_system()-20;state.chief_upgrade.finishes_at=Time.get_unix_time_from_system()-1;app.model.commit(state);app.building_workflow._process(.1)
		check(app.model.chief_level()==level,"Stage completes")
		check(app.world.get_node("ExistingHut").sprite.texture==BuildingWorkflow.approved_texture("BLD-CHIEF-L%d"%level),"Correct supplied atlas region displayed")
	check(not app.model.can_upgrade_chief(),"Level four is maximum")
	var restored:=GameState.new(store)
	check(restored.chief_level()==4 and restored.outposts().size()==1,"Actual completed asset state survives reload")
	print(JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
