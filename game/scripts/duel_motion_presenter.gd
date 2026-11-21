extends RefCounted
## Lab-only presentation. Never schedules damage or alters source animations.
const PREPARE_SECONDS := .65
const HP_SECONDS := .22
var hp := [100.0,100.0]
var hp_from := [100.0,100.0]
var hp_target := [100.0,100.0]
var hp_age := [0.0,0.0]
var poses := [{},{}]
var blend_from := [{},{}]
var blend_age := [1.0,1.0]
var phase := ["",""]
var hand := -1
var tip_in_hand := Vector3.ZERO
var spear_skeleton: Skeleton3D
var thrust_yaw := 0.0
var thrust_peak := Vector2.ZERO
var thrust_target := Vector2.ZERO
var grounded_spear := false
var recoil := [Vector2.ZERO,Vector2.ZERO]
var recoil_age := [1.0,1.0]
var ready_yaw:=0.0

func reset(health:Array)->void:
	for i in 2:
		hp[i]=float(health[i]);hp_from[i]=hp[i];hp_target[i]=hp[i];hp_age[i]=0
	poses=[{},{}];blend_from=[{},{}];blend_age=[1.0,1.0];phase=["",""]
	recoil=[Vector2.ZERO,Vector2.ZERO];recoil_age=[1.0,1.0]

func anchor_spear_root(actor)->void:
	# Extract authored planar root motion in this matchup only. Jump height,
	# limbs and weapon remain authored; movement belongs to the target-aware path.
	if not grounded_spear or actor.key!="hangyeol":return
	var sk:Skeleton3D=actor.preview.skeleton
	var root:int=actor.preview.root_bone
	var pose:=sk.get_bone_pose_position(root)
	var rest:=sk.get_bone_rest(root).origin
	pose.x=rest.x;pose.z=rest.z;sk.set_bone_pose_position(root,pose)
	actor.preview.pivot.position=Vector3.ZERO
	sk.force_update_all_bone_transforms()

func update_hp(health:Array,delta:float)->void:
	for i in 2:
		if hp_target[i]!=float(health[i]):
			hp_from[i]=hp[i];hp_target[i]=float(health[i]);hp_age[i]=0
		hp_age[i]=minf(HP_SECONDS,hp_age[i]+delta)
		hp[i]=lerpf(hp_from[i],hp_target[i],smoothstep(0,HP_SECONDS,hp_age[i]))

func attack_sample(age:float,duration:float)->float:
	# Preparation begins before the existing attack clock, without an impact.
	# The original .55 contact and entire authored recovery remain unchanged.
	var contact:=duration*.55
	return lerpf(duration*.22,contact,clampf(age/contact,0,1)) if age<contact else age

func sample(actor,side:int,key:String,age:float,until_attack:float,delta:float,extract_planar:=true)->void:
	var next_phase:=key
	var recovering:=key=="hit" and age>=minf(.14,actor.duration*.35)
	if (key=="idle" or recovering) and until_attack>0 and until_attack<PREPARE_SECONDS:
		next_phase="prepare"
		var windup:float=actor.span("attack")*.22*(1.0-smoothstep(0,PREPARE_SECONDS,until_attack))
		if side==0:
			actor.resident_sample("attack",windup)
		else:
			# Animal adapter owns its clip state; sample only its wind-up, never contact.
			actor.preview.start(actor.clip_for("attack"))
			actor.preview.sample(windup,false)
			actor.active_clip="" # Restore the authoritative motion on the next sample.
	elif grounded_spear and side==1 and key=="death":
		# Read the authored fall before the existing one-second reset. Do not
		# use the generic model-test effect that hides the mesh at .18 seconds.
		actor.preview.start(actor.clip_for("death"))
		actor.preview.sample(minf(age/.78,1.0)*actor.duration,false)
		actor.preview.modulate.a=1.0-smoothstep(.78,1.0,age)
		actor.death_effect.clear()
		if age>=.65:actor.death_effect.sample(age-.65+.08)
	else:
		actor.sample(attack_sample(age,actor.duration) if key=="attack" else age,false)
	if side==0 and extract_planar:anchor_spear_root(actor)
	var sk:Skeleton3D=actor.preview.skeleton
	if phase[side]!=next_phase:
		blend_from[side]=poses[side].duplicate(true);blend_age[side]=0;phase[side]=next_phase
	# Crossfade local bone poses, including additional clips whose adapter resets
	# rests. This does not touch the shared AnimationPlayer or timing profiles.
	blend_age[side]+=delta
	var weight:=smoothstep(0,.06 if next_phase=="hit" else .16,blend_age[side])
	var previous:Dictionary=blend_from[side]
	var current:Dictionary={}
	for i in sk.get_bone_count():
		var p:=sk.get_bone_pose_position(i);var q:=sk.get_bone_pose_rotation(i);var s:=sk.get_bone_pose_scale(i)
		if weight<1 and previous.has(i):
			p=previous[i][0].lerp(p,weight);q=previous[i][1].slerp(q,weight);s=previous[i][2].lerp(s,weight)
			sk.set_bone_pose_position(i,p);sk.set_bone_pose_rotation(i,q);sk.set_bone_pose_scale(i,s)
		current[i]=[p,q,s]
	poses[side]=current
	sk.force_update_all_bone_transforms()
	actor.preview.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE

