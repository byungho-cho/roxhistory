extends SceneTree
var app:Node
func _initialize()->void:
	root.unfocusable=true
	call_deferred("run")
func snap(name:String)->void:
	for i in 12:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/polish-"+name+".png")
func run()->void:
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await process_frame
	app.start_region();app.close_modal()
	app.world.player.position=Vector2(1150,810)
	for r in app.world.residents:r.set_physics_process(false)
	for a in app.world.animals:a.set_physics_process(false)
	app.actions_expanded=false;await snap("folded")
	app.actions_expanded=true;await snap("expanded")
	app.world.player.zoom_at(Vector2(480,270),2.0);await snap("zoom")
	app.canvas.visible=false
	var p:DemoPlayer=app.world.player
	p.camera.top_level=true;p.camera.position_smoothing_enabled=false;p.camera.position=Vector2(1170,985);p.camera.zoom=Vector2(1.6,1.6)
	p.position=Vector2(1170,1030)
	for i in app.world.residents.size():
		var r:TrialResident=app.world.residents[i];r.position=Vector2(1000 if i==0 else 1340,1030);r.visual.set_render_zoom(2);r.visual.animate(.5,Vector2.DOWN,0,false,"",0,false);r.visual.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	await snap("residents-front")
	for r in app.world.residents:r.visual.animate(1,Vector2.UP,0,false,"",0,false)
	await snap("residents-back")
	for r in app.world.residents:r.visible=false;r.collision_layer=0
	p.camera.position=Vector2(865,620);p.camera.zoom=Vector2(1.5,1.5)
	p.position=Vector2(865,580);await snap("hut-behind")
	p.position=Vector2(865,755);await snap("hut-front")
	p.position=Vector2(1040,695);await snap("hut-side")
	p.camera.position=Vector2(1800,960);p.camera.zoom=Vector2(1.5,1.5)
	p.position=Vector2(1700,1050);await snap("tree-stone")
	quit()

