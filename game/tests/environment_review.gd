extends SceneTree

var app: Node
var failures: Array[String] = []
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func snap(file: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/"+file+".png")

func walk_to(target: Vector2, limit: float = 6.0) -> void:
	var elapsed := 0.0
	while app.world.player.position.distance_to(target) > 10 and elapsed < limit:
		app.world.player.direction = app.world.player.position.direction_to(target)
		await physics_frame
		elapsed += 1.0/60.0
	app.world.player.direction = Vector2.ZERO
	check(app.world.player.position.distance_to(target) < 25,"Walk reaches "+str(target))

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://reports")
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.model.start_new()
	app.enter_game()
	app.close_modal()
	app.set_process(false)
	var world: DemoWorld = app.world
	var player: DemoPlayer = world.player
	var camera: Camera2D = player.camera
	camera.top_level = true
	camera.position = Vector2(1170,800)
	camera.offset = Vector2.ZERO
	check(world.y_sort_enabled,"Feet-based depth sorting enabled")
	check(world.water.polygon == world.get_node("RiverBank").get_child(0).polygon,"Visible water and bank collider share boundary")
	check(world.environment_props.size() >= 60,"Independent environment objects populated")
	check(world.get_node("ExistingHut").get_node("Footprint") is StaticBody2D,"Hut has ground footprint")
	app.canvas.visible = false
	camera.position = Vector2(1550,560)
	camera.zoom = Vector2(0.9,0.9)
	await create_timer(2).timeout
	await snap("stage1-idle-a")
	await create_timer(1.4).timeout
	await snap("stage1-idle-b")
	app.canvas.visible = true
	camera.position = Vector2(1170,800)
	camera.zoom = Vector2(0.5,0.5)
	# Actual CharacterBody2D movement, not teleported animation, around a tree.
	player.position = Vector2(1450,1120)
	await walk_to(Vector2(1500,990))
	await walk_to(Vector2(1640,990))
	await snap("stage1-tree-behind")
	await walk_to(Vector2(1740,990))
	await walk_to(Vector2(1800,1130))
	await walk_to(Vector2(1640,1130))
	await snap("stage1-tree-front")
	# Separate inspection segment for the dwelling footprint and roof occlusion.
	player.position = Vector2(800,820)
	await walk_to(Vector2(1210,820))
	await snap("stage1-hut-front")
	await walk_to(Vector2(1240,550))
	await walk_to(Vector2(900,550))
	await walk_to(Vector2(990,600))
	await snap("stage1-hut-behind")
	await create_timer(2).timeout
	player.direction = Vector2.ZERO
	var report := {"checks":checks,"failed":failures,"utc":Time.get_datetime_string_from_system(true),"runtime":"Native Godot physics and visual review; not Android"}
	FileAccess.open("res://reports/environment-review.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
