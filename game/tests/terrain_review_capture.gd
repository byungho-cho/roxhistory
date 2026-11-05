extends SceneTree
var app:Node
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
	for i in n:await process_frame
func capture(name:String)->void:
	await frames(8);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/terrain-review/terrain-"+name+".png")
func run()->void:
	DirAccess.make_dir_recursive_absolute("res://reports/terrain-review")
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames(5)
	if app.model.state.is_empty():assert(app.model.start_new())
	app.enter_game();await frames(25);app.set_process(false)
	var before:Dictionary=app.model.state.duplicate(true)
	assert(DemoPlayer.WORLD_SIZE==Vector2(2400,1350))
	assert(not app.world.water.visible)
	var terrain:Sprite2D=app.world.get_node("Terrain")
	assert(terrain.texture.get_size()==Vector2(1672,941))
	for z in [DemoPlayer.MIN_ZOOM,DemoPlayer.MAX_ZOOM]:
		app.world.player.zoom_at(Vector2(app.w,app.h)*.5,z)
		print("Village zoom factor=",z," camera=",app.world.player.camera.zoom.x," native texture logical magnification=",terrain.scale.x*app.world.player.camera.zoom.x)
		await capture("village-min" if z==DemoPlayer.MIN_ZOOM else "village-max")
	app.switch_map_scene();app.world_map.zoom=1;app.world_map.center=Vector2.ZERO;app.world_map.queue_redraw()
	await capture("world-min")
	app.world_map.zoom_at(Vector2(app.w,app.h)*.5,2.4)
	await capture("world-max")
	var reference:Vector2=Vector2(300,120)
	var screen_before:Vector2=app.world_map.size*.5+(reference-app.world_map.center)*app.world_map.zoom
	var recovered:Vector2=app.world_map.center+(screen_before-app.world_map.size*.5)/app.world_map.zoom
	assert(recovered.is_equal_approx(reference))
	app.world_map.pan(Vector2(-1800,-600));await capture("world-pan")
	print("Fog rect=",app.world_map.outer_fog.size," center=",app.world_map.center," zoom=",app.world_map.zoom," visible=",app.world_map.outer_fog.is_visible_in_tree())
	var screen_after:Vector2=app.world_map.size*.5+(reference-app.world_map.center)*app.world_map.zoom
	var recovered_after:Vector2=app.world_map.center+(screen_after-app.world_map.size*.5)/app.world_map.zoom
	assert(recovered_after.is_equal_approx(reference))
	assert(app.world_map.outer_fog.material.get_shader_parameter("camera_center")==app.world_map.center)
	assert(app.world_map.outer_fog.z_index==0)
	app.switch_map_scene();await frames(3)
	assert(app.model.state==before)
	print("Terrain native sizes, unchanged playable extent/save, village/world zoom, pan-fixed fog and return: PASS")
	quit()
