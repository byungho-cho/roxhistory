extends SceneTree
var app:Node
var errors:Array[String]=[]
var count:=0
func _initialize()->void:root.unfocusable=true;call_deferred("run")
func check(ok:bool,message:String)->void:
	count+=1
	if not ok:errors.append(message);push_error(message)
func frames(n:int=3)->void:
	for i in n:await physics_frame;await process_frame
func capture(label:String)->void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/refactor-"+label+".png")
func run()->void:
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames()
	app.start_region();await frames(10)
	check(not app.joystick.visible,"Village joystick absent")
	check(app.model.built_count()==0,"Fresh village only contains chief")
	check(app.world.homes.size()==5,"Five resident homes plus chief")
	await capture("village")
	var at:Vector2=app.world.player.position
	app.toggle_world_map();await frames()
	check(app.world_map.visible and not app.world.visible,"World toggle")
	var m:VillageWorldMap=app.world_map
	check(is_equal_approx(m.village.get_width()*m.factor()*m.visible_fraction,app.w/12.0),"Minimum village visible width")
	await capture("world-min")
	m.zoom_at(Vector2(app.w*.5,app.h*.5),2.4)
	check(is_equal_approx(m.village.get_width()*m.factor()*m.visible_fraction,app.w/5.0),"Maximum village visible width")
	await capture("world-max")
	m.pan(Vector2(100000,100000));check(m.center.is_finite(),"Pan bounded")
	app.toggle_world_map();await frames()
	check(app.world.visible and not m.visible and app.world.player.position.distance_to(at)<1,"Village camera/state restored")
	var rich:Dictionary=app.model.state.duplicate(true);rich.wood=100;rich.stone=100;app.model.commit(rich)
	var before:=JSON.stringify(app.model.state)
	app.choosing_plot=true;app.build_preview.select(0);app.cancel_build_preview()
	check(JSON.stringify(app.model.state)==before,"Preview cancellation spends nothing")
	for animal in app.world.animals:animal.set_physics_process(false)
	check(app.world.site_available(0),"Clear plot available")
	app.choosing_plot=true;app.build_preview.select(0);app.confirm_build_preview()
	check(app.task=="build","Build starts remotely")
	var ticks:=0
	while app.task!="" and ticks<200:await frames(1);ticks+=1
	check(app.model.built_count()==1,"Build finishes once")
	check(not app.world.site_available(0),"Completed plot occupied")
	await capture("built")
	var replacement:Dictionary={"BLD-HUT-L1":"res://missing-hut.png"}
	AssetCatalog.set_replacements(replacement)
	check(AssetCatalog.texture("BLD-HUT-L1")!=null,"Missing replacement falls back to packaged asset")
	AssetCatalog.set_replacements({})
	# Blocking is based on physical resources, not sprites or manifest dimensions.
	var obstruction:Dictionary=app.model.state.duplicate(true)
	obstruction.node_positions={"stone_1":[DemoConfig.BUILD_SITES[1].x,DemoConfig.BUILD_SITES[1].y]}
	app.model.commit(obstruction);await frames()
	check(not app.world.site_available(1),"Resource prevents construction")
	for i in 2:check(app.model.gather("stone_1"),"Clear occupied rock")
	await frames();check(app.world.site_available(1),"Fully gathered rock frees plot")
	var n:Dictionary=app.model.nodes()[0]
	var balance:int=app.model.state.wood
	for i in int(n.charges):check(app.model.gather(n.id),"Strike grants resource")
	check(app.model.state.wood==balance+int(n.charges)*10,"Each strike grants ten")
	check(not app.model.gather(n.id),"Exhausted resource cannot pay twice")
	await frames()
	check(not app.world.art_nodes[n.id].visible,"Exhausted tree hidden")
	var restored:=GameState.new(app.model.store)
	check(restored.state.wood==app.model.state.wood,"Save reload preserves balances")
	check(restored.state.depleted[n.id]==n.charges,"Save reload preserves depletion")
	var old:=DemoConfig.fresh();old.erase("resource_revision");old.wood=77;old.tokens=30;old.family_joined=true;old.depleted={"stone_1":4,"wood_1":1}
	var store:=SaveStore.new("user://tests/refactor-migration");store.save_game(old,true)
	var migrated:=GameState.new(store)
	check(migrated.state.wood==77 and migrated.state.tokens==30 and migrated.state.family_joined,"Migration preserves balances and family")
	check(migrated.state.depleted.stone_1==2,"Exhaustion migrated without reward")
	var result:={"checks":count,"failures":errors,"environment":"Godot isolated test profile; no physical touchscreen"}
	FileAccess.open("res://reports/first-refactor-tests.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print(JSON.stringify(result));quit(0 if errors.is_empty() else 1)
