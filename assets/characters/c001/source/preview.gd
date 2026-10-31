extends SceneTree
func _initialize():
	call_deferred("run")
func run():
	var bg:=ColorRect.new()
	bg.color=Color("e8decb");bg.size=Vector2(1600,900);root.add_child(bg)
	var captions:=["FRONT","THREE-QUARTER","SIDE","BACK"]
	for i in 4:
		var hero:=HybridCharacter.new();root.add_child(hero);hero.set_enabled(true)
		hero.viewport.size=Vector2i(800,1000)
		hero.camera.size=3.5
		hero.camera.position=Vector3(0,2.2,7)
		hero.camera.look_at(Vector3(0,1.5,0))
		hero.pivot.rotation.y=[0.0,0.65,PI/2,PI][i]
		hero.tool_3d.visible=false
		hero.display.scale=Vector2(0.48,0.48)
		hero.display.position=Vector2.ZERO
		hero.position=Vector2(8+i*398,180)
		for side in [-1.0,1.0]:
			hero.rotate_bone("arm"+("L" if side<0 else "R"),Vector3(0,0,side*0.22))
		var label:=Label.new();label.text=captions[i];label.position=Vector2(110+i*398,720);label.add_theme_font_size_override("font_size",23);label.modulate=Color("453429");root.add_child(label)
	var title:=Label.new();title.text="ROXHISTORY  /  CHARACTER MODEL C001 v0.3 STUDY 04";title.position=Vector2(54,40);title.add_theme_font_size_override("font_size",32);title.modulate=Color("453429");root.add_child(title)
	var note:=Label.new();note.text="Actual game model source  -  visual fidelity remains under review";note.position=Vector2(54,820);note.modulate=Color("645443");root.add_child(note)
	for j in 30: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://c001-study-04.png")
	quit()
