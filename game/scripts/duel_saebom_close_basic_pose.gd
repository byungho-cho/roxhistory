extends RefCounted
## Lab near basic presentation: original skeleton, sling meshes and rope skin.
## The attack clock and damage remain on the real squad gameplay resolution.
static func project(v:HybridCharacter,pos:Vector3)->Vector2:
	return v.position+(v.display.position+v.camera.unproject_position(pos)*v.display.scale)*v.scale

static func unproject(v:HybridCharacter,mark:Vector2,depth:float)->Vector3:
	var pixel:=((mark-v.position)/v.scale-v.display.position)/v.display.scale
	return v.camera.project_position(pixel,depth)

static func bone_pos(sk:Skeleton3D,b:int)->Vector3:
	return sk.to_global(sk.get_bone_global_pose(b).origin)

static func bone_named(v:HybridCharacter,n:String)->Vector3:
	return bone_pos(v.skeleton,v.skeleton.find_bone(n))

static func shoulder(unit:Dictionary,_attacker:Vector2)->Vector2:
	var v:HybridCharacter=unit.actor.preview
	var front:=project(v,bone_named(v,"front_upper.R"))
	var ribs:=project(v,bone_named(v,"trunk"))
	var head:=project(v,bone_named(v,"head"))
	# The near-body ribs sit behind the front shoulder and clear the visible
	# lower jaw even at the actual phone camera. Do not aim at head or muzzle.
	var side_skin:=front.lerp(ribs,.30)
	side_skin.y=maxf(side_skin.y+6.4,head.y+18.2)
	return side_skin

static func _curve(t:float,times:Array,poses:Array[Vector2])->Vector2:
	# C1 Hermite join: body leads a single strike and the weight follows through.
	for j in range(1,times.size()):
		if t<=float(times[j]):
			var k:=j-1
			var a:=float(times[k]); var b:=float(times[j])
			var v0:=Vector2.ZERO if k==0 else (poses[j]-poses[k-1])/float(times[j]-times[k-1])
			var v1:=Vector2.ZERO if j==poses.size()-1 else (poses[j+1]-poses[k])/float(times[j+1]-times[k])
			var x:=clampf((t-a)/(b-a),0.,1.)
			return (2.*x*x*x-3.*x*x+1.)*poses[k]+(x*x*x-2.*x*x+x)*(b-a)*v0+(-2.*x*x*x+3.*x*x)*poses[j]+(x*x*x-x*x)*(b-a)*v1
	return poses[-1]

static func _rotate(sk:Skeleton3D,n:String,axis:Vector3,amount:float)->void:
	var i:=sk.find_bone(n)
	if i>=0 and absf(amount)>.0001:sk.set_bone_pose_rotation(i,sk.get_bone_pose_rotation(i)*Quaternion(axis,amount))

static func _from_to(sk:Skeleton3D,i:int,old:Vector3,want:Vector3,weight:=1.0)->void:
	var p:=sk.get_bone_global_pose(i)
	var a:=sk.to_local(old)-p.origin
	var b:=sk.to_local(want)-p.origin
	if a.length_squared()<.00001 or b.length_squared()<.00001:return
	var rotate:=Quaternion.IDENTITY.slerp(Quaternion(a.normalized(),b.normalized()),weight)
	p.basis=Basis(rotate)*p.basis
	sk.set_bone_global_pose(i,p)
	sk.force_update_all_bone_transforms()

static func _arm(sk:Skeleton3D,want:Vector3,pole_hint:Vector3,weight:float,suffix:String="R")->void:
	var upper:=sk.find_bone("upper."+suffix);var fore:=sk.find_bone("lower."+suffix);var hand:=sk.find_bone("hand."+suffix)
	var s:=bone_pos(sk,upper);var e:=bone_pos(sk,fore);var w:=bone_pos(sk,hand)
	var ab:=s.distance_to(e);var bc:=e.distance_to(w)
	var delta:=want-s
	var direction:=delta.normalized()
	var span:=clampf(delta.length(),absf(ab-bc)+.09,ab+bc-.027)
	var along:=(ab*ab-bc*bc+span*span)/(2.*span)
	var side:=sqrt(maxf(0.,ab*ab-along*along))
	var pole:=pole_hint
	pole=(pole-direction*pole.dot(direction)).normalized()
	if pole.length_squared()<.5:pole=(e-s-direction*(e-s).dot(direction)).normalized()
	var elbow:=s+direction*along+pole*side
	_from_to(sk,upper,e,elbow,weight)
	_from_to(sk,fore,bone_pos(sk,hand),s+direction*span,weight)

