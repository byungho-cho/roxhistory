extends SceneTree
var checks := 0
var failed: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failed.append(message); push_error(message)
func frames(count: int) -> void:
	for i in count: await process_frame
func run() -> void:
	var app: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await frames(2)
	app.model.start_new(); app.start_region(); app.close_modal()
	await frames(3)
	var world: DemoWorld = app.world
	check(world.animals.size()==4,"Four bounded ambient animals, not an unlimited spawn loop")
	var provenance: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/animals/provenance.json"))
	for entry in provenance:
		check(entry.triangles<=16000 and entry.bytes<1000000,"Mobile mesh/texture budget: "+entry.id)
	for animal in world.animals:
		check(not Geometry2D.is_point_in_polygon(animal.position,PackedVector2Array(DemoWorld.RIVER_POLYGON)),"Animal stays on land")
		var anchor := animal.display.position+animal.camera.unproject_position(Vector3.ZERO)*animal.display.scale
		check(anchor.length()<0.01,"3D animal origin remains on its 2D contact point")
	var original: Dictionary = app.model.state.duplicate(true)
	app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await frames(3)
	var clocks: Array[float] = []
	for animal in world.animals: clocks.append(animal.clock)
	await frames(10)
	for i in world.animals.size(): check(is_equal_approx(clocks[i],world.animals[i].clock),"Background freezes wildlife motion")
	app._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	app.close_modal()
	check(app.model.state.wood==original.wood and app.model.state.stone==original.stone,"Ambient effects never change resources")
	app.model.gather("wood_3"); app.model.gather("stone_2")
	world.feedback.begin("build")
	world.feedback.update_work(5,10)
	check(is_equal_approx(world.feedback.preview_progress,0.5),"Common scaffold supports future durations, not hardcoded two seconds")
	world.feedback.cancel()
	check(not app.model.state.built and world.feedback.celebration==0,"Cancel has no completed building or success effect")
	check(app.model.build(),"Build commits once")
	var style: int = app.model.state.hut_style
	check(style>=0 and style<=2,"One of three approved hut styles selected")
	check(not app.model.build() and app.model.state.hut_style==style,"Duplicate completion cannot reroll or charge again")
	var restored := GameState.new(app.model.store)
	check(restored.state.hut_style==style and restored.state.wood==0 and restored.state.stone==0,"Style and consumed materials survive re-entry")
	var legacy: Dictionary = restored.state.duplicate(true)
	legacy.erase("hut_style")
	check(app.model.store.valid(legacy),"Old saves without a style remain valid")
	legacy.hut_style=3
	check(not app.model.store.valid(legacy),"Unknown saved style rejected")
	check(DemoConfig.get_data().build_seconds==2 and DemoConfig.get_data().gather_seconds==1.2,"Demo timing preserved")
	for prop in world.environment_props:
		if prop.kind=="hut": print("HUT_BOUNDS ",prop.hut_style," ",prop.sprite.texture.region)
	var report := {"checks":checks,"failed":failed,"runtime":"Windows Godot native render; synthetic lifecycle and state checks"}
	DirAccess.make_dir_recursive_absolute("res://reports")
	FileAccess.open("res://reports/world-life-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report));quit(0 if failed.is_empty() else 1)
