extends SceneTree
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
	for i in n:await physics_frame
func run()->void:
	var store:=SaveStore.new("user://legacy_world_%s"%Time.get_ticks_usec())
	var original:=GameState.new(store);assert(original.start_new())
	var fixture:=original.state.duplicate(true)
	fixture.homes=[];fixture.built=true;fixture.reward_claimed=true;fixture.wood=137;fixture.stone=93
	for i in 5:
		fixture.homes.append({"uid":"legacy-home-%d"%i,"style":i%3,"claimed":true,"site":i,"level":1})
	assert(original.commit(fixture))
	var model:=GameState.new(store)
	assert(model.built_count()==5 and not model.can_build())
	var world:=DemoWorld.new(model);root.add_child(world);await frames(6)
	assert(world.homes.size()==5)
	var instances:Array[int]=[]
	for i in 5:
		assert(model.home_key(i)=="legacy-home-%d"%i)
		assert(world.homes[i].visible)
		assert(world.homes[i].position==DemoConfig.BUILD_SITES[i])
		assert(world.has_node("HomeCollision%d"%i))
		instances.append(world.homes[i].get_instance_id())
		assert(world.reward_marker_rect(i).size.x>0)
	# An unrelated persisted change invokes the same production refresh signal.
	var next:=model.state.duplicate(true);next.wood+=10;assert(model.commit(next));await frames(3)
	world.refresh();await frames(2)
	for i in 5:
		assert(world.homes[i].visible and world.homes[i].get_instance_id()==instances[i])
		assert(model.home_key(i)=="legacy-home-%d"%i)
		assert(world.get_node("HomeCollision%d"%i).position==model.home_position(i))
	var reloaded:=GameState.new(store)
	assert(reloaded.built_count()==5 and reloaded.homes()==JSON.parse_string(JSON.stringify(fixture.homes)))
	assert(reloaded.state.wood==147 and reloaded.state.stone==93)
	world.queue_free();await frames(2)
	print("Five legacy homes load, render, retain identity/collisions through refresh, and persist without truncation: PASS")
	quit()
