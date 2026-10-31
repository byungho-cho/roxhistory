extends SceneTree
func _initialize():call_deferred("run")
func run():
	var document:=GLTFDocument.new();var state:=GLTFState.new()
	var result:=document.append_from_file("res://c001-rigged.glb",state)
	if result!=OK:push_error("Cannot import GLB");quit(1);return
	var scene:=document.generate_scene(state);root.add_child(scene)
	var players:=scene.find_children("*","AnimationPlayer",true,false)
	var rigs:=scene.find_children("*","Skeleton3D",true,false)
	assert(not players.is_empty() and not rigs.is_empty())
	var player:AnimationPlayer=players[0]
	for clip in ["idle","walk","gather","build"]:
		assert(player.has_animation(clip));player.play(clip);player.seek(.3,true)
		await process_frame
	print(JSON.stringify({"import_result":result,"animations":Array(player.get_animation_list()),"skeletons":rigs.size(),"bones":rigs[0].get_bone_count(),"utc":Time.get_datetime_string_from_system(true)}))
	quit()
