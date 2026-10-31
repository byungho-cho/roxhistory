extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var hero:=HybridCharacter.new();root.add_child(hero)
	await process_frame
	hero.tool_3d.visible=false
	var player:=AnimationPlayer.new();player.name="C001Animations";hero.pivot.add_child(player)
	var library:=AnimationLibrary.new();player.add_animation_library("",library)
	for clip in ["idle","walk","gather","build"]:
		var animation:=Animation.new();animation.length=2.0 if clip=="idle" else 1.0
		animation.loop_mode=Animation.LOOP_LINEAR if clip in ["idle","walk"] else Animation.LOOP_NONE
		for bone in hero.rig.get_bone_count():
			var path:=NodePath("VillagerSkeleton:"+hero.rig.get_bone_name(bone))
			var rot:=animation.add_track(Animation.TYPE_ROTATION_3D);animation.track_set_path(rot,path)
			var pos:=animation.add_track(Animation.TYPE_POSITION_3D);animation.track_set_path(pos,path)
			for frame in int(animation.length*30)+1:
				var t:=float(frame)/30
				hero.clock=t;hero.walk_blend=1.0 if clip=="walk" else 0.0
				hero.action_blend=1.0 if clip in ["gather","build"] else 0.0
				hero.work_kind="build" if clip=="build" else "wood"
				hero.apply_pose(t*TAU,HeroMotion.stroke(t) if clip in ["gather","build"] else 0.0)
				animation.rotation_track_insert_key(rot,t,hero.rig.get_bone_pose_rotation(bone))
				animation.position_track_insert_key(pos,t,hero.rig.get_bone_pose_position(bone))
		var tool_path:=hero.pivot.get_path_to(hero.tool_3d)
		var tool_rot:=animation.add_track(Animation.TYPE_ROTATION_3D);animation.track_set_path(tool_rot,tool_path)
		var tool_scale:=animation.add_track(Animation.TYPE_SCALE_3D);animation.track_set_path(tool_scale,tool_path)
		for frame in int(animation.length*30)+1:
			var t:=float(frame)/30
			var working:bool=clip in ["gather","build"]
			animation.rotation_track_insert_key(tool_rot,t,Quaternion.from_euler(Vector3(1.15*HeroMotion.stroke(t) if clip=="gather" else 0,0,0)))
			animation.scale_track_insert_key(tool_scale,t,Vector3.ONE if working else Vector3.ONE*.0001)
		library.add_animation(clip,animation)
	hero.rig.reset_bone_poses()
	var document:=GLTFDocument.new()
	var state:=GLTFState.new()
	var result:=document.append_from_scene(hero.pivot,state)
	if result!=OK:
		push_error("GLB scene export failed: %s"%result);quit(1);return
	result=document.write_to_filesystem(state,"res://c001-rigged.glb")
	print("STUDY_GLB_EXPORT_RESULT=",result)
	quit(0 if result==OK else 1)
