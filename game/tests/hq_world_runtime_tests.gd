extends SceneTree
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
	for i in n:await physics_frame
func run()->void:
	var model:=GameState.new(SaveStore.new("user://hq_world_%s"%Time.get_ticks_usec()));model.start_new()
	var world:=DemoWorld.new(model);root.add_child(world);await frames(6)
	assert(world.boundary_level==1)
	assert(world.boundary_pulse==null)
	assert(world.boundary_root.get_child_count()==5)
	assert(world.playable_rect().has_point(world.player.position))
	for n in model.nodes():
		assert(world.art_nodes.has(n.id))
		assert(world.playable_rect().grow(-100).has_point(DemoConfig.point(n.position)))
	var clouds:VillageEdgeClouds=world.get_node("VillageEdgeClouds")
	for size in [Vector2i(1280,720),Vector2i(540,960),Vector2i(1920,720)]:
		root.size=size;await frames(3)
		world.player.zoom_factor=DemoPlayer.MIN_ZOOM;clouds._process(0)
		var viewport_size:=clouds.get_viewport_rect().size
		assert(clouds.visible)
		for i in 4:
			var cloud:Sprite2D=clouds.get_child(i)
			var screen:=clouds.get_global_transform_with_canvas()*cloud.position
			var h:=float(cloud.get_meta("visible_height"))*.5
			assert(is_equal_approx(screen.x,0.0 if i%2==0 else viewport_size.x))
			assert(is_equal_approx(screen.y+h if i<2 else viewport_size.y-screen.y+h,20.0))
		world.player.zoom_factor=DemoPlayer.MAX_ZOOM;clouds._process(0);assert(not clouds.visible)
	var next:=model.state.duplicate(true);next.chief_level=4;model.commit(next);model.migrate_resource_positions();await frames(5)
	assert(world.boundary_level==4)
	assert(world.boundary_pulse!=null and world.boundary_pulse.is_running())
	assert(not world.player.presentation_paused)
	await create_timer(1.15).timeout
	var perimeter:Line2D=world.boundary_root.get_node("UnlockedPerimeter")
	assert(is_equal_approx(perimeter.width,3.0))
	assert(is_equal_approx(perimeter.default_color.a,.32))
	for n in model.nodes():assert(world.art_nodes.has(n.id))
	var regrowth:=ResourceRegrowth.new(world)
	var relocated:=regrowth.find_position(world.player.position)
	assert(relocated.is_finite());assert(world.playable_rect().grow(-100).has_point(relocated))
	regrowth.free();world.queue_free();await frames(2)
	print("HQ live boundary/resource upgrade, reachable respawn and three viewport corner layouts: PASS")
	quit()