static func _gear(v:HybridCharacter)->Array:
	if v.has_meta("close_basic_cords"):return v.get_meta("close_basic_cords")
	var sk:Skeleton3D=v.skeleton
	var result:Array=[]
	for model in v.pivot.find_children("*","MeshInstance3D",true,false):
		var n:=String(model.name)
		if not n.begins_with("Sling - cord_"):continue
		var name:=n.trim_prefix("Sling - ")
		var id:=sk.find_bone(name)
		var bind_pose:Transform3D=model.skin.get_bind_pose(id)
		var box:AABB=model.get_aabb()
		var center:=box.get_center()
		var start:=bind_pose*Vector3(center.x,box.position.y,center.z)
		var end:=bind_pose*Vector3(center.x,box.end.y,center.z)
		var grip:=bone_pos(sk,sk.find_bone("hand.R"))
		var bone_matrix:Transform3D=sk.global_transform*sk.get_bone_global_pose(id)
		if grip.distance_to(bone_matrix*start)>grip.distance_to(bone_matrix*end):
			var tmp:=start;start=end;end=tmp
		result.append({"id":id,"a":start,"b":end})
	v.set_meta("close_basic_cords",result)
	return result

static func _cord(sk:Skeleton3D,data:Dictionary,grip:Vector3,pouch:Vector3,weight:float)->void:
	var bone:int=data.id
	var a:Vector3=data.a
	var direction:Vector3=data.b-a
	var axis:=direction.normalized()
	var tail:=pouch-grip
	if tail.length()<.03:return
	var width:=sk.global_basis.x.length()
	var stretch:=tail.length()/maxf(.01,direction.length())
	var basis:=Basis(Quaternion(axis,tail.normalized()))*Basis(
		Vector3.RIGHT*width+axis*axis.x*(stretch-width),
		Vector3.UP*width+axis*axis.y*(stretch-width),
		Vector3.BACK*width+axis*axis.z*(stretch-width))
	var pose:=sk.global_transform.affine_inverse()*Transform3D(basis,grip-basis*a)
	var saved:=sk.get_bone_global_pose(bone)
	sk.set_bone_global_pose(bone,saved.interpolate_with(pose,weight))

const PALM_LOCAL:=Vector3(-.004,.132,-.046)

static func _palm(sk:Skeleton3D,hand:int,local:Vector3=PALM_LOCAL)->Vector3:
	return sk.global_transform*sk.get_bone_global_pose(hand)*local

static func _rope_error(sk:Skeleton3D,item:Dictionary,start_world:Vector3,end_world:Vector3)->float:
	var bone:int=item.id
	var matrix:Transform3D=sk.global_transform*sk.get_bone_global_pose(bone)
	var a:Vector3=item.a
	var b:Vector3=item.b
	return maxf((matrix*a).distance_to(start_world),(matrix*b).distance_to(end_world))

static func _rig_attached(v:HybridCharacter,requested:Vector3,stone_offset:Vector3)->float:
	var sk:Skeleton3D=v.skeleton
	var palm:=sk.find_bone("hand.R")
	var rock:=sk.find_bone("sling_stone")
	var pouch:=sk.find_bone("sling_pouch")
	var cable:=_gear(v)
	var leather:=_palm(sk,palm)+requested
	var rock_pose:=sk.get_bone_global_pose(rock)
	var leather_pose:=sk.get_bone_global_pose(pouch)
	rock_pose.origin=sk.to_local(leather+stone_offset)
	leather_pose.origin=sk.to_local(leather)
	sk.set_bone_global_pose(rock,rock_pose)
	sk.set_bone_global_pose(pouch,leather_pose)
	var error:=0.
	for i in cable.size():
		var split:=1. if i==0 else -1.
		var a:=_palm(sk,palm,PALM_LOCAL+Vector3(.009*split,.001,0.))
		var b:=leather+v.camera.global_basis.x*.028*split
		_cord(sk,cable[i],a,b,1.)
		sk.force_update_all_bone_transforms()
		error=maxf(error,_rope_error(sk,cable[i],a,b))
	sk.force_update_all_bone_transforms()
	return error


static func _stable_arc(a:Vector3,b:Vector3,t:float,around:Vector3)->Vector3:
	var ua:=a.normalized()
	var ub:=b.normalized()
	if ua.dot(ub)<-.92:
		var mid:=around.normalized()
		var v:=ua.slerp(mid,t*2.) if t<.5 else mid.slerp(ub,(t-.5)*2.)
		return v.normalized()*lerpf(a.length(),b.length(),t)
	return ua.slerp(ub,t).normalized()*lerpf(a.length(),b.length(),t)


