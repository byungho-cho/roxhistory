extends SceneTree
var checks := 0
var failures: Array[String] = []
func check(value: bool, text: String) -> void:
	checks += 1
	if not value:
		failures.append(text)
		push_error(text)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var model := GameState.new(SaveStore.new("user://tests/environment_%d" % Time.get_ticks_usec()))
	model.start_new()
	var world := DemoWorld.new(model)
	root.add_child(world)
	await physics_frame
	await physics_frame
	var player := world.player
	player.set_physics_process(false)
	player.position = Vector2(1640,1150)
	var hit := false
	for i in 90:
		await physics_frame
		player.velocity = Vector2.UP*165
		player.move_and_slide()
		if player.get_slide_collision_count() > 0: hit = true
	check(hit and player.position.y >= 1077 and player.position.y < 1100,"Visible tree base blocks physical movement")
	player.position = Vector2(990,700)
	world.restore_clear_position()
	await physics_frame
	await physics_frame
	check(not player.test_move(player.transform,Vector2.ZERO,null,0.08,true),"Old save inside new hut relocates to free ground")
	player.position = Vector2(990,1020)
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0,0,80,45)
	grid.cell_size = Vector2(30,30)
	grid.offset = Vector2(15,15)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	var query := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 20
	query.shape = circle
	query.exclude = [player.get_rid()]
	var space := world.get_world_2d().direct_space_state
	for y in 45:
		for x in 80:
			var p := Vector2(x*30+15,y*30+15)
			query.transform = Transform2D(0,p)
			grid.set_point_solid(Vector2i(x,y),not space.intersect_shape(query,1).is_empty() or x == 0 or y == 0 or x == 79 or y == 44)
	var start := Vector2i(33,34)
	for resource in DemoConfig.get_data().nodes:
		var p := DemoConfig.point(resource.position)
		var reachable := false
		for i in 12:
			var approach := p+Vector2.from_angle(i*TAU/12)*85
			var cell := Vector2i(approach/30)
			if grid.is_in_boundsv(cell) and not grid.is_point_solid(cell) and not grid.get_id_path(start,cell).is_empty():
				reachable = true
				break
		check(reachable,"Open walking route to resource "+str(resource.id))
	var site_approach := Vector2i((world.site.position+Vector2(0,100))/30)
	check(not grid.get_id_path(start,site_approach).is_empty(),"Construction site reachable from arrival")
	var phases := {}
	for p in world.environment_props:
		if p.sprite.material is ShaderMaterial: phases[p.sprite.material.get_shader_parameter("phase")] = true
	check(phases.size() > 20,"Wind phases vary across foliage")
	check(world.y_sort_enabled,"Character and props share feet-based sorting")
	check(world.water.polygon == world.get_node("RiverBank").get_child(0).polygon,"Water rendering and river collision use one boundary")
	for dims in [Vector2i(1280,720),Vector2i(896,370),Vector2i(725,396),Vector2i(816,616)]:
		root.size = dims
		player.position = Vector2(700,540)
		await process_frame
		await physics_frame
		player.camera.force_update_scroll()
		var inverse := world.get_canvas_transform().affine_inverse()
		var upper: Vector2 = inverse*Vector2.ZERO
		var lower: Vector2 = inverse*root.get_visible_rect().size
		check(upper.x >= -1 and upper.y >= -1 and lower.x <= 2401 and lower.y <= 1351,"Camera stays inside terrain at "+str(dims))
	var report := {"checks":checks,"failed":failures,"utc":Time.get_datetime_string_from_system(true)}
	DirAccess.make_dir_recursive_absolute("res://reports")
	FileAccess.open("res://reports/environment-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
