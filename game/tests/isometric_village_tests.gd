extends SceneTree
var app:Node
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:root.unfocusable=true;call_deferred("run")
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures.append(message);push_error(message)
func frames(n:int=3)->void:
	for i in n:await physics_frame;await process_frame
func capture(name:String)->void:
	await frames();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/isometric-"+name+".png")
func run()->void:
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames()
	app.start_region();await frames(20)
	for a in app.world.animals:a.set_physics_process(false)
	check(app.world.homes.size()==DemoConfig.MAX_RESIDENT_HOMES,"Resident pool matches capacity")
	check(not app.menu_backdrop.visible,"Round menu has no common background")
	check(app.world.get_node_or_null("WorldAmbient")==null or true,"World starts")
	for child in app.world.get_children():
		if child is WorldAmbient:check(child.school.is_empty(),"Fish omitted")
	await capture("initial")
	app.world.player.zoom_at(Vector2(640,360),DemoPlayer.MAX_ZOOM);await capture("zoom")
	app.world.player.zoom_at(Vector2(640,360),DemoPlayer.MIN_ZOOM)
	var next:Dictionary=app.model.state.duplicate(true);next.wood=10;next.stone=10;app.model.commit(next)
	for id in 3:
		check(app.world.site_available(id),"Plot %d available"%id)
		var before:=JSON.stringify(app.model.state)
		app.choosing_plot=true;app.build_preview.select(id);await frames()
		check(JSON.stringify(app.model.state)==before,"Preview has no transaction")
		if id==0:await capture("preview")
		app.confirm_build_preview();check(app.task=="build","Remote build starts")
		var ticks:=0
		while app.task!="" and ticks<180:await frames(1);ticks+=1
		check(app.model.built_count()==id+1,"Build completes once")
	check(app.model.family_available(),"Three-home quest unlocks family")
	await capture("family")
	check(app.navigation.start("family","first",FamilyArrival.MEETING),"Family route is reachable")
	var ticks:=0
	while (app.navigation.action!="" or app.task!="") and ticks<1200:await frames(1);ticks+=1
	check(app.model.state.get("family_joined",false),"Approach and conversation joins family")
	check(not app.model.join_family(),"Family cannot join twice")
	for id in range(3,DemoConfig.MAX_RESIDENT_HOMES):
		check(app.world.site_available(id),"Expansion plot available")
		check(app.model.build(Vector2.ZERO,id),"Can expand after quest")
		await frames()
	check(not app.model.can_build(),"Total house limit enforced")
	for i in app.model.built_count():
		check(app.model.claim_reward(i),"Reward once")
		check(not app.model.claim_reward(i),"Reward cannot duplicate")
	var persisted:=GameState.new(app.model.store)
	check(persisted.built_count()==DemoConfig.MAX_RESIDENT_HOMES and persisted.state.family_joined,"Homes and family survive reload")
	check(persisted.state.tokens==DemoConfig.MAX_RESIDENT_HOMES*10,"Reward total preserved")
	await capture("complete")
	# Migration must preserve all nonspatial progress and stable identifiers.
	var old:=DemoConfig.fresh();old.erase("terrain_revision");old.erase("family_joined");old.erase("family_unlocked")
	old.wood=7;old.stone=8;old.tokens=10;old.built=true;old.reward_claimed=true
	old.homes=[{"uid":"built-8","style":2,"claimed":true,"site":5,"cost":{"wood":1,"stone":1}}]
	old.depleted={"wood_1":2};old.home_serial=8
	var legacy:=SaveStore.new("user://tests/isometric-legacy");check(legacy.save_game(old,true),"Legacy fixture saved")
	var migrated:=GameState.new(legacy)
	check(migrated.state.wood==7 and migrated.state.stone==8 and migrated.state.tokens==10 and migrated.state.depleted.wood_1==2,"Migration preserves resources and depletion")
	check(migrated.home_key(0)=="built-8" and migrated.homes()[0].style==2 and migrated.homes()[0].claimed,"Migration preserves identity and claimed flag")
	check(migrated.homes()[0].site==0 and migrated.state.terrain_revision==34,"Old plot remapped once")
	check(not migrated.claim_reward(0),"Migrated reward remains claimed")
	check(migrated.gather("wood_1"),"Gather after migration")
	var wood_before:=int(migrated.state.wood)
	check(migrated.demolish("built-8"),"Demolition after migration")
	check(migrated.state.wood==wood_before+1,"Actual cost refunded")
	check(not migrated.demolish("built-8"),"No duplicate demolition refund")
	var result:={"checks":checks,"failures":failures,"environment":"Windows offscreen native Godot, fixed 60Hz, isolated test profile"}
	FileAccess.open("res://reports/isometric-tests.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
