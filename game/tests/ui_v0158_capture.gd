extends SceneTree
var app:Node
func _initialize()->void:call_deferred("run")
func frames(n:int=5)->void:
	for i in n:await process_frame
	await RenderingServer.frame_post_draw
func capture(name:String)->void:
	await frames();root.get_texture().get_image().save_png("res://reports/v0158-"+name+".png")
func run()->void:
	root.size=Vector2i(1280,720)
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames()
	await capture("start")
	app.chapter_menu();await capture("chapter")
	app.model=GameState.new(SaveStore.new("user://v0158-capture"));app.model.start_new();app.model.changed.connect(app.update_hud);app.enter_game();await frames(12)
	app.quest_details();await capture("quest")
	app.close_modal();await capture("play")
	app.queue_free();await frames();quit()
