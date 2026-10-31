extends SceneTree
func _initialize():call_deferred("run")
func run():
	var bg:=ColorRect.new();bg.color=Color("fffdf4");bg.size=Vector2(1024,1024);root.add_child(bg)
	var path:=ProjectSettings.globalize_path("res://../../../../docs/shared-reports/2026-10-31-c001-character-ui/evidence/c001-v03-authoritative.png")
	var reference:=TextureRect.new();reference.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;reference.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;reference.texture=ImageTexture.create_from_image(Image.load_from_file(path));reference.size=Vector2(1024,512);root.add_child(reference)
	for i in 4:
		var hero:=HybridCharacter.new();root.add_child(hero);hero.set_enabled(true)
		hero.viewport.size=Vector2i(256,500);hero.camera.size=3.35
		hero.camera.position=Vector3(0,1.5,7);hero.camera.look_at(Vector3(0,1.5,0))
		hero.pivot.rotation.y=[0.0,PI,-PI/2,PI/2][i];hero.tool_3d.visible=false
		hero.display.scale=Vector2.ONE;hero.display.position=Vector2.ZERO;hero.position=Vector2(i*256,520)
		for side in [-1.0,1.0]:hero.rotate_bone("arm"+("L" if side<0 else "R"),Vector3(0,0,side*.22))
		var label:=Label.new();label.text=["MODEL / FRONT","MODEL / BACK","MODEL / LEFT","MODEL / RIGHT"][i];label.position=Vector2(i*256+50,515);label.modulate=Color("503c29");root.add_child(label)
	for i in 20:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://c001-reference-comparison.png")
	quit()
