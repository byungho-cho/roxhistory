extends SceneTree
func _initialize():call_deferred("run")
func run():
	var hero:=HybridCharacter.new();root.add_child(hero);hero.set_enabled(true)
	hero.viewport.size=Vector2i(256,256);hero.camera.size=1.60
	hero.camera.position=Vector3(0,1.95,6);hero.camera.look_at(Vector3(0,1.88,0))
	hero.tool_3d.visible=false
	for i in 20:await process_frame
	await RenderingServer.frame_post_draw
	hero.viewport.get_texture().get_image().save_png("res://assets/ui/hero_portrait.png")
	quit()
