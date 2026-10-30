extends SceneTree
# Same deterministic camera, location, size and script for before/after evidence.
var app: Node
var p: DemoPlayer
var title: Label
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n:
		await physics_frame
		if p.camera.top_level: p.camera.position = p.position+Vector2(0,-70)
		await RenderingServer.frame_post_draw
func snap(name: String) -> void:
	root.get_texture().get_image().save_png("res://reports/hero-"+name+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://reports")
	app=load("res://scenes/main.tscn").instantiate(); root.add_child(app); await process_frame
	app.start_region(); app.close_modal(); app.set_process(false)
	p=app.world.player; p.set_character_3d(true); p.position=Vector2(1060,1030)
	app.canvas.visible=false; p.camera.top_level=true; p.camera.zoom=Vector2(1.4,1.4)
	var layer:=CanvasLayer.new();root.add_child(layer)
	title=Label.new();title.theme=DemoArt.theme();title.position=Vector2(24,20)
	title.add_theme_color_override("font_outline_color",Color("302418"));title.add_theme_constant_override("outline_size",5);layer.add_child(title)
	for entry in [[0.0,"front"],[PI/2,"side"],[PI,"back"]]:
		title.text="주인공 · "+entry[1]+" / 같은 위치·카메라·크기"
		p.hybrid.heading=entry[0];p.hybrid.target_heading=entry[0];await frames(60);snap(entry[1])
	p.camera.top_level=false;p.camera.position=Vector2(180,-220);p.fit_camera();app.canvas.visible=true;title.text="실제 플레이 크기";p.hybrid.target_heading=0
	await frames(60);snap("world")
	app.canvas.visible=false;p.camera.top_level=true;p.camera.zoom=Vector2(1.4,1.4)
	for v in [Vector2.DOWN,Vector2(1,1).normalized(),Vector2.RIGHT,Vector2(1,-1).normalized(),Vector2.UP,Vector2(-1,-1).normalized(),Vector2.LEFT,Vector2(-1,1).normalized()]:
		title.text="이동 · 직선/대각선 · 정지";p.position=Vector2(1060,1030);p.direction=v;await frames(36);p.direction=Vector2.ZERO;await frames(18)
	title.text="급회전 · 입력 반응";p.direction=Vector2.RIGHT;await frames(24);p.direction=Vector2.LEFT;await frames(24);p.direction=Vector2.ZERO;await frames(24)
	for action in ["gather","build"]:
		p.position=Vector2(1060,1030);p.hybrid.target_heading=PI/3;p.set_activity(action);title.text="동작 관찰 · "+action
		await frames(18);snap(action);await frames(42);p.set_activity("");await frames(30)
	quit()
