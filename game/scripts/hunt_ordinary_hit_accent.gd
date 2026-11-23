extends SkeletonModifier3D
## Display-only; never changes command, play clock, root motion or collision.
const END:=.205
var stamp:=-INF
var blend:=0.
var substitute:=false
var stance:Array=[]
var joints:PackedInt32Array
var shoulders:PackedInt32Array
var charge_flinch:=false

static func on_hit(rig:Skeleton3D,at:float,can_substitute:bool,with_shoulders:=false)->void:
	if not is_instance_valid(rig):return
	var accent=rig.get_node_or_null("OrdinaryHitAccent")
	if not is_instance_valid(accent):
		accent=load("res://scripts/hunt_ordinary_hit_accent.gd").new()
		accent.name="OrdinaryHitAccent"
		accent.active=false
		rig.add_child(accent)
	accent.stamp=at
	accent.charge_flinch=with_shoulders
	accent.substitute=false
	if can_substitute:
		accent.stance.clear()
		for joint in rig.get_bone_count():
			accent.stance.append([rig.get_bone_pose_position(joint),rig.get_bone_pose_rotation(joint)])
	elif accent.stance.is_empty():
		accent.substitute=false

static func clear(rig:Skeleton3D)->void:
	if not is_instance_valid(rig):return
	var accent=rig.get_node_or_null("OrdinaryHitAccent")
	if is_instance_valid(accent):
		accent.stamp=-INF
		accent.stance.clear()
		accent.active=false

static func display(rig:Skeleton3D,now:float,alive:bool,resting_hit:bool,hit_started:=INF)->void:
	if not is_instance_valid(rig):return
	var accent=rig.get_node_or_null("OrdinaryHitAccent")
	if not is_instance_valid(accent):return
	var age:float=now-accent.stamp
	if not alive or age<0.:
		accent.stance.clear()
		accent.active=false
		return
	# Freeze only the neutral pose of a resting receiver, not an attack.
	# Keep it while the original solver's recovery state remains live.
	accent.substitute=resting_hit and absf(hit_started-accent.stamp)<.017 and not accent.stance.is_empty()
	if not resting_hit and age>=END:accent.stance.clear()
	accent.blend=smoothstep(0.,.038,age)*(1.-smoothstep(.080,END,age)) if age<END else 0.
	accent.active=accent.substitute or accent.blend>.0001

func _skeleton_changed(_old:Skeleton3D,new:Skeleton3D)->void:
	joints.clear()
	shoulders.clear()
	if not is_instance_valid(new):return
	for label in ["head","neck"]:
		var joint:=new.find_bone(label)
		if joint>=0:joints.append(joint)
	for label in ["upper.L","upper.R"]:
		var joint:=new.find_bone(label)
		if joint>=0:shoulders.append(joint)

func _process_modification_with_delta(_delta:float)->void:
	var rig:=get_skeleton()
	if not is_instance_valid(rig):return
	if substitute:
		for joint in mini(rig.get_bone_count(),stance.size()):
			rig.set_bone_pose_position(joint,stance[joint][0])
			rig.set_bone_pose_rotation(joint,stance[joint][1])
	if blend<=.0001:return
	for i in joints.size():
		var joint:=joints[i]
		var tilt:=Vector3(-.065,.009,.039) if i==0 else Vector3(-.025,0.,.014)
		rig.set_bone_pose_rotation(joint,rig.get_bone_pose_rotation(joint)*Quaternion.from_euler(tilt*blend*(1.55 if charge_flinch else 1.)))
	if charge_flinch:
		for i in shoulders.size():
			var joint:=shoulders[i]
			var shoulder:=Vector3(-.105,0.,.065 if i==0 else -.065)
			rig.set_bone_pose_rotation(joint,rig.get_bone_pose_rotation(joint)*Quaternion.from_euler(shoulder*blend))
