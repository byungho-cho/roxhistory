extends SceneTree
# Run with --fixed-fps 60 for intermediate action-phase assertions. Production
# timers remain 1.2/2 seconds; Android touch validation uses normal wall time.
var app: Node
var checks := 0
var failed: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failed.append(message); push_error(message)
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/p3-"+name+".png")
func wait_work() -> void:
	var limit := 0
	while app.task != "" and limit < 180:
		await physics_frame; limit += 1
	check(app.task == "","Work finishes within bounded engine physics time")
func run() -> void:
	app = load("res://scenes/main.tscn").instantiate(); root.add_child(app)
	await process_frame
	app.start_region(); app.close_modal(); app.application_active = true
	var p: DemoPlayer = app.world.player
	p.set_character_3d(true)
	var fx: WorldFeedback = app.world.feedback
	p.position = Vector2(1360,830)
	await frames(4)
	check(app.world.selected == "wood_3","Nearby target is selected")
	app.gather_action(); await frames(20)
	check(app.model.state.wood == 0,"Impact does not grant resource before task commits")
	check(fx.events.has("impact:gather") and fx.particles.size()>0,"Timed strike produces material particles")
	await snap("wood-impact")
	app.joystick.value = Vector2.RIGHT; await frames(4); app.joystick.value = Vector2.ZERO
	check(app.task == "" and fx.activity == "" and app.model.state.wood == 0,"Movement cancels presentation without granting wood: "+str([app.task,fx.activity,app.model.state.wood]))
	check(not fx.events.has("credit:wood"),"Cancelled action has no success effect")
	app.gather_action(); await wait_work(); await frames(2)
	check(app.model.state.wood == 1 and fx.events.count("credit:wood") == 1,"One successful gather produces one wood and one credit cue")
	await snap("wood-credit")
	app.model.store.blocked = true
	app.gather_action(); await wait_work(); await frames(3)
	check(app.model.state.wood == 1 and fx.events.count("credit:wood") == 1,"Failed save never emits a second credit effect")
	check(app.modal,"Save failure remains visible to the player")
	app.model.store.blocked = false; app.close_modal()
	p.position = Vector2(1360,1080); await frames(4)
	check(app.world.selected == "stone_2","Stone target selected: "+app.world.selected)
	app.gather_action(); await wait_work(); await frames(2)
	check(app.model.state.stone == 1 and fx.events.count("credit:stone") == 1,"Stone credits once")
	await snap("stone-credit")
	p.position = Vector2(820,1060); await frames(4)
	app.build_action()
	var confirm: DemoButton = app.overlay.get_child(1).get_child(0).get_child(2).get_child(1)
	confirm.pressed.emit(); await frames(25)
	check(fx.preview.visible and fx.preview_progress > 0.1,"Construction grows visibly during work")
	check(not app.model.state.built and app.model.state.wood == 1,"Preview does not spend materials early")
	await snap("build-frame")
	app.go_back(); await frames(2)
	check(not fx.preview.visible and not app.model.state.built and app.model.state.stone == 1,"Back cancels preview and preserves materials")
	app.close_modal(); app.build_action()
	confirm = app.overlay.get_child(1).get_child(0).get_child(2).get_child(1)
	confirm.pressed.emit(); await frames(75)
	await snap("build-roof")
	await wait_work(); await frames(2)
	check(app.model.state.built and app.model.state.wood == 0 and app.model.state.stone == 0,"Completed build spends exactly 1+1")
	check(fx.events.count("built") == 1 and not fx.preview.visible and app.world.home.visible,"One permanent home replaces preview")
	check(app.modal,"Reward remains available after completion")
	await snap("complete-card")
	var reward: DemoButton = app.overlay.get_child(1).get_child(0).get_child(2).get_child(0)
	reward.pressed.emit(); reward.pressed.emit(); await frames(2)
	check(app.model.state.tokens == 10 and fx.events.count("reward") == 1,"Repeated reward input emits one reward and one effect")
	await snap("reward")
	app._notification(Node.NOTIFICATION_APPLICATION_PAUSED); await frames(2)
	check(fx.particles.is_empty() and fx.notices.is_empty(),"Background clears transient effects")
	app._notification(Node.NOTIFICATION_APPLICATION_RESUMED); await frames(2)
	var saved := GameState.new(SaveStore.new("user://tests/session"))
	check(saved.state.built and saved.state.reward_claimed and saved.state.tokens == 10,"Presentation preserves saved progress")
	# Persisted completed builds must not replay construction or rewards.
	app.world.queue_free(); app.world = null; await frames(2); app.enter_game(); await frames(4)
	check(app.world.home.visible and not app.world.feedback.preview.visible and app.world.feedback.events.is_empty(),"Continue restores home without replaying rewards")
	for size in [Vector2i(896,370),Vector2i(816,616),Vector2i(1280,720)]:
		root.size = size; await frames(4)
		# Reopen unclaimed reward presentation without changing inventory.
		app.model.state.reward_claimed = false; app.completion(); await frames(4)
		var rect: Rect2 = app.overlay.get_child(1).get_global_rect()
		check(rect.position.x>=0 and rect.position.y>=0 and rect.end.x<=app.w+1 and rect.end.y<=app.h+1,"Completion card fits viewport "+str(size))
		await snap("card-"+str(size.x)+"x"+str(size.y)); app.close_modal(); app.model.state.reward_claimed = true
	var report := {"checks":checks,"failed":failed,"utc":Time.get_datetime_string_from_system(true),"runtime":"Native Godot engine timers at fixed 60fps; explicit test positions, not Android wall-time play"}
	FileAccess.open("res://reports/interaction-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report)); quit(0 if failed.is_empty() else 1)