func prepare_spear(actor,origin:Vector2,target:Vector2,contact:float,preferred_travel:=78.0)->void:
	var p=actor.preview
	thrust_target=target+Vector2(0,33)
	cache_spear(actor)
	# Do not calibrate from a partially blended idle/attack pose. The lab's
	# explicit bone crossfade below owns the transition used in actual play.
	p.animation.play(actor.clip_for(actor.motion),0.0)
	p.animation.advance(0)
	actor.sample(contact,false)
	anchor_spear_root(actor)
	spear_skeleton.force_update_all_bone_transforms()
	var ideal:=origin+origin.direction_to(target+Vector2(0,33))*preferred_travel
	var best:=INF
	for i in 180:
		p.pivot.rotation.y=TAU*float(i)/180.0
		var offset:Vector2=spear_point(actor)-p.position
		var peak:Vector2=target-offset
		var error:float=peak.distance_squared_to(ideal)
		if error<best:best=error;thrust_yaw=p.pivot.rotation.y;thrust_peak=peak-origin
	p.pivot.rotation.y=thrust_yaw
	actor.sample(0,false)

func cache_spear(actor)->void:
	var p=actor.preview
	if spear_skeleton!=p.skeleton:
		spear_skeleton=p.skeleton;hand=spear_skeleton.find_bone("hand.R")
		var mesh:=p.pivot.find_child("*chipped*",true,false) as MeshInstance3D
		var rest:=spear_skeleton.get_bone_global_rest(hand)
		var longest:=-1.0
		for vertex:Vector3 in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var local:=spear_skeleton.to_local(mesh.to_global(vertex))
			var distance:=local.distance_squared_to(rest.origin)
			if distance>longest:longest=distance;tip_in_hand=rest.affine_inverse()*local

func prepare_ready(actor,origin:Vector2,enemy:Vector2)->void:
	if not grounded_spear:return
	actor.sample(0,false);anchor_spear_root(actor)
	var target:=enemy+enemy.direction_to(origin)*28.0-Vector2(0,33)
	var best:=INF
	for i in 180:
		actor.preview.pivot.rotation.y=TAU*float(i)/180.0
		var distance:=spear_point(actor).distance_squared_to(target)
		if distance<best:best=distance;ready_yaw=actor.preview.pivot.rotation.y
	actor.preview.pivot.rotation.y=ready_yaw

func spear_point(actor)->Vector2:
	if actor.preview.has_meta("duel_world"):
		var world=actor.preview.get_meta("duel_world")
		return world.project(world.weapon_point(0))
	var p=actor.preview
	var world:=spear_skeleton.global_transform*spear_skeleton.get_bone_global_pose(hand)*tip_in_hand
	return p.position+(p.display.position+p.camera.unproject_position(world)*p.display.scale)*p.scale

func bone_point(actor,name:String)->Vector2:
	if actor.preview.has_meta("duel_world"):
		return actor.preview.get_meta("duel_world").bone_screen(int(actor.preview.get_meta("duel_side")),name)
	var p=actor.preview
	var sk:Skeleton3D=p.skeleton
	var world:=sk.global_transform*sk.get_bone_global_pose(sk.find_bone(name)).origin
	return p.position+(p.display.position+p.camera.unproject_position(world)*p.display.scale)*p.scale
