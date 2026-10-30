extends SceneTree
var app: Node
var player: DemoPlayer
var title: Label
func _initialize() -> void: call_deferred("run")
func segment(text: String, movement: Vector2, action: String, count: int) -> void:
	title.text = text
	player.direction = movement
	player.set_activity(action)
	for i in count:
		await physics_frame
		if player.camera.top_level: player.camera.position = player.position+Vector2(0,-70)
		await RenderingServer.frame_post_draw
func snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/"+label+".png")
func run() -> void:
	app = load("res://scenes/main.tscn").instantiate(); root.add_child(app); await process_frame
	app.start_region();app.close_modal();app.set_process(false);app.canvas.visible = false
	player=app.world.player
	player.camera.top_level=true;player.camera.zoom=Vector2(1.4,1.4)
	var layer:=CanvasLayer.new();root.add_child(layer)
	title=Label.new();title.theme=DemoArt.theme();title.position=Vector2(24,20)
	title.add_theme_color_override("font_outline_color",Color("302418"));title.add_theme_constant_override("outline_size",5);layer.add_child(title)
	for mode in [false,true]:
		player.set_character_3d(mode)
		var label: String = "3D" if mode else "2D"
		player.position=Vector2(1060,1030);player.facing=0;player.hybrid.heading=0;player.hybrid.target_heading=0
		await segment(label+" · 같은 위치 / 대기",Vector2.ZERO,"",45);await snap("compare-"+label+"-idle")
		for movement in [Vector2.DOWN,Vector2(0.7,0.7),Vector2.RIGHT,Vector2(0.7,-0.7),Vector2.UP,Vector2(-0.7,-0.7),Vector2.LEFT]:
			player.position=Vector2(1060,1030)
			await segment(label+" · 직선·대각선 / 회전",movement,"",22)
		await segment(label+" · 정지",Vector2.ZERO,"",12)
		player.position=Vector2(1060,1030);player.face_target(player.position+Vector2(1,0.4))
		await segment(label+" · 채집 / 어깨·팔·도구",Vector2.ZERO,"gather",50);await snap("compare-"+label+"-gather")
		await segment(label+" · 중단 후 대기",Vector2.ZERO,"",20)
	player.set_character_3d(true);player.camera.top_level=false;player.camera.position=Vector2(180,-220);player.fit_camera();app.canvas.visible=true;layer.queue_free()
	await segment("",Vector2.ZERO,"",15);await snap("hybrid-world")
	quit()
