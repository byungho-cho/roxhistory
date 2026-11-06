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
	app.model=GameState.new(SaveStore.new("user://queued_lifecycle_%s"%Time.get_ticks_usec()));app.model.start_new();app.enter_game();await frames(15)
	app.set_process(false);app.navigation.set_physics_process(false)
	var icon:QueuedActionIndicator=app.queued_action_indicator;icon.set_process(false)
	var target:Dictionary={}
	for node in app.model.nodes():
		if node.kind=="wood":target=node;break
	var request:={"kind":"gather","id":str(target.id)}
	app.reserve_action(request);check(icon.visible and icon.phase=="queued","New reservation visible")
	for cycle in 3:
		icon._process(.17 if cycle==0 else .16);check(icon.modulate.a<.2,"Blink dim phase")
		icon._process(.16);check(icon.modulate.a==1,"Blink bright phase")
	icon._process(.4);check(icon.modulate.a==1,"Exactly three cycles then stable")
	app.run_reserved_action();icon.refresh()
	check(app.pending_action.is_empty() and icon.visible,"Dispatch clears queue but keeps receipt")
	check(app.navigation.action=="gather" or app.task=="gather","Reserved gather still dispatches normally")
	if app.navigation.action=="gather":
		icon._process(2);check(icon.visible and icon.hide_remaining<0,"Travel does not start hide timer")
		var generation:int=icon.generation
		app.cancel_task(true,true);app.navigation.action="gather";app.navigation.target=str(target.id);icon.refresh()
		check(icon.generation==generation and icon.visible,"Internal route retry retains receipt")
	app.navigation.cancel();app.world.player.position=DemoConfig.point(target.position)+Vector2(30,30)
	app.gather_action(str(target.id));icon.refresh()
	check(app.task=="gather" and icon.phase=="started" and icon.hide_remaining==1,"Countdown begins at actual gather start")
	icon._process(.6);check(icon.visible,"Icon survives first 0.6 seconds of gathering")
	var recreated:=QueuedActionIndicator.new(app)
	check(recreated.phase==icon.phase and is_equal_approx(recreated.hide_remaining,icon.hide_remaining),"HUD recreation retains active countdown")
	recreated.free()
	var old_generation:int=icon.generation
	app.reserve_action({"kind":"build","id":0})
	check(icon.icon_key=="hut" and icon.phase=="queued","New reservation immediately replaces receipt")
	icon.observe_dispatch(old_generation);icon._process(2)
	check(icon.visible and icon.icon_key=="hut" and icon.hide_remaining<0,"Old completion/timer cannot clear newer reservation")
	app.cancel_task();check(not icon.visible,"Explicit cancel clears newest receipt")
	app.reserve_action(request);app.run_reserved_action();icon.refresh();icon._process(.99)
	check(icon.visible,"Gather receipt present until one second")
	icon._process(.02);check(not icon.visible,"Gather receipt removed after one second")
	app.cancel_task();app.reserve_action({"kind":"gather","id":"missing"});app.run_reserved_action()
	check(not icon.visible,"Invalid target clears receipt")
	app.reserve_action({"kind":"move","at":Vector2(1000,800)});app.run_reserved_action();icon.refresh()
	check(icon.visible and app.navigation.action=="move","Move receipt persists along route")
	app.navigation.cancel();icon.refresh();check(not icon.visible,"Movement arrival or cancellation removes receipt")
	var state:Dictionary=app.model.state.duplicate(true);state.wood=40;state.stone=40;app.model.commit(state)
	app.reserve_action({"kind":"build","id":0});app.run_reserved_action();icon.refresh()
	check(app.task=="build" and icon.phase=="started","Construction countdown begins when construction starts")
	icon._process(1.01);check(not icon.visible,"Construction receipt hides after one second")
	app.cancel_task()
	app.reserve_action({"kind":"family","id":"first"});check(not icon.visible,"Unsupported family symbol remains absent")
	app.cancel_task()
	print(JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
