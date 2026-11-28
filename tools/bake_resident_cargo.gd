extends SceneTree
## Run with the game project and pass the RES-053 source and atlas output folders after --.

const ResidentSprite := preload("res://scripts/resident_sprite.gd")
const CARRY_STATES := ["carry_wood", "carry_stone", "carry_grain"]
const ATLAS_DIR := "res://assets/characters/residents"
const FRAME := Vector2i(ResidentSprite.APPROVED_FRAME)
const FLOOR := Vector2i(ResidentSprite.APPROVED_FLOOR)
const COLUMNS := ResidentSprite.APPROVED_COLUMNS

func _initialize() -> void:
	call_deferred("bake")

func fiber(color: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.roughness = .96
	return material

func cord(parent: Node3D, from: Vector3, to: Vector3, radius: float, material: Material) -> void:
	var part := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.radial_segments = 6
	mesh.rings = 0
	mesh.height = from.distance_to(to)
	part.mesh = mesh
	part.material_override = material
	parent.add_child(part)
	part.position = (from + to) * .5
	part.quaternion = Quaternion(Vector3.UP, (to - from).normalized())

func loop(parent: Node3D, y: float, radius: float, depth: float, thickness: float, material: Material) -> void:
	var band := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - thickness
	torus.outer_radius = radius + thickness
	torus.rings = 16
	torus.ring_segments = 8
	band.mesh = torus
	band.material_override = material
	parent.add_child(band)
	band.position.y = y
	band.scale.z = depth

func harness(parent: Node3D, is_wood: bool) -> void:
	var rope := fiber("ac8050")
	var width := .15 if is_wood else .135
	for side in [-1.0, 1.0]:
		var x: float = width * side
		var route := PackedVector3Array([
			Vector3(x, .13, -.11), Vector3(x, .192, -.06), Vector3(x, .204, .035),
			Vector3(x, .141, .113), Vector3(x * 1.14, -.037, .126),
			Vector3(x * 1.38, -.065, .043), Vector3(x * 1.3, -.11, -.14),
		])
		for index in route.size() - 1:
			cord(parent, route[index], route[index + 1], .015, rope)

func wood_pack(parent: Node3D) -> void:
	var logs: Node3D = ResidentLoadVisual.LOADS.wood.instantiate()
	parent.add_child(logs)
	logs.scale = Vector3(.83, 1.23, .9)
	logs.position = Vector3(0, -.035, -.164)
	var rope := fiber("a37a4b")
	for side in [-1.0, 1.0]:
		var x: float = .185 * side
		cord(parent, Vector3(x, -.22, -.23), Vector3(x * .91, .145, -.236), .021, rope)

func wicker_pack(parent: Node3D, kind: String) -> void:
	var basket := Node3D.new()
	parent.add_child(basket)
	basket.position = Vector3(0, -.124, -.262)
	var wicker := fiber("947049")
	var pale := fiber("b8905d")
	var deep := fiber("775735")
	var shell := MeshInstance3D.new()
	var vase := CylinderMesh.new()
	vase.top_radius = .234
	vase.bottom_radius = .163
	vase.height = .35
	vase.radial_segments = 16
	shell.mesh = vase
	shell.material_override = deep
	basket.add_child(shell)
	shell.scale.z = .64
	for row in 9:
		var t := float(row) / 8.0
		var radius := lerpf(.167, .239, t)
		loop(basket, lerpf(-.166, .175, t), radius, .64, .009 if row < 8 else .019, pale if row % 2 == 0 else wicker)
	for slat in 12:
		var angle := slat * TAU / 12.0
		var root := Vector3(cos(angle) * .167, -.166, sin(angle) * .107)
		for direction in [-1.0, 1.0]:
			var upper: float = angle + direction * TAU / 13.0
			var end := Vector3(cos(upper) * .245, .168, sin(upper) * .157)
			cord(basket, root, end, .009 if kind == "stone" else .006, pale if direction > 0 else wicker)
	if kind == "stone":
		var stones: Node3D = ResidentLoadVisual.LOADS.stone.instantiate()
		basket.add_child(stones)
		stones.scale = Vector3(1.1, .87, .73)
		stones.position.y = .117
		for child in stones.get_children():
			if not child.name.begins_with("Icosphere"):
				child.hide()
		return
	var stalk := fiber("b18235")
	var seed := fiber("dba749")
	var pale_seed := fiber("edc471")
	for index in 9:
		var t := float(index) / 8.0
		var bottom := Vector3(lerpf(-.12, .12, t), .08, 0)
		var shoulder := Vector3(lerpf(-.18, .15, t), .238 + .085 * sin(t * PI), sin(index * 2.4) * .065)
		var tip := shoulder + Vector3(lerpf(-.095, .083, t), .084 + .035 * sin(index * 1.6), -.04)
		cord(basket, bottom, shoulder, .009, stalk)
		cord(basket, shoulder, tip, .027, seed)
		for grain in 3:
			var at := shoulder.lerp(tip, .22 + grain * .21)
			cord(basket, at, at + Vector3(.019 if grain % 2 == 0 else -.019, .023, .004), .013, pale_seed)

func bake() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(2)
		return
	# Render from the same camera and lighting used for normal RES-053 frames.
	var reference := HybridCharacter.new()
	root.add_child(reference)
	var viewport := reference.viewport
	var world := viewport.get_child(0) as Node3D
	reference.hide()
	reference.pivot.hide()
	viewport.size = Vector2i(256, 280)
	reference.camera.size = 3.0 * viewport.size.y / 200.0
	var crop := Rect2i(Vector2i(reference.camera.unproject_position(Vector3.ZERO).round()) - FLOOR * 2, FRAME * 2)
	for sex in ["Man", "Woman"]:
		var filename := "res053-%s.png" % sex.to_lower()
		var atlas := Image.load_from_file(ProjectSettings.globalize_path(ATLAS_DIR.path_join(filename)))
		if not atlas:
			quit(3)
			return
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var error := doc.append_from_file(args[0].path_join("Resident-%s-01-11.glb" % sex), state)
		if error != OK:
			quit(error)
			return
		var actor := doc.generate_scene(state) as Node3D
		world.add_child(actor)
		var rig := actor.find_child("Skeleton3D", true, false) as Skeleton3D
		var player := actor.get_node("AnimationPlayer") as AnimationPlayer
		var travel := actor.get_node("Travel") as Node3D
		travel.get_node("StoneAxe").hide()
		player.play("07_Walk")
		player.advance(0.0)
		player.pause()
		var spine := rig.find_bone("Spine")
		var rest_rotation := rig.get_bone_global_rest(spine).basis.orthonormalized().inverse()
		for key: String in CARRY_STATES:
			var kind := key.trim_prefix("carry_")
			var prop := Node3D.new()
			travel.add_child(prop)
			harness(prop, kind == "wood")
			if kind == "wood":
				wood_pack(prop)
			else:
				wicker_pack(prop, kind)
			var track: Vector3i = ResidentSprite.APPROVED_ROWS[key]
			for sample in track.y:
				player.seek(float(track.z * sample) / (30.0 * track.y), true)
				travel.position = Vector3.ZERO
				for direction in 4:
					actor.rotation.y = direction * TAU / 4.0
					rig.force_update_all_bone_transforms()
					var chest := travel.global_transform.affine_inverse() * rig.global_transform * rig.get_bone_global_pose(spine)
					var rotation := chest.basis.orthonormalized() * rest_rotation
					var size := .91 if sex == "Woman" else 1.0
					prop.transform = Transform3D(rotation.scaled(Vector3.ONE * size), chest.origin + rotation * Vector3(0, .13, 0))
					viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
					await process_frame
					await RenderingServer.frame_post_draw
					var frame := viewport.get_texture().get_image().get_region(crop)
					frame.convert(Image.FORMAT_RGBA8)
					frame.resize(FRAME.x, FRAME.y, Image.INTERPOLATE_LANCZOS)
					var bounds := frame.get_used_rect()
					if bounds.position.x < 1 or bounds.end.x >= FRAME.x - 1 or bounds.position.y < 1 or bounds.end.y >= FRAME.y - 1 or bounds.size.y < 30:
						push_error("Clipped or empty cargo frame %s %s %d %d %s" % [sex, kind, sample, direction, bounds])
						quit(4)
						return
					var tile := (track.x + sample) * 4 + direction
					atlas.blit_rect(frame, Rect2i(Vector2i.ZERO, FRAME), Vector2i(tile % COLUMNS, tile / COLUMNS) * FRAME)
			prop.free()
			print("CARGO BAKE ", sex, " ", kind, " ", track.y * 4)
		error = atlas.save_png(args[1].path_join(filename))
		if error != OK:
			quit(error)
			return
		actor.free()
	reference.free()
	quit()
