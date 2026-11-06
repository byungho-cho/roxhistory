extends SceneTree
var checks:=0
var failures:Array[String]=[]
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures.append(message);push_error(message)
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
	for i in n:await process_frame
func run()->void:
	var app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames(5)
	var store:=SaveStore.new("user://upgrade_visual_%s"%Time.get_ticks_usec())
	app.model=GameState.new(store);app.model.start_new();app.enter_game();await frames(15);app.set_process(false)
	var state:Dictionary=app.model.state.duplicate(true);state.wood=300;state.stone=300;app.model.commit(state)
	for site in [0,1,2]:app.model.build(Vector2.ZERO,site)
	app.model.build_outpost(Vector2.ZERO,3)
	var flow:BuildingWorkflow=app.building_workflow;flow.set_process(false)
	var progress:ConstructionProgress=app.stage.get_node("ChiefUpgradeProgress")
	var effects:UpgradeConstructionEffect=app.world.get_node("ChiefUpgradeEffects")
	for level in [2,3,4]:
		var duration:float=app.model.chief_upgrade_duration(level)
		check(app.model.upgrade_chief(Time.get_unix_time_from_system()-duration*.5),"Upgrade starts with existing persisted timing")
		progress._process(.1);effects._process(.1);flow.update_scaffold()
		check(progress.visible and effects.visible and flow.scaffold.visible,"Timer hammer scaffold and shared work effects visible")
		check(absf(progress.fill.size.x-160)<8,"Upgrade timer follows persisted wall-clock half progress")
		var angle:=progress.hammer.rotation;progress._process(.07);check(not is_equal_approx(angle,progress.hammer.rotation),"Existing hammer animation moves")
		check(effects.visibility_layer==2 and flow.scaffold.visibility_layer==2,"Upgrade effects excluded from GPS")
		app.task="gather";app.task_total=99;app.task_remaining=99;progress._process(0)
		check(progress.visible and progress.fill.size.x>150,"Upgrade timer independent of simultaneous gathering")
		app.task=""
		var reloaded:=GameState.new(store)
		check(reloaded.state.has("chief_upgrade") and reloaded.chief_upgrade_remaining()>0,"Pending upgrade survives reload")
		if "--capture-upgrade" in OS.get_cmdline_user_args():
			app.world.player.zoom_at(Vector2(app.w,app.h)*.5,1.6)
			await frames(8);await RenderingServer.frame_post_draw;DirAccess.make_dir_recursive_absolute("res://reports/upgrade-animation")
			root.get_texture().get_image().save_png("res://reports/upgrade-animation/stage-%d-working.png"%level)
		state=app.model.state.duplicate(true);state.chief_upgrade.started_at=Time.get_unix_time_from_system()-duration-1;state.chief_upgrade.finishes_at=Time.get_unix_time_from_system()-1;app.model.commit(state)
		flow._process(.01);progress._process(0);effects._process(0)
		check(app.model.chief_level()==level and not progress.visible and not effects.visible,"Completion removes active work indicators")
		check(is_instance_valid(flow.previous_visual) and app.world.get_node("ExistingHut").sprite.modulate.a==0,"Completion begins short old-to-new crossfade")
		await create_timer(.4).timeout;flow._process(.4)
		check(not flow.scaffold.visible and is_equal_approx(app.world.get_node("ExistingHut").sprite.modulate.a,1),"Transition completes with opaque new building")
		var completed:=GameState.new(store);check(completed.chief_level()==level and not completed.state.has("chief_upgrade"),"Completed upgrade reloads without duplicate job")
	print(JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
