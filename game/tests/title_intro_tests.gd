extends SceneTree
var checks := 0
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:failures.append(message);push_error(message)
func _initialize() -> void:call_deferred("run")
func frames(count: int) -> void:
	for i in count:await process_frame
func run() -> void:
	var app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await frames(5)
	app.model=GameState.new(SaveStore.new("user://title_intro_%s"%Time.get_ticks_usec()))
	app.show_screen("title")
	var start_rect: Rect2=app.title_prompt.get_rect()
	app.queue_layout() # Already scheduled on the title before tapping Start.
	app.start_or_continue()
	await frames(3)
	check(app.screen=="intro","Start opens intro before game")
	var intro=app.title_intro
	check(intro.player.stream is VideoStreamTheora,"Godot loads native Theora runtime")
	check(intro.player.is_playing(),"Video playback starts")
	check(intro.skip.text=="화면을 터치하여 스킵","Skip label")
	check(intro.skip.get_rect()==start_rect,"Skip shares exact start prompt position")
	app.start_or_continue()
	check(app.title_intro==intro,"Repeated start cannot restart video")
	app.queue_layout()
	app.relayout()
	await frames(3)
	check(app.title_intro==intro,"Resize callback keeps current player")
	app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(intro.player.paused,"Background pauses video")
	app._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(not intro.player.paused,"Foreground resumes video")
	intro.skip.pressed.emit()
	check(app.screen=="chapter","Skip preserves new-player chapter route")
	intro.finish()
	check(app.screen=="chapter","Duplicate completion is harmless")
	await frames(2)
	app.model.start_new()
	app.show_screen("title")
	app.start_or_continue()
	await frames(2)
	await create_timer(16.0).timeout
	check(app.screen=="play","Natural video end resumes existing village")
	await frames(3)
	app.show_screen("title")
	app.start_or_continue()
	await frames(2)
	app.go_back()
	check(app.screen=="play","Android Back skips intro")
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
