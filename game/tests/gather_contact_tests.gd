extends SceneTree
var app: Node
var checks:=0
var failures: Array[String]=[]
var cases: Array[Dictionary]=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message);push_error(message)
func frames(n: int) -> void:
	for i in n: await physics_frame;await process_frame
func run() -> void:
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await process_frame
	app.start_region();app.close_modal()
	var p: DemoPlayer=app.world.player
	for entry in DemoConfig.get_data().nodes:
		var id: String=entry.id
		for index in (range(8) if id in ["wood_3","stone_2"] else [0,4]):
			app.cancel_task();app.model.start_new();app.close_modal();app.chrome.clear_effects();app.world.feedback.events.clear()
			var target: Node2D=app.world.art_nodes[id]
			p.position=target.position+Vector2.from_angle(index*TAU/8)*100
			await frames(3);app.gather_action()
			check(app.task=="gather","Reachable resource begins work from direction "+str(index))
			var ticks:=0;var contact_checked:=false
			while app.task!="" and ticks<180:
				await frames(1);ticks+=1
				if not contact_checked and app.world.feedback.events.has("impact:gather"):
					contact_checked=true
					var sprite: Sprite2D=target.get_child(0)
					var bounds: Rect2=sprite.get_global_transform()*sprite.get_rect()
					check(bounds.has_point(app.world.feedback.impact_point),"Tool head contacts visible resource bounds: "+id+" direction "+str(index))
					check(not p.work_destination.is_finite(),"Positioning ends before the first strike")
			var kind: String="wood" if id.begins_with("wood") else "stone"
			check(contact_checked and app.task=="" and app.model.state[kind]==1,"Approach and one gather finish without duplicate credit: "+id+" "+str(index))
			check(is_equal_approx(app.task_total,1.2),"Actual gathering timer remains 1.2 seconds")
			cases.append({"resource":id,"direction":index,"engine_seconds":ticks/60.0,"contact":contact_checked})
	app.cancel_task();app.model.start_new();app.chrome.clear_effects();app.world.feedback.events.clear()
	p.position=app.world.art_nodes.wood_3.position+Vector2(0,-100);await frames(3)
	app.gather_action();await frames(5)
	check(app.gather_approach and p.work_destination.is_finite(),"North approach uses actual physics movement before work")
	var destination:=p.work_destination
	var remaining: float=app.task_remaining
	app.gather_action()
	check(app.model.state.wood==0 and not app.world.feedback.events.has("impact:gather") and not app.world.feedback.events.has("credit:wood") and p.work_destination==destination and app.task_remaining==remaining,"Duplicate request during positioning preserves its destination/timer, grants nothing and has no impact")
	app.joystick.value=Vector2.LEFT;await frames(3);app.joystick.value=Vector2.ZERO
	check(app.task=="" and not p.work_destination.is_finite() and app.model.state.wood==0,"Manual movement cancels positioning without credit")
	p.position=app.world.art_nodes.wood_3.position+Vector2(0,-100);await frames(3);app.gather_action();await frames(3)
	app.pause_game()
	check(app.task=="" and not p.work_destination.is_finite() and app.model.state.wood==0,"Popup cancels positioning without held auto movement")
	app.close_modal()
	var report: Dictionary={"checks":checks,"failed":failures,"cases":cases,"utc":Time.get_datetime_string_from_system(true),"runtime":"Native Godot real collision movement; 8 approaches at both quest resources and left/right at every other resource; test state reset between cases"}
	FileAccess.open("res://reports/gather-contact-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
