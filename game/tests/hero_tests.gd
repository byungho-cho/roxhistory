extends SceneTree
var failed: Array[String] = []
var checks := 0
var cues: Array[String] = []
func on_sound(key: String) -> void: cues.append(key)
func _initialize() -> void: call_deferred("run")
func check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok: failed.append(msg);push_error(msg)
func run() -> void:
	# The contact phase must be shared by pose and presentation, with no grants.
	check(is_equal_approx(HeroMotion.stroke(HeroMotion.CONTACT),1.0),"Stroke reaches contact at feedback beat")
	check(HeroMotion.stroke(HeroMotion.CYCLE*0.2)<0,"Anticipation precedes contact")
	check(absf(HeroMotion.stroke(HeroMotion.CYCLE))<0.001,"Recovery joins next cycle")
	for side in [-1.0,1.0]:
		for i in 16:
			var phase := TAU*i/16.0
			var foot := HeroMotion.step(phase,side)
			check(foot.y>=0 and foot.y<=0.096,"Swing never moves sole below support plane")
	# Use the application's real character for the entire fixture. Keep one
	# viewport lifetime rather than destroying and replacing it mid-frame.
	var app: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(app);await process_frame;app.start_region();app.close_modal();app.set_process(false)
	var p: DemoPlayer = app.world.player
	p.set_character_3d(true);p.set_process(false);p.set_physics_process(false)
	var hero := p.hybrid
	hero.walk_blend=0;hero.action_blend=1;hero.apply_pose(0,0)
	var standing_hips:=hero.rig.get_bone_global_pose(hero.bones.hips).origin
	var standing_feet: Array[Vector3]=[]
	for suffix in ["L","R"]: standing_feet.append(hero.rig.get_bone_global_pose(hero.bones["foot"+suffix]).origin)
	hero.apply_pose(0,1)
	check(hero.rig.get_bone_global_pose(hero.bones.hips).origin.distance_to(standing_hips)>0.02,"Contact transfers body weight")
	for i in 2:
		var suffix: String=["L","R"][i]
		check(hero.rig.get_bone_global_pose(hero.bones["foot"+suffix]).origin.distance_to(standing_feet[i])<0.003,"Leg articulation preserves support point during weight transfer")
	hero.action_blend=0
	for i in 30: hero.animate(1.0/60,Vector2.ZERO,0,false,"gather",i/60.0,false)
	hero.work_kind="wood";hero.animate(0,Vector2.ZERO,0,false,"gather",HeroMotion.CONTACT,false)
	var wood := hero.rig.get_bone_pose_rotation(hero.bones.armR)
	hero.work_kind="stone";hero.animate(0,Vector2.ZERO,0,false,"gather",HeroMotion.CONTACT,false)
	check(wood.angle_to(hero.rig.get_bone_pose_rotation(hero.bones.armR))>0.2,"Stone uses a lower swing than wood")
	var point := hero.tool_contact_world()
	check(point.is_finite() and point.distance_to(hero.global_position)<160,"Projected contact remains inside character working reach")
	hero.animate(1.0/60,Vector2.ZERO,0,false,"",0,false)
	check(hero.action_blend>0 and not hero.tool_3d.visible,"Cancellation stows tool while body releases pose")
	for i in 20: hero.animate(1.0/60,Vector2.ZERO,0,false,"",0,false)
	check(hero.action_blend==0,"Release reaches idle without stale work blend")
	hero.work_kind="build"
	for i in 30: hero.animate(1.0/60,Vector2.ZERO,0,false,"build",i/60.0,false)
	hero.animate(0,Vector2.ZERO,0,false,"build",HeroMotion.CONTACT,false)
	var build_hit := hero.rig.get_bone_global_pose(hero.bones.handR)*Vector3(0,0.025,0.43)
	check(hero.work_block.visible,"Construction has a visible timber workpiece")
	check(Vector2(build_hit.x,build_hit.z).distance_to(Vector2(hero.work_block.position.x,hero.work_block.position.z))<0.03,"Construction strike lands on timber top")
	check(absf(build_hit.y-hero.work_block.scale.y-0.04)<0.03 and hero.work_block.position.y==0,"Timber contacts the tool while supported by ground")
	hero.animate(1.0/60,Vector2.ZERO,0,false,"",0,false)
	check(not hero.work_block.visible,"Cancel removes temporary workpiece")
	p.set_character_3d(true);p.position=Vector2(1360,830);p.face_target(Vector2(1420,830));p.set_activity("gather")
	cues.clear()
	app.world.feedback.sound_cue.connect(on_sound)
	app.world.feedback.begin("gather","wood_3")
	app.world.feedback.update_work(HeroMotion.CONTACT-0.001,1.2)
	check(cues.is_empty(),"No early impact sound during preparation")
	app.world.feedback.update_work(HeroMotion.CONTACT,1.2)
	check(cues==["wood"],"Contact emits exactly one wood cue")
	check(app.world.feedback.impact_point.distance_to(p.hybrid.tool_contact_world())<0.01,"Particles and rendered tool share contact projection")
	check(app.model.state.wood==0,"Contact never credits before persistence commits")
	app.world.feedback.cancel()
	check(not p.external_work_clock,"Cancel releases shared work clock")
	app.world.feedback.sound_cue.disconnect(on_sound)
	app.audio.configure(false,false,false,false);await process_frame;await process_frame
	var report := {"checks":checks,"failed":failed,"utc":Time.get_datetime_string_from_system(true)}
	FileAccess.open("res://reports/hero-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report));quit(0 if failed.is_empty() else 1)
