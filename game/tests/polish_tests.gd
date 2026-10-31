extends SceneTree
var checks := 0
var failed: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failed.append(message); push_error(message)
func run() -> void:
	var character := HybridCharacter.new()
	root.add_child(character)
	await process_frame
	character.set_enabled(true)
	check(character.skinned_limbs.size() == 1,"Continuous imported body binds all four limbs")
	for limb in character.skinned_limbs:
		var arrays: Array = limb.mesh.surface_get_arrays(0)
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var valid := weights.size() > 0
		var blended := false
		for i in range(0,weights.size(),4):
			valid = valid and absf(weights[i]+weights[i+1]+weights[i+2]+weights[i+3]-1.0) < 0.001
			blended = blended or (weights[i] > 0.05 and weights[i+1] > 0.05)
		check(valid and blended,"Joint weights normalized and smoothly blended")
		check(limb.skin.get_bind_count() == 15 and limb.get_node(limb.skeleton) == character.rig,"Skin binds target the real skeleton")
		var joints:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
		var influenced:Dictionary={}
		for i in joints.size():
			if weights[i]>.1:
				var index=limb.skin.get_bind_bone(joints[i])
				var bone_name=character.rig.get_bone_name(index) if index>=0 else String(limb.skin.get_bind_name(joints[i]))
				influenced[bone_name]=true
		for side in ["L","R"]:
			for joint in ["arm","forearm","thigh","shin"]:check(influenced.has(joint+side),"Imported body has real deformation weights for "+joint+side)
		for sample in [[0,0,1,-.35],[0,0,1,1],[PI/2,1,0,0],[-PI/2,1,0,0]]:
			character.walk_blend=sample[1];character.action_blend=sample[2];character.apply_pose(sample[0],sample[3])
			var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			var transforms:Array[Transform3D]=[]
			for bind in limb.skin.get_bind_count():
				var index=limb.skin.get_bind_bone(bind)
				if index<0:index=character.rig.find_bone(limb.skin.get_bind_name(bind))
				transforms.append(character.rig.get_bone_global_pose(index)*limb.skin.get_bind_pose(bind))
			var posed:=PackedVector3Array();posed.resize(vertices.size())
			for i in vertices.size():
				for influence in 4:posed[i]+=(transforms[joints[i*4+influence]]*vertices[i])*weights[i*4+influence]
			var spikes:=0
			for triangle in range(0,indices.size(),3):
				for edge in 3:
					var a=indices[triangle+edge];var b=indices[triangle+(edge+1)%3]
					var rest_length=vertices[a].distance_to(vertices[b]);var posed_length=posed[a].distance_to(posed[b])
					if posed_length-rest_length>.12 and posed_length>maxf(.02,rest_length)*4:
						if spikes<4:print("SPIKE ",vertices[a]," -> ",vertices[b]," weights ",joints.slice(a*4,a*4+4),weights.slice(a*4,a*4+4)," / ",joints.slice(b*4,b*4+4),weights.slice(b*4,b*4+4)," posed ",posed[a]," -> ",posed[b])
						spikes+=1
			check(spikes==0,"Animation pose has no long skinning spikes: "+str(spikes))
	character.action_blend=0;character.walk_blend=0
	for i in 24:
		var phase := TAU*i/24.0
		character.animate(0.2,Vector2.DOWN,phase,true,"",0,false)
		await process_frame
		for side in ["L","R"]:
			var foot: Transform3D = character.rig.get_bone_global_pose(character.bones["foot"+side])
			var sole := foot.origin.y-character.rig.get_bone_global_rest(character.bones["foot"+side]).origin.y
			check(sole > -0.003 and sole < 0.105,"Sole stays at or above ground across gait")
	for i in 20: character.animate(1.0/60.0,Vector2.ZERO,0,false,"",0,false)
	await process_frame
	for side in ["L","R"]:
		check(absf(character.rig.get_bone_global_pose(character.bones["foot"+side]).origin.y-character.rig.get_bone_global_rest(character.bones["foot"+side]).origin.y) < 0.003,"Stopped foot is planted")
	character.animate(0.2,Vector2.ZERO,0,false,"gather",0.4,false)
	await process_frame
	check(character.tool_3d.get_parent() == character.attachments.handR,"Tool remains attached to hand bone")
	var pose: Quaternion = character.rig.get_bone_pose_rotation(character.bones.armR)
	character.animate(0.2,Vector2.RIGHT,0,false,"",0,true)
	check(not character.tool_3d.visible and character.rig.get_bone_pose_rotation(character.bones.armR) == pose,"Pause hides tool and freezes pose")
	for i in 20: character.animate(1.0/60.0,Vector2.ZERO,0,false,"",0,false)
	check(character.action_blend == 0.0,"Interrupted action settles after resume")
	var report := {"checks":checks,"failed":failed,"utc":Time.get_datetime_string_from_system(true)}
	FileAccess.open("res://reports/polish-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report)); quit(0 if failed.is_empty() else 1)
