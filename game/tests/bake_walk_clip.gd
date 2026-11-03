extends SceneTree
# Offline authored contact/down/passing/up poses, baked to editable bone tracks.
const FEET = [Vector2(.40,0),Vector2(.20,0),Vector2(0,0),Vector2(-.20,.005),Vector2(-.40,.02),Vector2(-.22,.12),Vector2(.06,.16),Vector2(.34,.08),Vector2(.40,0)]
func foot(t:float)->Vector2:
	var f:=fposmod(t,1.0)*8
	return FEET[int(f)].lerp(FEET[int(f)+1],f-int(f))
func _initialize()->void:call_deferred("run")
func run()->void:
	var c:=HybridCharacter.new();root.add_child(c);await process_frame
	var clip:=Animation.new();clip.resource_name="BriskWalk_v001";clip.length=1.0;clip.loop_mode=Animation.LOOP_LINEAR
	for i in c.rig.get_bone_count():
		for type in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D]:
			var track:=clip.add_track(type);clip.track_set_path(track,NodePath("Skeleton3D:"+c.rig.get_bone_name(i)))
	for frame in 65:
		var t:=frame/64.0
		for i in c.rig.get_bone_count():c.rig.set_bone_pose_rotation(i,Quaternion.IDENTITY);c.rig.set_bone_pose_position(i,c.rig.get_bone_rest(i).origin)
		c.rig.set_bone_pose_position(c.bones.hips,c.rests.hips+Vector3(0,-.12,0))
		c.rotate_bone("spine",Vector3(.025,.025*cos(TAU*t),0));c.rotate_bone("head",Vector3(-.025,-.018*cos(TAU*t),0))
		for side in [-1.0,1.0]:
			var suffix:="L" if side<0 else "R";var p:=foot(t+(.5 if side<0 else 0))
			var upper:float=c.rests["shin"+suffix].length();var lower:float=c.rests["foot"+suffix].length()
			var y:=-(upper+lower-.12)+p.y;var z:=p.x
			var d:=sqrt(y*y+z*z)
			assert(d<upper+lower,"Authored target must remain within the existing leg reach")
			var knee:=acos(clampf((d*d-upper*upper-lower*lower)/(2*upper*lower),-1,1))
			var thigh:=atan2(-z,-y)-atan2(lower*sin(knee),upper+lower*cos(knee))
			c.rotate_bone("thigh"+suffix,Vector3(thigh,0,0));c.rotate_bone("shin"+suffix,Vector3(knee,0,0));c.rotate_bone("foot"+suffix,Vector3(-thigh-knee,0,0))
			c.rotate_bone("arm"+suffix,Vector3(-p.x*.75,0,-side*.035));c.rotate_bone("forearm"+suffix,Vector3(-.18-.055*sin(TAU*t)*side,0,0))
		for i in c.rig.get_bone_count():
			clip.position_track_insert_key(i*2,t,c.rig.get_bone_pose_position(i))
			clip.rotation_track_insert_key(i*2+1,t,c.rig.get_bone_pose_rotation(i))
	DirAccess.make_dir_recursive_absolute("res://assets/characters/motion")
	assert(ResourceSaver.save(clip,"res://assets/characters/motion/brisk_walk_v001.tres")==OK)
	print("Saved 30 bone tracks, 65 keys per track, loop 1 second; explicit authored gait")
	quit()
