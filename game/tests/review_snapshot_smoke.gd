extends SceneTree
# Uses a separate test profile supplied by the caller; never the player's save.
func _initialize()->void:call_deferred("run")
func frames(count:int)->void:
	for i in count:await process_frame
func run()->void:
	var app=load("res://scenes/main.tscn").instantiate();root.add_child(app)
	await frames(5)
	if app.model.state.is_empty():assert(app.model.start_new())
	app.enter_game();await frames(12)
	assert(app.world!=null and app.world.player!=null)
	app.construction_menu();await frames(3)
	assert(app.build_side.visible and app.build_side.outpost_button.disabled)
	assert(AssetCatalog.texture("UI-MENU-EXPAND")!=null)
	assert(AssetCatalog.texture("UI-MENU-COLLAPSE")!=null)
	assert(AssetCatalog.texture("WORLD-MOUNTAIN")!=null)
	app.build_side.hide()
	app.switch_map_scene();await frames(5)
	assert(app.world_map_open)
	app.switch_map_scene();await frames(5)
	assert(not app.world_map_open)
	assert(app.model.save_position(app.world.player.position))
	print("Review snapshot: village, build menu, replacement assets, both maps and save PASS")
	quit()
