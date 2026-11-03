extends SceneTree
var app:Node
var checks:=0
var failed:Array[String]=[]
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
	for i in n:await physics_frame;await process_frame
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failed.append(label);push_error(label)
func run()->void:
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames(2);app.start_region();app.close_modal();await frames(3)
	var p:DemoPlayer=app.world.player
	check(is_equal_approx(float(DemoConfig.get_data().move_speed),151.25*1.2),"Speed is exactly twenty percent over baseline")
	check(ProjectSettings.get_setting("display/window/handheld/orientation")==0,"Android is landscape locked")
	check(HybridCharacter.WALK_CLIP.get_track_count()==30 and HybridCharacter.WALK_CLIP.loop_mode==Animation.LOOP_LINEAR,"Existing fifteen bones use a saved looping animation clip")
	for track in HybridCharacter.WALK_CLIP.get_track_count():
		check(HybridCharacter.WALK_CLIP.track_get_key_count(track)==65,"Baked editable bone keys: "+str(track))
	for a in app.world.animals:a.set_physics_process(false)
	for r in app.world.residents:r.set_physics_process(false)
	var hut:EnvironmentProp=app.world.get_node("ExistingHut")
	for side in [-1,1]:
		var pose:=p.transform;pose.origin=hut.position+Vector2(side*140,-25)
		check(p.test_move(pose,Vector2.ZERO,null,.08,true),"Hut visual flank is blocked: "+str(side))
		p.position=hut.position+Vector2(side*200,-25);p.direction=Vector2(-side,0);await frames(45);p.direction=Vector2.ZERO
		check(absf(p.position.x-hut.position.x)>140,"Joystick cannot penetrate eaves footprint: "+str(side))
	p.position=hut.position+Vector2(-200,-25);app.navigation.start("move","",hut.position+Vector2(200,-25))
	var crossed:=false
	for i in 350:
		await frames(1)
		crossed=crossed or Geometry2D.is_point_in_polygon(p.position-hut.position,EnvironmentProp.hut_footprint(300))
	check(not crossed,"Automatic route never enters hut footprint")
	check(p.position.distance_to(hut.position+Vector2(200,-25))<6,"Automatic route reaches opposite side of hut")
	app.cancel_task();var target:Vector2=app.world.art_nodes.wood_3.position;p.position=target+Vector2(-85,5);await frames(3)
	var before:=p.position;app.world_tap(app.world.get_global_transform_with_canvas()*target)
	check(app.task=="gather" and not p.work_destination.is_finite(),"Nearby resource tap starts stationary work")
	await frames(75)
	check(p.position.distance_to(before)<.5 and app.model.state.wood==1,"Near gathering does not move feet and grants once")
	app.cancel_task();p.position=target+Vector2(-280,100);await frames(3);app.world_tap(app.world.get_global_transform_with_canvas()*target)
	check(app.navigation.action=="gather","Far resource still approaches")
	await frames(240);check(app.model.state.wood==2,"Far approach gathers exactly once")
	check(app.world.residents.size()==2,"Exactly two prototype residents, no life system")
	for r in app.world.residents:
		check(r.visual.rig.get_bone_count()==15 and r.visual.skinned_limbs.size()==1,"Resident reuses humanoid skin and rig: "+r.variant)
		check(r.visual.model_path.contains(r.variant),"Resident uses its distinct model: "+r.variant)
	var report:Dictionary={"checks":checks,"failed":failed,"runtime":"Native Godot, actual movement/physics, synthetic input; no physical-device claim"}
	FileAccess.open("res://reports/walk-residents-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failed.is_empty() else 1)
