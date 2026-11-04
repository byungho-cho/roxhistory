extends SceneTree
var app:Node
func _initialize()->void:root.unfocusable=true;call_deferred("run")
func run()->void:
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app)
	for i in 3:await process_frame
	app.start_region()
	for i in 3:await process_frame
	var next:Dictionary=app.model.state.duplicate(true);next.wood=2;next.stone=2;app.model.commit(next)
	app.world.player.position=app.world.art_nodes.wood_1.position+Vector2(0,35);app.world.player.resume_camera()
	DirAccess.make_dir_recursive_absolute("res://reports/queue-video")
	var key:=""
	for tick in 780:
		if tick==20:app.construction_menu()
		if tick==65:
			for b in app.overlay.find_children("*","Button",true,false):
				if b.text=="움집 선택":b.pressed.emit();break
		if tick==100:app.world_tap(app.world.get_global_transform_with_canvas()*DemoConfig.BUILD_SITES[3])
		if tick==120:app.gather_action("wood_1")
		if tick==240:app.navigation.start("move","",Vector2(650,850))
		if tick==270:app.navigation.start("move","",Vector2(700,850))
		if tick==390 and app.model.built_count()>0:app.claim_home(0);key=app.model.home_key(0)
		if tick==470:app.request_demolition(app.world.get_global_transform_with_canvas()*(app.model.home_position(0)+Vector2(0,-100)))
		if tick==550:app.confirm_demolition(key)
		await process_frame
		if tick%2==0:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://reports/queue-video/frame-%04d.png"%(tick/2))
	print("QUEUE_CAPTURE homes=",app.model.built_count()," wood=",app.model.state.wood," stone=",app.model.state.stone)
	quit()
