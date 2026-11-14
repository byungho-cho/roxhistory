extends HybridCharacter

const MODEL := "res://assets/characters/residents/roxhistory-hunter-male-combat-v2-preview.glb"
var animation_player: AnimationPlayer
var model: Node3D
var spear: MeshInstance3D
var active_clip := ""

func build_villager() -> void:
	model = load(MODEL).instantiate()
	model.scale = Vector3.ONE * 1.24
	model.position.y = -.12
	pivot.add_child(model)
	animation_player = model.find_children("*","AnimationPlayer",true,false)[0]
	spear = model.find_child("Hunter_Spear",true,false)
	show_combat_pose(Vector2.RIGHT,"Combat_Idle",0.0)

func show_combat_pose(direction: Vector2, clip: String, progress: float) -> void:
	pivot.rotation.y = atan2(direction.x,direction.y)
	if clip != active_clip:
		active_clip = clip
		animation_player.play(clip)
	animation_player.speed_scale = 0.0
	var duration := animation_player.get_animation(clip).length
	animation_player.seek(clampf(progress,0,1)*duration,true)

func contact_point() -> Vector2:
	var skeleton := model.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	var bone := skeleton.find_bone("spear")
	if bone < 0: return position+Vector2(24,-38)
	var tip := skeleton.get_bone_global_pose(bone) * (skeleton.get_bone_global_rest(bone).affine_inverse() * Vector3(-.765,2.53,.14))
	var pixel := camera.unproject_position(skeleton.to_global(tip))
	return position+(display.position+pixel*display.scale)*scale
