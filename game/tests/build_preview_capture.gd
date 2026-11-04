extends SceneTree
var app:Node
func _initialize()->void:root.unfocusable=true;call_deferred("run")
func run()->void:
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app)
	for i in 4:await process_frame
	app.start_region()
	for i in 4:await process_frame
	var next:Dictionary=app.model.state.duplicate(true);next.wood=2;next.stone=2;app.model.commit(next)
	app.world.player.position=Vector2(1150,900);app.world.player.resume_camera()
	DirAccess.make_dir_recursive_absolute("res://reports/preview-video")
	for tick in 660:
		if tick==20:app.toggle_menu()
		if tick==65:app.toggle_menu()
		if tick==100:app.construction_menu()
		if tick==140:
			for b in app.overlay.find_children("*","Button",true,false):
				if b.text=="움집 선택":b.pressed.emit();break
		if tick==180:app.world_tap(app.world.get_global_transform_with_canvas()*DemoConfig.BUILD_SITES[0])
		if tick==260:app.cancel_build_preview()
		if tick==290:
			app.choosing_plot=true;app.world.show_candidates=true
			app.world_tap(app.world.get_global_transform_with_canvas()*DemoConfig.BUILD_SITES[1])
		if tick==360:app.confirm_build_preview()
		if tick==510 and app.model.built_count()>0:app.claim_home(0)
		if tick==570:app.toggle_menu()
		await process_frame
		if tick%2==0:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://reports/preview-video/frame-%04d.png"%(tick/2))
	quit()
