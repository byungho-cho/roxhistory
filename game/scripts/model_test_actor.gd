extends RefCounted
# Z90000 owns its clock and presentation; no hunt rules or saved state are created.
const Catalog = preload("res://scripts/lab_motion_catalog.gd")
const Residents = preload("res://scripts/res011_lab_preview.gd")
const Uram = preload("res://scripts/uram_lab_rig.gd")
const Wildlife = preload("res://scripts/wildlife_lab.gd")
const Animal = preload("res://scripts/wildlife_lab_preview.gd")
const Hunt = preload("res://scripts/deer_hunt_screen.gd")
const Poly = preload("res://scripts/model_test_poly_catalog.gd")
const RunPreview=preload("res://scripts/run_comparison_preview.gd")
const Profile=preload("res://scripts/model_motion_profile.gd")
const DeathEffect=preload("res://scripts/model_death_effect.gd")
const ANIMAL_ORDER=["idle","walk","run","attack","hit","skill","death"]
const ALLY_ORDER=["idle","walk","run","attack","hit","guard","counter","skill","chain","death"]
var key:String
var preview:HybridCharacter
var motion := "idle"
var segments:Array = []
var duration := 0.0
var active_clip := ""
var stride:=Vector3.ZERO
var root_start:=Vector3.ZERO
var support_yaw:=0.0
var death_effect:Node2D

func resident_root()->Vector3:
	return preview.skeleton.get_bone_pose_position(preview.root_bone)

func resident_sample(id:String,clock:float)->void:
	if preview is Uram:preview.show_pose(clip_for(id),clock)
	elif preview is RunPreview and id=="run":preview.sample_motion(id,clock)
	else:preview.sample_clip(clip_for(id),clock)

func create(parent:Node, id:String,comparison_b:=false,run_variant:="")->void:
	key=id
	if Wildlife.ANIMALS.has(key):
		preview=Animal.new()
		preview.model_path=Profile.ANIMAL_MODELS[key]
		preview.profile_key=key
	elif key=="uram":
		preview=Uram.new();preview.use_retouch=true;preview.extra_motions=true
	else:
		preview=Residents.new() if run_variant.is_empty() else RunPreview.new()
		preview.character=key;preview.shared_motion_view=true;preview.extra_motions=run_variant.is_empty()
		if not run_variant.is_empty():preview.variant=run_variant
		if key=="hangyeol":preview.excluded_playlist_clips=PackedStringArray(["stone_spear_thrust"])
	preview.render_size_factor=.75
	parent.add_child(preview)
	death_effect=DeathEffect.new(not Wildlife.ANIMALS.has(key));parent.add_child(death_effect)
	preview.tree_exiting.connect(func():
		if is_instance_valid(death_effect):death_effect.clear();death_effect.queue_free())
	preview.set_enabled(true)
	preview.viewport.size=Vector2i(1536,960)
	preview.camera.size=7.0*960.0/720.0
	configure(false)
	if key=="saebom" and run_variant.is_empty():
		resident_sample("chain",2.72)
		var skeleton=preview.skeleton
		var chest=skeleton.get_bone_global_pose(skeleton.find_bone("spine")).origin
		var hands=(skeleton.get_bone_global_pose(skeleton.find_bone("hand.R")).origin+skeleton.get_bone_global_pose(skeleton.find_bone("hand.L")).origin)*.5
		var gesture=preview.pivot.global_basis.inverse()*skeleton.global_basis*(hands-chest)
		support_yaw=atan2(gesture.x,gesture.z)
		resident_sample("idle",0.0)

func screen_anchor()->Vector2:
	var skeleton=preview.skeleton
	var bone=skeleton.find_bone("spine")
	if bone<0:bone=preview.root_bone
	var point=skeleton.global_transform*skeleton.get_bone_global_pose(bone).origin
	return preview.position+(preview.display.position+preview.camera.unproject_position(point)*preview.display.scale)*preview.scale

func face_support(target:Vector2)->void:
	# Calibrate the authored palm gesture, then invert the current camera's
	# ground projection. Actor ground markers are not always at chest centers.
	var origin=preview.camera.unproject_position(Vector3.ZERO)
	var x=preview.camera.unproject_position(Vector3.RIGHT)-origin
	var z=preview.camera.unproject_position(Vector3.BACK)-origin
	for i in 2:
		var delta=target-screen_anchor()
		var world=Vector2(delta.cross(z),x.cross(delta))/x.cross(z)
		preview.pivot.rotation.y=atan2(world.x,world.y)-support_yaw

