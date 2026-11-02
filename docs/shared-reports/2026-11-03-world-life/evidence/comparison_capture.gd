extends SceneTree
func _initialize(): call_deferred("run")
func run():
 var app=load("res://scenes/main.tscn").instantiate()
 root.add_child(app)
 for i in 2: await process_frame
 app.model.start_new(); app.start_region(); app.close_modal()
 for i in 30: await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("C:/Users/sentr/Documents/Codex/2026-10-30/new-chat/worldlife-evidence/before-settlement.png")
 quit()
