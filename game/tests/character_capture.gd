extends SceneTree

var app: Node
var player: DemoPlayer
var title: Label

func _initialize() -> void:
	call_deferred("run")

func segment(text: String, movement: Vector2, action: String, count: int) -> void:
	title.text = text
	player.direction = movement
	player.set_activity(action)
	for i in count:
		await physics_frame
		await RenderingServer.frame_post_draw

func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/"+name+".png")

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://reports")
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.start_region()
	app.close_modal()
	app.set_process(false)
	app.canvas.visible = false
	player = app.world.player
	player.position = Vector2(1060,1030)
	player.camera.top_level = true
	player.camera.position = player.position+Vector2(0,-70)
	player.camera.zoom = Vector2(2.2,2.2)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	title = Label.new()
	title.theme = DemoArt.theme()
	title.position = Vector2(24,20)
	title.add_theme_font_size_override("font_size",24)
	title.add_theme_color_override("font_outline_color",Color("35271b"))
	title.add_theme_constant_override("outline_size",5)
	layer.add_child(title)
	await segment("P2 · 대기 / 호흡",Vector2.ZERO,"",45)
	await snap("character-idle")
	for entry in [[Vector2.DOWN,0,"앞"],[Vector2.UP,1,"뒤"],[Vector2.LEFT,2,"왼쪽"],[Vector2.RIGHT,3,"오른쪽"]]:
		player.position = Vector2(1060,1030)
		await segment("P2 · "+str(entry[2])+" 걷기",entry[0],"",28)
		await snap("character-walk-"+str(entry[1]))
		await segment("P2 · 정지 → 대기",Vector2.ZERO,"",12)
	player.position = Vector2(1060,1030)
	player.facing = 0
	await segment("P2 · 채집 동작",Vector2.ZERO,"gather",50)
	await snap("character-gather")
	player.facing = 2
	await segment("P2 · 옆 방향 채집",Vector2.ZERO,"gather",50)
	await snap("character-gather-side")
	player.presentation_paused = true
	await segment("P2 · 일시 정지",Vector2.ZERO,"",20)
	player.presentation_paused = false
	await segment("P2 · 복귀",Vector2.ZERO,"",20)
	app.canvas.visible = true
	layer.queue_free()
	player.camera.top_level = false
	player.camera.position = Vector2(180,-220)
	player.fit_camera()
	await segment("",Vector2.ZERO,"",15)
	await snap("character-world")
	quit()
