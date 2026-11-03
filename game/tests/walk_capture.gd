extends SceneTree
var app:Node
var p:DemoPlayer
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
	for i in n:
		await physics_frame
		p.camera.position=p.position+Vector2(0,-55)
		p.camera.force_update_scroll()
		await RenderingServer.frame_post_draw
func run()->void:
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await process_frame
	app.start_region();app.close_modal();app.set_process(false);p=app.world.player
	app.canvas.visible=false
	for a in app.world.animals:a.visible=false;a.set_physics_process(false)
	for r in app.world.residents:r.visible=false;r.set_physics_process(false);r.collision_layer=0
	p.camera.top_level=true;p.camera.position_smoothing_enabled=false;p.camera.zoom=Vector2(1.4,1.4)
	var layer:=CanvasLayer.new();root.add_child(layer);var label:=Label.new();label.theme=DemoArt.theme();label.position=Vector2(24,18);label.add_theme_constant_override("outline_size",5);label.add_theme_color_override("font_outline_color",Color("33271d"));layer.add_child(label)
	for pose in [["front",Vector2.DOWN,Vector2(1300,950)],["side",Vector2.RIGHT,Vector2(1300,1100)],["back",Vector2.UP,Vector2(1300,1150)]]:
		p.position=pose[2];p.direction=Vector2.ZERO;p.phase=0
		label.text="%s · %.2f world units/s · 60 fps / 1×"%[pose[0],DemoConfig.get_data().move_speed]
		await frames(20);p.direction=pose[1];await frames(45)
		root.get_texture().get_image().save_png("res://reports/walk-"+pose[0]+".png")
		await frames(45);p.direction=Vector2.ZERO;await frames(30)
	quit()
