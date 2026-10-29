extends SceneTree

var app: Node
var failures: Array[String] = []
var checks := 0
var captures: Array[String] = []

func check(value: bool, text: String) -> void:
	checks += 1
	if not value:
		failures.append(text)
		push_error(text)

func _initialize() -> void:
	call_deferred("run_tests")

func snap(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var file := "res://reports/%s.png" % name
	root.get_texture().get_image().save_png(file)
	captures.append(file)

func touch(target: Control, index: int, pressed: bool, local: Vector2 = Vector2(-1,-1)) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = target.get_global_transform_with_canvas()*(target.size/2 if local.x < 0 else local)
	root.push_input(event)

func press(target: Control, index: int = 1) -> void:
	touch(target,index,true)
	await process_frame
	touch(target,index,false)
	await process_frame

func all_controls_inside(node: Node, rect: Rect2) -> void:
	for child in node.get_children():
		if child is DemoButton and child.is_visible_in_tree():
			check(rect.encloses(child.get_global_rect()),"Button fits viewport: "+child.text)
		all_controls_inside(child,rect)

func run_tests() -> void:
	DirAccess.make_dir_recursive_absolute("res://reports")
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.show_screen("onboarding")
	await snap("01-onboarding")
	app.welcome(false)
	await snap("02-title")
	app.show_screen("region")
	await snap("03-region")
	app.start_region()
	await process_frame
	check(app.screen == "play" and app.modal,"New game shows quest introduction")
	await snap("04-quest-intro")
	app.close_modal()
	var intro: Dictionary = app.model.state.duplicate(true)
	intro.intro_seen = true
	app.model.commit(intro)
	await snap("05-gameplay")
	var before: Vector2 = app.world.player.position
	touch(app.joystick,0,true,Vector2(110,70))
	await create_timer(0.15).timeout
	check(app.world.player.position.x > before.x,"Touch joystick moves player")
	check(app.joystick.finger == 0,"Joystick owns first finger")
	var journal: Control = app.gather_button.get_parent().get_child(2)
	await press(journal,1)
	check(app.modal,"Second finger opens quest while first is held")
	check(app.joystick.value == Vector2.ZERO,"Popup clears held movement")
	var stopped: Vector2 = app.world.player.position
	await create_timer(0.15).timeout
	check(app.world.player.position.distance_to(stopped) < 1,"Popup blocks world movement")
	touch(app.joystick,0,false)
	app.go_back()
	check(not app.modal and app.screen == "play","Back closes popup and preserves play screen")
	var n: Dictionary = DemoConfig.get_data().nodes[0]
	app.world.player.position = DemoConfig.point(n.position)+Vector2(70,0)
	await process_frame
	await press(app.gather_button)
	check(app.task == "gather","Touch action starts gathering")
	for i in 20: app.gather_action()
	check(app.task == "gather","Rapid input leaves one active gather task")
	app.task_remaining = 0.01
	await create_timer(0.06).timeout
	check(app.model.state.wood == 2,"Single action grants one yield")
	app.world.player.position = DemoConfig.point(DemoConfig.get_data().build_site)+Vector2(140,0)
	await process_frame
	app.build_action()
	check(not app.modal and not app.model.state.built,"Insufficient build leaves world unchanged")
	for entry in DemoConfig.get_data().nodes:
		while not app.world.exhausted(entry): app.model.gather(entry.id)
	app.build_action()
	check(app.modal,"Sufficient resources ask to build")
	var confirm: Control = app.overlay.get_child(1).get_child(0).get_child(2).get_child(1)
	await press(confirm)
	check(app.task == "build","Build confirmation starts construction")
	app.task_remaining = 0.01
	await create_timer(0.06).timeout
	check(app.model.state.built and app.modal,"Construction completes and reward dialog opens")
	await snap("06-complete")
	var reward: Control = app.overlay.get_child(1).get_child(0).get_child(2).get_child(0)
	await press(reward)
	check(app.model.state.reward_claimed and app.model.state.tokens == 10,"Touch reward claimed once")
	var saved := GameState.new(SaveStore.new("user://tests/session"))
	check(saved.state.built and saved.state.reward_claimed,"Completed game persists across instances")
	await snap("07-home")
	app.world.player.position = Vector2(1270,680)
	for i in 60:
		app.world.player.direction = Vector2.UP
		await physics_frame
	check(app.world.player.position.y > 490,"River bank blocks entry")
	for dims in [Vector2i(1280,720),Vector2i(896,370),Vector2i(725,396),Vector2i(816,616)]:
		root.size = dims
		await process_frame
		await process_frame
		await process_frame
		for name in ["onboarding","title","region","play"]:
			app.show_screen(name)
			await process_frame
			await process_frame
			all_controls_inside(app.ui,Rect2(Vector2.ZERO,root.get_visible_rect().size))
			await snap("viewport-%dx%d-%s" % [dims.x,dims.y,name])
	var report := {"checks":checks,"failed":failures,"screenshots":captures,"runtime":"Native Godot synthetic touch; not Android device validation"}
	var file := FileAccess.open("res://reports/ui-smoke.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
