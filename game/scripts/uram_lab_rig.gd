extends HybridCharacter

const MODEL := preload("res://assets/characters/d0047/uram-B-rigged.glb")
var animator: AnimationPlayer
var skeleton: Skeleton3D
var root_bone: int
var shield_hand: int
var current_clip := ""

func build_villager() -> void:
	var rig := MODEL.instantiate() as Node3D
	pivot.add_child(rig)
	animator = rig.find_children("*","AnimationPlayer",true,false)[0]
	skeleton = rig.find_children("*","Skeleton3D",true,false)[0]
	root_bone = skeleton.find_bone("root")
	shield_hand = skeleton.find_bone("hand.L")
	show_pose("idle",0.0)

func clip_length(clip: String) -> float:
	return animator.get_animation(clip).length

func show_pose(clip: String, seconds: float) -> void:
	if clip != current_clip:
		current_clip = clip
		skeleton.reset_bone_poses()
		animator.play(clip,0.0)
		animator.speed_scale = 0.0
	animator.seek(clampf(seconds,0.0,clip_length(clip)),true)
	var anchor := skeleton.get_bone_pose_position(root_bone)
	var rest := skeleton.get_bone_rest(root_bone).origin
	skeleton.set_bone_pose_position(root_bone,Vector3(rest.x,anchor.y,rest.z))

func projected_shield_hand() -> Vector2:
	var hand := skeleton.to_global(skeleton.get_bone_global_pose(shield_hand).origin)
	return display.position+camera.unproject_position(hand)*display.scale
