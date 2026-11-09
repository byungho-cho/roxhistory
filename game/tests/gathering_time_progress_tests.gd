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
	app.model=GameState.new(SaveStore.new("user://gather_time_%s"%Time.get_ticks_usec()));app.model.start_new();app.enter_game();await frames(15);app.set_process(false)
	var construction:ConstructionProgress=app.stage.get_node("ConstructionTimeProgress")
	check(not app.stage.has_node("GatheringTimeProgress"),"No duplicate upper gathering bar")
	for kind in ["wood","stone"]:
		var target:Dictionary={}
		for node in app.model.nodes():
			if node.kind==kind:target=node;break
		var indicator:ResourceIndicator=app.world.resource_labels[target.id]
		check(indicator.bar_time==0,"Idle indicator hidden")
		check(app.model.claim_gather(target.id,"resident-0"),"Resident reserves the source")
		await frames(2)
		var sprite:Sprite2D=app.world.art_nodes[target.id].get_child(0)
		check(indicator.reserved_by_other and sprite.self_modulate.a<1,"Reserved source displays the lock and dims before a click")
		app.model.release_gather("resident-0")
		await frames(2)
		check(not indicator.reserved_by_other and sprite.self_modulate==Color.WHITE,"Released source clears the lock and restores its appearance")
		app.world.player.position=DemoConfig.point(target.position)+Vector2(30,30)
		app.gather_action(str(target.id))
		check(app.task=="gather" and indicator.kind==kind and not app.task_bar.visible,"Gather uses the small resource indicator")
		app.world.feedback.update_work(app.task_total*.5,app.task_total)
		check(indicator.bar_time>0 and is_equal_approx(indicator.action_progress,.5),"Small bar shows actual gathering progress")
		if "--capture-gather" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute("res://reports/gather-time")
			root.get_texture().get_image().save_png("res://reports/gather-time/"+kind+".png")
		var paid:int=app.model.state[kind]
		app.finish_task()
		check(indicator.bar_time==0 and app.model.state[kind]>paid,"Completion awards resources and clears the indicator")
		app.gather_action(str(target.id))
		app.world.feedback.update_work(app.task_total*.5,app.task_total)
		app.cancel_task()
		check(indicator.bar_time==0,"Cancellation clears the indicator")
	app.task="build";app.task_total=2;app.task_remaining=1;construction._process(0)
	check(construction.visible,"Construction keeps its own timer")
	app.cancel_task()
	print(JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
