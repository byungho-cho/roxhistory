extends HybridCharacter

const ASSETS := "res://assets/characters/d0048/"
const CLUB_SIZE := Vector2(1.43,.53)
var variant := 0
var animator: AnimationPlayer
var skeleton: Skeleton3D
var root_bone: int
var current_clip := ""
var hand_bone: int
var shield_bone: int
var left_hand_bone: int
var grip_in_hand: Vector3
var tip_in_hand: Vector3
var shield_anchor: Vector3
var club: MeshInstance3D
var shield: MeshInstance3D

func build_villager() -> void:
	var packed := load(ASSETS+"uram-warm.glb") as PackedScene
	var rig := packed.instantiate() as Node3D
	pivot.add_child(rig)
	animator = rig.find_children("*","AnimationPlayer",true,false)[0]
	skeleton = rig.find_children("*","Skeleton3D",true,false)[0]
	root_bone = skeleton.find_bone("root")
	for item in rig.find_children("*","MeshInstance3D",true,false):
		var mesh := item as MeshInstance3D
		if "club" in String(mesh.name).to_lower():
			mesh.hide()
		elif variant > 0:
			var material := mesh.get_active_material(0).duplicate() as StandardMaterial3D
			material.albedo_texture = load(ASSETS+("brown.png" if variant == 1 else "red.png"))
			mesh.set_surface_override_material(0,material)
	hand_bone = skeleton.find_bone("hand.R")
	left_hand_bone = skeleton.find_bone("hand.L")
	shield_bone = skeleton.find_bone("forearm.L")
	var inverse_hand := skeleton.get_bone_global_rest(hand_bone).affine_inverse()
	var grip := Vector3(-.423,.763,.075)
	grip_in_hand = inverse_hand * grip
	tip_in_hand = inverse_hand * (grip + Vector3(-.025,.51,1.0).normalized())
	shield_anchor = skeleton.get_bone_global_rest(shield_bone).affine_inverse() * Vector3(.47,.99,.085)
	club = make_equipment("stone-club.png",CLUB_SIZE,.35)
	shield = make_equipment("hide-shield.png",Vector2(.61,.76),.36)
	show_pose("idle",0.0)

func make_equipment(file: String, dimensions: Vector2, threshold: float) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(ASSETS+file)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = threshold
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var quad := QuadMesh.new()
	quad.size = dimensions
	quad.material = material
	var equipment := MeshInstance3D.new()
	equipment.mesh = quad
	pivot.add_child(equipment)
	return equipment

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
	# Offset the entire preview so skin and equipment share the same root motion
	# compensation without changing the clip's bone transforms.
	pivot.position = -(skeleton.global_basis * Vector3(anchor.x-rest.x,0.0,anchor.z-rest.z))
	skeleton.force_update_all_bone_transforms()
	update_equipment()

func update_equipment() -> void:
	var hand := skeleton.global_transform * skeleton.get_bone_global_pose(hand_bone)
	var grip := hand * grip_in_hand
	var axis := (hand * tip_in_hand - grip).normalized()
	var up := camera.global_basis.z.cross(axis)
	if up.length_squared() < .001:
		up = camera.global_basis.y.cross(axis)
	up = up.normalized()
	club.global_transform = Transform3D(Basis(axis,up,axis.cross(up)),
		grip + axis * (CLUB_SIZE.x * .36) + up * (CLUB_SIZE.y * .19))
	var forearm := skeleton.global_transform * skeleton.get_bone_global_pose(shield_bone)
	var wrist := skeleton.to_global(skeleton.get_bone_global_pose(left_hand_bone).origin)
	var forward := pivot.global_basis.z.normalized()
	var toward_camera := camera.global_basis.z.normalized()
	var normal := (toward_camera * .47 + forward * .53).normalized()
	var arm := (forearm.origin - wrist).normalized()
	var right := (Vector3.UP * .72 + arm * .28).cross(normal).normalized()
	var rise := clampf((wrist.y - forearm.origin.y + .10) / .26,0.0,1.0)
	var center := forearm * shield_anchor + normal * .14 + forward * .05 + toward_camera * .075
	center.y -= lerpf(.19,.04,rise)
	shield.global_transform = Transform3D(Basis(right,normal.cross(right),normal),center)
