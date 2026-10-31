extends SceneTree

var app: Node
var checks := 0
var failures: Array[String] = []

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		push_error(description)

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in count: await physics_frame

func touch_move(value: Vector2) -> void:
	app.joystick.value = value

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.start_region()
	app.close_modal()
	app.application_active = true
	var player: DemoPlayer = app.world.player
	await frames(3)
	check(player.motion_state == "idle","New player is idle")
	var idle_mesh := player.hybrid.rig.get_bone_pose(player.hybrid.bones.spine)
	await frames(30)
	check(player.hybrid.rig.get_bone_pose(player.hybrid.bones.spine) != idle_mesh,"Idle breathing animates the 3D spine")
	for entry in [[Vector2.DOWN,0],[Vector2.UP,1],[Vector2.LEFT,2],[Vector2.RIGHT,3]]:
		player.position = Vector2(1060,1030)
		var before := player.position
		touch_move(entry[0])
		await frames(10)
		check(player.motion_state == "walk" and player.facing == entry[1],"Direction selects matching walk: "+str(entry[1]))
		check(player.position.distance_to(before) > 10,"Walk moves body through physics")
		var mesh := player.hybrid.rig.get_bone_pose_rotation(player.hybrid.bones.thighR)
		await frames(8)
		check(player.hybrid.rig.get_bone_pose_rotation(player.hybrid.bones.thighR) != mesh,"Walk articulates the 3D leg")
		touch_move(Vector2.ZERO)
		await frames(3)
		check(player.motion_state == "idle" and player.facing == entry[1],"Stop preserves direction and returns to idle")
	# The production hero is now 3D-only: verify hand attachment at every phase.
	touch_move(Vector2.ZERO)
	for heading in [0.0,PI,-PI/2,PI/2]:
		player.hybrid.heading=heading;player.hybrid.target_heading=heading;player.hybrid.action_blend=1
		for t in [0.0,0.14,0.28,0.42]:
			player.hybrid.animate(0,Vector2.ZERO,0,false,"gather",t,false)
			var hand: Node3D=player.hybrid.attachments.handR
			check(player.hybrid.tool_3d.get_parent()==hand,"3D tool remains attached to the working hand")
			var tip:=player.hybrid.tool_contact_world()
			check(tip.is_finite() and tip.distance_to(player.position)<160,"Tool contact remains inside working reach in every heading")
	player.set_activity("")
	# Wall input must not animate walking in place or advance the distance clock.
	player.position = Vector2(45,1030)
	touch_move(Vector2.LEFT)
	await frames(50)
	check(player.motion_state == "idle","Blocked movement keeps planted feet")
	touch_move(Vector2.ZERO)
	player.position = DemoConfig.point(DemoConfig.get_data().nodes[0].position)+Vector2(70,0)
	await frames(3)
	app.gather_action()
	await frames(8)
	check(player.motion_state == "gather" and player.hybrid.tool_3d.visible,"Gather task drives visible tool and action pose")
	var before_gather: Vector2 = player.position
	touch_move(Vector2.RIGHT)
	await frames(4)
	check(app.task == "" and player.activity == "" and not player.hybrid.tool_3d.visible,"Movement cancels gather and clears tool")
	check(player.position.x > before_gather.x,"Moving after gather cancellation works")
	touch_move(Vector2.ZERO)
	await frames(3)
	app.gather_action()
	await frames(3)
	app.quest_details()
	await frames(3)
	check(app.task == "" and player.motion_state == "paused" and not player.hybrid.tool_3d.visible,"Popup interrupts action and pauses character")
	app.close_modal()
	await frames(3)
	check(player.motion_state == "idle","Closing popup returns to idle")
	app.gather_action()
	await frames(3)
	app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await frames(3)
	check(app.task == "" and player.motion_state == "paused","App pause cancels work and pauses character")
	app._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await frames(3)
	check(player.motion_state == "idle","App resume returns to idle without stale action")
	# Use real task durations rather than fast-forwarding the progress bar.
	app.start_region()
	app.close_modal()
	app.application_active = true
	player = app.world.player
	for id in ["wood_1","stone_1"]:
		for n in DemoConfig.get_data().nodes:
			if n.id != id: continue
			player.position = DemoConfig.point(n.position)+Vector2(70,0)
			await frames(3)
			app.gather_action()
			for tick in 120:
				if not app.gather_approach: break
				await frames(1)
			check(app.task=="gather" and not app.gather_approach,"Contact positioning finishes before measuring the real work duration")
			await create_timer(float(DemoConfig.get_data().gather_seconds)+0.15).timeout
			check(app.task == "" and app.model.state[n.kind] == 1,"One real-duration gather credits exactly one "+str(n.kind))
	check(app.model.can_build(),"Two gather actions unlock construction")
	player.position = DemoConfig.point(DemoConfig.get_data().build_site)+Vector2(90,30)
	await frames(3)
	app.build_action()
	check(app.modal,"Minimal materials open construction confirmation")
	var confirm: DemoButton = app.overlay.get_child(1).get_child(0).get_child(2).get_child(1)
	confirm.pressed.emit()
	await frames(5)
	check(player.motion_state == "build" and player.hybrid.tool_3d.visible,"Construction drives action animation")
	await create_timer(float(DemoConfig.get_data().build_seconds)+0.15).timeout
	check(app.model.state.built and app.modal and player.activity == "","Construction opens reward and clears action state")
	var reward: DemoButton = app.overlay.get_child(1).get_child(0).get_child(2).get_child(0)
	reward.pressed.emit()
	await frames(3)
	check(app.model.state.reward_claimed and app.model.state.tokens == 10,"Short loop grants exactly one reward")
	var saved := GameState.new(SaveStore.new("user://tests/session"))
	check(saved.state.built and saved.state.reward_claimed and saved.state.wood == 0 and saved.state.stone == 0,"Short loop survives save and reload")
	var report := {"checks":checks,"failed":failures,"runtime":"Native Godot physics/synthetic input, real action timers; not Android"}
	var file := FileAccess.open("res://reports/character-tests.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
