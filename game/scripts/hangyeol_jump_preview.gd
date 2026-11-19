extends HybridCharacter

const R03 := preload("res://scripts/res011_lab_preview.gd")
var jump_model: Node3D
var jump_animation: AnimationPlayer
var jump_skeleton: Skeleton3D
var legacy_visuals: Array[Node3D] = []
var legacy_visibility: Array[bool] = []
var original_view_size := Vector2i.ZERO
var original_camera_size := 3.5
var hand_index := -1
var tip_in_hand := Vector3.ZERO

func prepare_jump() -> void:
	if jump_model: return
	for child in pivot.get_children():
		if child is Node3D: legacy_visuals.append(child)
	jump_model = (load(R03.JUMP_MODEL) as PackedScene).instantiate()
	jump_model.scale = Vector3.ONE*1.24
	jump_model.position.y = -.12
	pivot.add_child(jump_model)
	jump_animation = jump_model.find_children("*","AnimationPlayer",true,false)[0]
	jump_animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	jump_animation.play(R03.JUMP_CLIP)
	jump_animation.advance(0)
	jump_skeleton = jump_model.find_children("*","Skeleton3D",true,false)[0]
	hand_index = jump_skeleton.find_bone("hand.R")
	var point := jump_model.find_child("*chipped*",true,false) as MeshInstance3D
	var hand_rest := jump_skeleton.get_bone_global_rest(hand_index)
	var longest := -1.0
	for vertex: Vector3 in point.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var local := jump_skeleton.to_local(point.to_global(vertex))
		var distance := local.distance_squared_to(hand_rest.origin)
		if distance>longest:
			longest = distance
			tip_in_hand = hand_rest.affine_inverse()*local
	jump_model.hide()

func show_jump(direction: Vector2, seconds: float) -> void:
	prepare_jump()
	if not jump_model.visible:
		original_view_size = viewport.size
		original_camera_size = camera.size
		viewport.size = Vector2i(original_view_size.x*3,original_view_size.y*2)
		camera.size = original_camera_size*2
		legacy_visibility.clear()
		for child in legacy_visuals: legacy_visibility.append(child.visible)
	for child in legacy_visuals: child.hide()
	jump_model.show()
	pivot.rotation.y = atan2(direction.x,direction.y)
	jump_animation.seek(R03.Timing.event_sample("hangyeol",R03.JUMP_CLIP,seconds,R03.JUMP_CONTACT_SECONDS,R03.JUMP_SECONDS),true)
	jump_skeleton.force_update_all_bone_transforms()
	display.position = -camera.unproject_position(Vector3.ZERO)*display.scale
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func stop_jump() -> void:
	if not jump_model or not jump_model.visible: return
	jump_model.hide()
	for index in legacy_visuals.size():
		legacy_visuals[index].visible = legacy_visibility[index]
	viewport.size = original_view_size
	camera.size = original_camera_size
	display.position = -camera.unproject_position(Vector3.ZERO)*display.scale

func contact_point() -> Vector2:
	if not jump_model or not jump_model.visible:
		return position+(tool_contact_world()-global_position)*scale
	var world_tip := jump_skeleton.global_transform*jump_skeleton.get_bone_global_pose(hand_index)*tip_in_hand
	var pixel := camera.unproject_position(world_tip)
	return position+(display.position+pixel*display.scale)*scale
