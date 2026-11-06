extends SceneTree
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var app=load("res://scenes/main.tscn").instantiate();root.add_child(app)
	for i in 5:await process_frame
	var store:=SaveStore.new("user://edge_%s"%Time.get_ticks_usec())
	app.model=GameState.new(store);app.model.start_new();app.enter_game()
	for i in 12:await physics_frame
	app.set_process(false)
	var nodes:Array=app.model.nodes().filter(func(n):return "_edge_" in n.id)
	check(nodes.size()==10,"Ten added nodes")
	check(nodes.filter(func(n):return n.kind=="wood").size()==5,"Balanced resource types")
	var old:Dictionary=app.model.state.duplicate(true)
	for n in nodes:
		var pos:=DemoConfig.point(n.position)
		check(VillageLayout.ground_ok(pos),"Inside playable: "+n.id)
		for site in DemoConfig.BUILD_SITES:check(pos.distance_to(site)>230,"Clear build site: "+n.id)
		check(app.navigation.start("move","",pos+Vector2(0,80)),"Reachable contact: "+n.id)
		app.navigation.cancel()
		var balance:int=app.model.state[n.kind]
		check(app.model.gather(n.id),"Gather new node: "+n.id)
		check(app.model.state[n.kind]==balance+10,"Reward unchanged")
	var loaded:=GameState.new(store)
	for n in nodes:check(int(loaded.state.depleted.get(n.id,0))==1,"New depletion survives reload: "+n.id)
	check(loaded.state.wood==old.wood+50 and loaded.state.stone==old.stone+50,"Balances preserved")
	var clouds=app.world.get_node("VillageEdgeClouds")
	app.world.player.zoom_factor=DemoPlayer.MAX_ZOOM;clouds._process(0)
	check(not clouds.visible,"No cloud at maximum zoom")
	app.world.player.zoom_factor=DemoPlayer.MIN_ZOOM;clouds._process(0)
	check(clouds.visible and clouds.visibility_layer==2,"Clouds visible only outside GPS")
	check(app.chrome.location_marker_texture.get_size()==Vector2(72,60),"Official marker source dimensions")
	print(JSON.stringify({"checks":checks,"failures":failures}))
	app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
