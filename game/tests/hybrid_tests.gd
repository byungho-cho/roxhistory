extends SceneTree
var app: Node
var checks := 0
var failed: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failed.append(message); push_error(message)
func frames(n: int) -> void:
	for i in n: await physics_frame
func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.start_region(); app.close_modal(); app.application_active = true
	var p: DemoPlayer = app.world.player
	p.set_character_3d(true)
	await frames(4)
	check(p.hybrid.rig.get_bone_count() == 15,"Real 15-bone skeleton")
	check(p.hybrid.mesh_count > 40,"Volumetric meshes built")
	check(p.hybrid.viewport.own_world_3d and p.hybrid.viewport.transparent_bg,"Isolated transparent 3D render")
	var foot_anchor: Vector2 = p.hybrid.display.position
	for a in [0.0,0.4,0.785,1.57,2.4,3.14,-2.4,-1.57,-0.4]:
		p.position = Vector2(1050,1030)
		app.joystick.value = Vector2(sin(a),cos(a))
		await frames(24)
		check(absf(angle_difference(p.hybrid.heading,a)) < 0.15,"Intermediate angle follows joystick")
		check(p.hybrid.display.position == foot_anchor,"Projected foot anchor stable while turning")
	app.joystick.value = Vector2.ZERO
	await frames(12)
	check(p.hybrid.walk_blend < 0.01,"Stopping settles the legs")
	p.position = Vector2(40,1030); app.joystick.value = Vector2.LEFT
	await frames(50)
	check(p.hybrid.walk_blend < 0.01,"Wall does not keep playing walk")
	app.joystick.value = Vector2.ZERO
	p.position = Vector2(1360,830)
	await frames(3); app.gather_action(); await frames(20)
	check(p.hybrid.tool_3d.visible and p.hybrid.action_blend > 0.9,"Gather drives skeletal action and tool")
	check(p.hybrid.rig.get_bone_pose_rotation(p.hybrid.bones.armR) != Quaternion.IDENTITY,"Shoulder rotates in 3D")
	app.quest_details(); await frames(4)
	check(not p.hybrid.tool_3d.visible and app.task == "","Popup clears action")
	app.close_modal(); await frames(12)
	var before: Vector2 = p.position
	var state: Dictionary = app.model.state.duplicate(true)
	app.toggle_character(); await frames(3)
	check(not p.use_3d and p.sprite.visible,"Switch back to original 2D")
	check(p.hybrid.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED,"2D stops 3D rendering cost")
	check(p.position == before and app.model.state == state,"Comparison preserves world and save")
	app.toggle_character(); await frames(3)
	check(p.use_3d and not p.sprite.visible,"Switch again without duplicate character")
	var report := {"checks":checks,"failed":failed,"utc":Time.get_datetime_string_from_system(true)}
	var f := FileAccess.open("res://reports/hybrid-tests.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"  ")); print(JSON.stringify(report))
	quit(0 if failed.is_empty() else 1)
