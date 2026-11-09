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
	var timer:ConstructionProgress=app.stage.get_node("GatheringTimeProgress")
	var construction:ConstructionProgress=app.stage.get_node("ConstructionTimeProgress")
	check(not timer.visible,"Idle timer hidden")
	for kind in ["wood","stone"]:
		var target:Dictionary={}
		for node in app.model.nodes():
			if node.kind==kind:target=node;break
		app.world.player.position=DemoConfig.point(target.position)+Vector2(30,30)
		app.gather_action(str(target.id));timer._process(0)
		check(app.task=="gather" and timer.visible and not app.task_bar.visible,"Gather shows only target time bar")
		check(timer.hammer.texture==DemoArt.icon(kind),"Resource-specific symbol in timer")
		app.task_remaining=app.task_total*.5;timer._process(0)
		check(is_equal_approx(timer.fill.size.x,172),"Time fill follows elapsed half duration")
		for zoom in [DemoPlayer.MIN_ZOOM,DemoPlayer.MAX_ZOOM]:
			app.world.player.zoom_at(Vector2(app.w,app.h)*.5,zoom);timer._process(0)
			var world_zoom:float=app.world.get_global_transform_with_canvas().get_scale().x
			check(is_equal_approx(timer.scale.x,clampf(world_zoom*.85,.34,.68)*2.0/3.0),"Exactly two-thirds construction scale at zoom")
			check(timer.get_global_rect().position.x>=app.safe.x and timer.get_global_rect().end.x<=app.w-app.safe.x+1,"Time bar within horizontal bounds")
			check(timer.get_global_rect().position.y>=app.safe.y+90 and timer.get_global_rect().end.y<=app.h-app.safe.y-100+1,"Time bar within vertical bounds")
		var top_hud_clear:=true
		for hud in app.resident_panel.fixed_hud_rects():
			if hud.position.y<app.h*.4 and hud.intersects(timer.get_global_rect()):top_hud_clear=false
		check(top_hud_clear,"Gather time bar stays clear of the top HUD")
		if "--capture-gather" in OS.get_cmdline_user_args():
			await frames(12);await RenderingServer.frame_post_draw;DirAccess.make_dir_recursive_absolute("res://reports/gather-time")
			root.get_texture().get_image().save_png("res://reports/gather-time/"+kind+".png")
		app.gather_approach=true;timer._process(0);check(not timer.visible,"Approach has no time bar");app.gather_approach=false
		app.world_map_open=true;timer._process(0);check(not timer.visible,"World map hides timer");app.world_map_open=false
		var paid:int=app.model.state[kind];app.finish_task();timer._process(0)
		check(not timer.visible and app.model.state[kind]>paid,"Completion gives resource and removes time bar")
		app.gather_action(str(target.id));app.cancel_task();timer._process(0);check(not timer.visible,"Cancellation removes time bar")
	app.task="build";app.task_total=2;app.task_remaining=1;construction._process(0);timer._process(0)
	check(construction.visible and not timer.visible,"Construction keeps original separate representation")
	app.cancel_task()
	print(JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
