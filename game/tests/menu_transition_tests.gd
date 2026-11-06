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
	app.model=GameState.new(SaveStore.new("user://menu_transition_%s"%Time.get_ticks_usec()));app.model.start_new();app.enter_game();await frames(10)
	for i in 2:
		app.build_side.show();var before:bool=app.menu_expanded;app.toggle_menu()
		check(not app.build_side.visible,"Toggle closes side menu in both directions")
		check(app.menu_animating and app.menu_expanded!=before,"Animation starts once")
		app.toggle_menu();check(app.menu_expanded!=before,"Repeated toggle ignored during tween")
		app.construction_menu();check(not app.build_side.visible,"Side menu cannot reopen during tween")
		var at:Vector2=app.action_row.get_global_rect().get_center()
		app.world_tap(at);check(app.navigation.action.is_empty(),"Animated row does not send tap to world")
		for down in [true,false]:
			var event:=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=down;root.push_input(event,true)
		check(app.navigation.action.is_empty(),"Touch row blocked during transition")
		await create_timer(.3).timeout
		check(not app.menu_animating,"Input unlocks after animation")
	app.construction_menu();check(app.build_side.visible,"Existing side menu works after transition")
	print(JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
