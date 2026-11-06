extends SceneTree
var failures:Array[String]=[]
var checks:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var app=load("res://scenes/main.tscn").instantiate();root.add_child(app)
	for i in 5:await process_frame
	var store:=SaveStore.new("user://expanded_%s"%Time.get_ticks_usec())
	app.model=GameState.new(store);app.model.start_new()
	app.model.build(Vector2.ZERO,0);app.model.claim_reward(0);app.model.gather("wood_1")
	var initial:Dictionary=app.model.state.duplicate(true)
	initial.node_positions={"wood_1":[700,1000]};app.model.commit(initial)
	var prior:Dictionary=app.model.state.duplicate(true)
	app.enter_game()
	for i in 12:await physics_frame
	app.set_process(false)
	var outer:Array=app.model.nodes().filter(func(n):return "_outer_v048_" in n.id)
	check(outer.size()==12,"Twelve stable outer resources")
	check(app.world.animals.size()==9,"Existing species only, four additional animals")
	var ids:Dictionary={}
	for node in app.model.nodes():ids[node.id]=true
	check(ids.size()==app.model.nodes().size(),"No duplicate catalog IDs")
	var max_ms:=0.0
	for n in outer:
		var point:=DemoConfig.point(n.position)+Vector2(0,80)
		check(VillageLayout.ground_ok(point),"Playable contact "+n.id)
		var started:=Time.get_ticks_usec()
		check(app.navigation.start("move","",point),"Route to "+n.id)
		max_ms=maxf(max_ms,(Time.get_ticks_usec()-started)/1000.0)
		app.navigation.cancel()
	# Traverse real physics into previously inaccessible negative world coordinates.
	var destination:=Vector2(-550,800)
	check(app.navigation.start("move","",destination),"Outer physical travel starts")
	for i in 1800:
		await physics_frame
		if app.navigation.action=="":break
	check(app.world.player.position.distance_to(destination)<10,"Actual travel reaches outer destination")
	check(app.model.save_position(app.world.player.position),"Negative coordinate checkpoint")
	var restored:=GameState.new(store)
	check(DemoConfig.point(restored.state.position).distance_to(destination)<10,"Negative coordinate reload")
	check(restored.state.homes==JSON.parse_string(JSON.stringify(prior.homes)) and restored.state.wood==prior.wood and restored.state.stone==prior.stone,"Existing homes and balances preserved")
	check(restored.state.node_positions==JSON.parse_string(JSON.stringify(prior.node_positions)),"Old relocated resource preserved")
	check(restored.state.depleted.get("wood_1")==prior.depleted.get("wood_1"),"Existing depletion preserved")
	for n in outer:check(app.model.gather(n.id),"Outer gather "+n.id)
	restored=GameState.new(store)
	check(restored.nodes().size()==app.model.nodes().size(),"Reload does not duplicate new resources")
	for n in outer:check(int(restored.state.depleted.get(n.id,0))==1,"Outer depletion persists "+n.id)
	var node:Dictionary=outer[0]
	# Intentionally exhaust and respawn in the new region, retaining stable ID.
	app.model.gather(node.id);app.model.gather(node.id)
	check(app.model.respawn(node.id,Vector2(-300,1450),Time.get_unix_time_from_system()+60),"Outer respawn transaction")
	restored=GameState.new(store)
	check(DemoConfig.point(restored.state.node_positions[node.id])==Vector2(-300,1450),"Outer respawn reload")
	var pose:Transform2D=app.world.player.transform;pose.origin=Vector2(-690,800)
	check(app.world.player.test_move(pose,Vector2(-100,0)),"Physical boundary blocks outward motion")
	for dimensions in [Vector2i(1280,720),Vector2i(540,960)]:
		root.size=dimensions
		for i in 5:await process_frame
		for factor in [.56,1.6]:
			app.world.player.zoom_at(Vector2(app.w,app.h)*.5,factor)
			check(VillageLayout.ground_ok(destination),"Same world boundary for every zoom/aspect")
			var sprite:Sprite2D=app.world.get_node("Terrain")
			var coverage:Rect2=sprite.get_global_transform()*sprite.get_rect()
			for pan in [Vector2(-10000,-10000),Vector2(20000,20000)]:
				app.world.player.pan_camera(pan)
				for i in 3:await process_frame
				var view:Rect2=app.world.get_canvas_transform().affine_inverse()*app.world.get_viewport_rect()
				check(coverage.encloses(view),"Camera edge stays within single background")
	print(JSON.stringify({"checks":checks,"failures":failures,"max_route_ms_desktop":max_ms}))
	app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