func configure(battle:bool)->void:
	var animal := Wildlife.ANIMALS.has(key)
	preview.camera.position=Vector3(0,6.65,6) if battle and animal else Vector3(0,7.05,6) if battle else Residents.GAME_CAMERA
	preview.camera.look_at(Vector3(0,1,0) if battle and animal else Vector3(0,1.45,0) if battle else Residents.GAME_AIM)
	var direction:Vector2=Hunt.DEER_SLOT-Hunt.HUNTER_BATTLE_CENTER
	preview.pivot.rotation.y=-PI*.35 if battle and animal else atan2(direction.x,direction.y) if battle else Residents.MOTION_HEADING
	preview.display.position=-preview.camera.unproject_position(Vector3.ZERO)*preview.display.scale

func clip_for(id:String)->String:
	if Wildlife.ANIMALS.has(key):
		return Profile.animal_clip(key,id)
	if Profile.ALLY_CLIPS[key].has(id):return Profile.ALLY_CLIPS[key][id]
	return Catalog.CLIPS[key].get(id,"")

func supported(id:String)->bool:
	return id=="full" or not clip_for(id).is_empty()

func span(id:String)->float:
	if preview is Animal:
		if id=="skill":return preview.length("req046_skill_anticipation")+preview.length("req046_skill_execute")
		return preview.presentation_length(clip_for(id))
	if preview is Uram:return preview.clip_length(clip_for(id))
	if preview is RunPreview and id=="run":return preview.motion_duration(id)
	var clip:=clip_for(id)
	return Residents.Timing.duration(key,clip,preview.animation.get_animation(clip).length)

func play(id:String)->void:
	death_effect.clear();preview.modulate.a=1.0
	motion=id if supported(id) else "idle"
	active_clip=""
	segments.clear()
	duration=0
	if motion=="full":
		var included:Array=[]
		for item in (ANIMAL_ORDER if preview is Animal else ALLY_ORDER):
			if supported(item):
				var clip:=clip_for(item)
				if clip in included:continue
				included.append(clip)
				var length:=span(item)*(2 if item in ["walk","run"] else 1)
				segments.append({"key":item,"start":duration,"end":duration+length})
				duration+=length
	else:duration=span(motion)
	stride=Vector3.ZERO
	if motion in ["walk","run"] and not preview is Animal:
		resident_sample(motion,0)
		root_start=resident_root()
		resident_sample(motion,duration-.00001)
		stride=resident_root()-root_start;stride.y=0
		resident_sample(motion,0)

func sample(age:float, route:bool)->void:
	var id:=motion
	var at:=age
	if not segments.is_empty():
		var last:Dictionary=segments[-1]
		id=last.key;at=maxf(0,age-float(last.start))
		for segment in segments:
			if age<float(segment.end):id=segment.key;at=age-float(segment.start);break
	elif id!="death" and id not in Catalog.REPEATS and age>=duration:id="idle";at=maxf(0,age-duration)
	var period:=span(id)
	var moving:=id in ["walk","run"]
	var travel_period:=period
	if moving and preview is Residents:travel_period*=Residents.Timing.rate(key,clip_for(id))
	if route and moving:at=minf(at,travel_period*2)
	var clock:=fposmod(at,period) if id in Catalog.REPEATS else at
	if route and moving and at>=travel_period*2:clock=period-.00001
	# The animal adapter preserves native root travel and stops after two cycles.
	if preview is Animal:
		var clip:=clip_for(id)
		if id=="skill":
			var preparation:float=preview.length("req046_skill_anticipation")
			clip="req046_skill_anticipation" if at<preparation else "req046_skill_execute"
			at=at if at<preparation else at-preparation
		if active_clip!=clip:preview.start(clip);active_clip=clip
		preview.sample(at,route)
	else:
		resident_sample(id,clock)
		if route and moving and stride.length()>.02:
			if preview is Residents:
				# Visual cadence changes never multiply the preview's path velocity.
				preview.pivot.position+=preview.skeleton.global_basis*stride*(at/travel_period)
			else:
				var cycles:=mini(1,floori(at/period))
				var anchor:=resident_root()-root_start;anchor.y=0
				preview.pivot.position+=preview.skeleton.global_basis*(anchor+stride*cycles)
	# Resident locomotion is authored in-place in the deployed lab. Move only
	# the 2D ground anchor for its fixed path, never the camera or skill roots.
	preview.set_meta("route_fraction",clampf(at/(travel_period*2),0,1) if route and moving and not preview is Animal and stride.length()<=.02 else 0.0)
	if id=="death":
		preview.modulate.a=DeathEffect.model_alpha(at)
		death_effect.sample(at)
	else:
		preview.modulate.a=1.0
		death_effect.clear()
	preview.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE

func place_effect()->void:
	death_effect.position=preview.position
	death_effect.scale=preview.scale