static func _plant_leg(sk:Skeleton3D,suffix:String,plant:Transform3D,pole:Vector3)->void:
	var up:=sk.find_bone("thigh."+suffix)
	var low:=sk.find_bone("shin."+suffix)
	var foot:=sk.find_bone("foot."+suffix)
	var hip:=bone_pos(sk,up)
	var knee:=bone_pos(sk,low)
	var ankle:=bone_pos(sk,foot)
	var wanted:=sk.global_transform*plant.origin
	var len1:=hip.distance_to(knee)
	var len2:=knee.distance_to(ankle)
	var d:=(wanted-hip).normalized()
	var reach:=clampf(hip.distance_to(wanted),absf(len1-len2)+.01,len1+len2-.004)
	var mid:=(len1*len1-len2*len2+reach*reach)/(2.*reach)
	var bend:=(pole-d*pole.dot(d)).normalized()
	var side:=sqrt(maxf(0.,len1*len1-mid*mid))
	_from_to(sk,up,knee,hip+d*mid+bend*side)
	_from_to(sk,low,bone_pos(sk,foot),hip+d*reach)
	sk.set_bone_global_pose(foot,plant)
	sk.force_update_all_bone_transforms()

static func sample(unit:Dictionary,target:Dictionary,p:float)->Dictionary:
	var actor=unit.actor
	var v:HybridCharacter=actor.preview
	var sk:Skeleton3D=v.skeleton
	var cam:=v.camera
	v.animation.play(actor.clip_for("idle"),0.0)
	sk.reset_bone_poses()
	actor.resident_sample("idle",0.)
	sk.force_update_all_bone_transforms()
	_gear(v)
	var right:=sk.find_bone("hand.R")
	var left:=sk.find_bone("hand.L")
	var hip:=sk.find_bone("hips")
	var rf:=sk.find_bone("foot.R")
	var lf:=sk.find_bone("foot.L")
	var rock:=sk.find_bone("sling_stone")
	var pouch:=sk.find_bone("sling_pouch")
	var r0:=_palm(sk,right)
	var l0:=_palm(sk,left,Vector3(.004,.132,-.046))
	var hp0:=bone_pos(sk,hip)
	var rf0:=sk.get_bone_global_pose(rf)
	var lf0:=sk.get_bone_global_pose(lf)
	var slack:=bone_pos(sk,pouch)-r0
	var stone_offset:=bone_pos(sk,rock)-bone_pos(sk,pouch)
	var home:=project(v,r0)
	var edge:Vector2=unit.get("close_basic_edge",Vector2.INF)
	if not edge.is_finite():edge=shoulder(target,unit.feet)
	var side:=1. if edge.x>=unit.feet.x else -1.
	var screen_x:=cam.global_basis.x*side
	var cam_flat:=(cam.global_basis.z*Vector3(1,0,1)).normalized()
	var body_fwd:=(screen_x*.93-cam_flat*.37).normalized()
	var pitch_axis:=Vector3.UP.cross(body_fwd).normalized()
	var load:=smoothstep(.00,.205,p)*(1.-smoothstep(.245,.44,p))
	var drive:=smoothstep(.25,.48,p)*(1.-smoothstep(.58,.91,p))
	var work:=smoothstep(.015,.16,p)*(1.-smoothstep(.745,1.,p))
	var h:=sk.get_bone_global_pose(hip)
	# Actual center of gravity transfers over the lead leg; both soles lock.
	# This is one bent-knee shift and recovery, not a torso-twist cycle.
	h.origin+=sk.global_basis.inverse()*(body_fwd*(-.153*load+.143*drive)+Vector3.DOWN*(.092*load+.061*drive))
	sk.set_bone_global_pose(hip,h)
	sk.force_update_all_bone_transforms()
	var planted_strength:=smoothstep(0.005,.105,p)*(1.-smoothstep(.84,.999,p))
	if planted_strength>.04:
		_plant_leg(sk,"R",sk.get_bone_global_pose(rf).interpolate_with(rf0,planted_strength),body_fwd+cam_flat*.18)
		_plant_leg(sk,"L",sk.get_bone_global_pose(lf).interpolate_with(lf0,planted_strength),body_fwd-cam_flat*.29)
	var si:=sk.find_bone("spine")
	var pose:=sk.get_bone_global_pose(si)
	pose.basis=Basis(Quaternion((sk.global_basis.inverse()*pitch_axis).normalized(),-.113*load+.165*drive))*pose.basis
	sk.set_bone_global_pose(si,pose)
	_rotate(sk,"chest",Vector3.UP,-.041*load+.051*drive)
	_rotate(sk,"head",Vector3.UP,.034*load-.029*drive)
	sk.force_update_all_bone_transforms()
	# The stone has limited travel from the closed hand and follows the
	# proximal shoulder/elbow burst, so it never looks like a fired stone.
	var aim_vec:Vector3=(screen_x*.92+Vector3.DOWN*.18-cam_flat*.12).normalized()*.318
	var at_hit:=edge-Vector2(side*3.1,0.)-(project(v,r0+aim_vec+stone_offset)-home)
	var marks:Array=[0.,.12,.22,.31,.385,.48,.57,.72,.9,1.]
	var pts:Array[Vector2]=[home,home+Vector2(-9.*side,-5.),home+Vector2(-14.*side,-7.5),
		home+Vector2(-11.*side,-5.),at_hit+Vector2(-10.*side,-2.3),
		at_hit,at_hit+Vector2(.65*side,2.8),home+Vector2(5.*side,2.1),home,home]
	var visit:=_curve(p,marks,pts)
	var rdepth:float=-cam.to_local(r0).z
	var r_goal:=unproject(v,visit,rdepth-.07*load+.04*drive)
	var r_rot:=sk.get_bone_pose_rotation(right)
	sk.set_bone_pose_rotation(right,r_rot*Quaternion(Vector3.UP,side*(-.16*load+.11*drive)))
	sk.force_update_all_bone_transforms()
	var elbow_plane:Vector3=(Vector3.DOWN*.79+cam_flat*(.56+.23*load)-body_fwd*.16).normalized()
	for i in 4:
		_arm(sk,r_goal-(_palm(sk,right)-bone_pos(sk,right)),elbow_plane,work if i==0 else minf(1.,work*1.18))
	var handle:=_palm(sk,right)
	var spare:=l0-body_fwd*.09*drive+Vector3.UP*.04*load+cam_flat*.067*drive
	var la:=Vector3(.004,.132,-.046)
	for i in 3:
		_arm(sk,spare-(_palm(sk,left,la)-bone_pos(sk,left)),Vector3.DOWN,work*.67,"L")
	var delayed:=maxf(0.,p-.041)
	var layback:Vector3=(-screen_x*.59+Vector3.DOWN*.67+cam_flat*.32).normalized()*.29
	var low_follow:Vector3=(screen_x*.58+Vector3.DOWN*.77).normalized()*.331
	var cords:Vector3
	if delayed<.295:
		cords=_stable_arc(slack,layback,smoothstep(.005,.214,delayed),Vector3.DOWN)
	elif delayed<.439:
		cords=_stable_arc(layback,aim_vec,smoothstep(.295,.439,delayed),Vector3.DOWN)
	elif delayed<.58:
		cords=_stable_arc(aim_vec,low_follow,smoothstep(.439,.58,delayed),Vector3.DOWN)
	else:
		cords=_stable_arc(low_follow,slack,smoothstep(.58,.959,delayed),Vector3.DOWN)
	# Keep the leather body and stone turning as a single loaded pouch.
	var pouch_turn:=Quaternion.IDENTITY.slerp(Quaternion(slack.normalized(),cords.normalized()),work*.69)
	var rpose:=sk.get_bone_global_pose(rock)
	var ppose:=sk.get_bone_global_pose(pouch)
	var local_turn:=Basis(sk.global_basis.get_rotation_quaternion().inverse()*pouch_turn*sk.global_basis.get_rotation_quaternion())
	rpose.basis=local_turn*rpose.basis
	ppose.basis=local_turn*ppose.basis
	sk.set_bone_global_pose(rock,rpose)
	sk.set_bone_global_pose(pouch,ppose)
	var err:=_rig_attached(v,cords,stone_offset)
	var mark:=project(v,bone_pos(sk,rock))
	return {"edge":edge,"tip":mark+Vector2(side*3.1,0.),"stone":mark,"hand":project(v,handle),
		"left":project(v,_palm(sk,left,la)),"cord":cords.length(),"pinned_error":err,
		"foot_r":bone_pos(sk,rf).distance_to(sk.global_transform*rf0.origin),
		"foot_l":bone_pos(sk,lf).distance_to(sk.global_transform*lf0.origin),
		"center":project(v,bone_pos(sk,hip))-project(v,hp0),
		"jaw":project(target.actor.preview,bone_named(target.actor.preview,"head")),"strike_axis":Vector2(side,0.)}
