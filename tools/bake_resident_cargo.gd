extends SceneTree
## Run with the game project and pass the RES-053 source and atlas output folders after --.

const ResidentSprite := preload("res://scripts/resident_sprite.gd")
const CARRY_STATES := ["carry_wood", "carry_stone", "carry_grain"]
const ATLAS_DIR := "res://assets/characters/residents"
const FRAME := Vector2i(ResidentSprite.APPROVED_FRAME)
const FLOOR := Vector2i(ResidentSprite.APPROVED_FLOOR)
const COLUMNS := ResidentSprite.APPROVED_COLUMNS
const CARRY_FRAME := Vector2i(ResidentSprite.APPROVED_FRAME * ResidentSprite.CARRY_RENDER_SCALE)
const CARRY_COLUMNS := ResidentSprite.CARRY_COLUMNS
const CARGO_SIZE_MULTIPLIER := 1.5
const CARGO_SURFACE := """
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform vec4 base_color : source_color;
uniform vec4 detail_color : source_color;
uniform int pattern;
varying vec3 local_point;

void vertex() {
	local_point = VERTEX;
}

void fragment() {
	vec3 p = local_point;
	float angle = atan(p.z + 0.0001, p.x);
	float detail;
	if (pattern == 0) {
		float groove = sin(angle * 8.0 + sin(p.y * 15.0 + angle * 3.0) * 0.9);
		float grain = sin(angle * 21.0 - p.y * 9.0 + sin(p.y * 23.0)) * 0.13;
		float bark_edge = smoothstep(-0.8, 0.5, groove);
		detail = clamp(0.19 + bark_edge * 0.65 + grain, 0.0, 1.0);
	} else if (pattern == 1) {
		float radius = length(p.xz - vec2(0.007, -0.009));
		float rings = sin(radius * 246.0 + sin(angle * 3.0) * 0.46);
		detail = 0.23 + smoothstep(-0.5, 0.3, rings) * 0.62;
		detail *= 1.0 - 0.43 * smoothstep(0.062, 0.079, radius);
	} else if (pattern == 3) {
		float twist = sin(angle * 3.0 + p.y * 216.0);
		detail = mix(0.26, 0.9, smoothstep(-0.65, 0.7, twist));
	} else {
		float vein = sin(dot(p, vec3(13.0, 42.0, 29.0)) + sin(p.x * 35.0) * 0.45);
		detail = smoothstep(-0.82, 0.87, vein) * 0.57;
	}
	ALBEDO = mix(base_color.rgb, detail_color.rgb, detail);
	ROUGHNESS = 0.96;
}
"""

var surface_shader := Shader.new()

func _initialize() -> void:
	surface_shader.code = CARGO_SURFACE
	call_deferred("bake")

func fiber(color: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.roughness = .96
	return material

func cargo_surface(base_color: String, detail_color: String, pattern: int) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = surface_shader
	material.set_shader_parameter("base_color", Color(base_color))
	material.set_shader_parameter("detail_color", Color(detail_color))
	material.set_shader_parameter("pattern", pattern)
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
	var rope := cargo_surface("94673e", "d2ad75", 3)
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
	var bark := [
		cargo_surface("6e3b25", "a67345", 0),
		cargo_surface("79502f", "b17b4d", 0),
		cargo_surface("61402a", "94603b", 0),
	]
	var rings := cargo_surface("ac7744", "e4b87f", 1)
	var rope := cargo_surface("a77848", "dfbc81", 3)
	for index in logs.get_child_count():
		var piece := logs.get_child(index) as MeshInstance3D
		var source := piece.mesh.surface_get_material(0)
		match source.resource_name:
			"bark": piece.material_override = bark[index / 3]
			"cut wood": piece.material_override = rings
			"fiber": piece.material_override = rope
	for side in [-1.0, 1.0]:
		var x: float = .185 * side
		cord(parent, Vector3(x, -.22, -.23), Vector3(x * .91, .145, -.236), .021, rope)

func wicker_pack(parent: Node3D, kind: String) -> void:
	var basket := Node3D.new()
	parent.add_child(basket)
	basket.position = Vector3(0, -.124, -.262)
	var wicker := fiber("aa7843")
	var pale := fiber("d4a764")
	var dark := fiber("8e6038")
	var rim := cargo_surface("b4844d", "e2bc7c", 3)
	var deep := fiber("79502d")
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
		var band_color: Material = rim if row == 8 else pale if row % 2 == 0 else wicker
		loop(basket, lerpf(-.166, .175, t), radius, .64, .009 if row < 8 else .019, band_color)
	for slat in 12:
		var angle := slat * TAU / 12.0
		var root := Vector3(cos(angle) * .167, -.166, sin(angle) * .107)
		for direction in [-1.0, 1.0]:
			var upper: float = angle + direction * TAU / 13.0
			var end := Vector3(cos(upper) * .245, .168, sin(upper) * .157)
			cord(basket, root, end, .009 if kind == "stone" else .006, pale if direction > 0 else dark)
	if kind == "stone":
		var stones: Node3D = ResidentLoadVisual.LOADS.stone.instantiate()
		basket.add_child(stones)
		stones.scale = Vector3(1.1, .87, .73)
		stones.position.y = .117
		var rock_colors := [
			cargo_surface("777b84", "afb1ae", 2),
			cargo_surface("626974", "9c9fa3", 2),
			cargo_surface("958a7c", "c1b4a1", 2),
		]
		var rock_index := 0
		for child in stones.get_children():
			if child.name.begins_with("Icosphere"):
				(child as MeshInstance3D).material_override = rock_colors[rock_index % rock_colors.size()]
				rock_index += 1
			else:
				child.hide()
		return
	var stalk := fiber("b18942")
	var husks := [fiber("c89438"), fiber("e1ad49"), fiber("edc26c")]
	var kernels := [fiber("d6a345"), fiber("f0ca79")]
	for index in 9:
		var t := float(index) / 8.0
		var bottom := Vector3(lerpf(-.12, .12, t), .08, 0)
		var shoulder := Vector3(lerpf(-.18, .15, t), .238 + .085 * sin(t * PI), sin(index * 2.4) * .065)
		var tip := shoulder + Vector3(lerpf(-.095, .083, t), .084 + .035 * sin(index * 1.6), -.04)
		cord(basket, bottom, shoulder, .009, stalk)
		cord(basket, shoulder, tip, .027, husks[index % husks.size()])
		for grain in 4:
			var at := shoulder.lerp(tip, .16 + grain * .18)
			var direction := 1.0 if grain % 2 == 0 else -1.0
			cord(basket, at, at + Vector3(.019 * direction, .021, .004), .012, kernels[grain % 2])

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
	var first_carry: Vector3i = ResidentSprite.APPROVED_ROWS[CARRY_STATES[0]]
	var last_carry: Vector3i = ResidentSprite.APPROVED_ROWS[CARRY_STATES[-1]]
	var first_tile := first_carry.x * 4
	var carry_rows := ceili(float((last_carry.x + last_carry.y) * 4 - first_tile) / CARRY_COLUMNS)
	for sex in ["Man", "Woman"]:
		var filename := "res053-%s.png" % sex.to_lower()
		var atlas := Image.load_from_file(ProjectSettings.globalize_path(ATLAS_DIR.path_join(filename)))
		if not atlas:
			quit(3)
			return
		var carry_atlas := Image.create_empty(CARRY_FRAME.x * CARRY_COLUMNS, CARRY_FRAME.y * carry_rows, false, Image.FORMAT_RGBA8)
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
			# Size the load separately from the straps fitted to the shoulders.
			var load_mesh := Node3D.new()
			prop.add_child(load_mesh)
			load_mesh.scale = Vector3.ONE * CARGO_SIZE_MULTIPLIER
			load_mesh.position = Vector3(0, -.025, .05)
			if kind == "wood":
				wood_pack(load_mesh)
			else:
				wicker_pack(load_mesh, kind)
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
					frame.resize(CARRY_FRAME.x, CARRY_FRAME.y, Image.INTERPOLATE_LANCZOS)
					var bounds := frame.get_used_rect()
					if bounds.position.x < 1 or bounds.end.x >= CARRY_FRAME.x - 1 or bounds.position.y < 1 or bounds.end.y >= CARRY_FRAME.y - 1 or bounds.size.y < 45:
						push_error("Clipped or empty cargo frame %s %s %d %d %s" % [sex, kind, sample, direction, bounds])
						quit(4)
						return
					var tile := (track.x + sample) * 4 + direction - first_tile
					carry_atlas.blit_rect(frame, Rect2i(Vector2i.ZERO, CARRY_FRAME), Vector2i(tile % CARRY_COLUMNS, tile / CARRY_COLUMNS) * CARRY_FRAME)
			prop.free()
			print("CARGO BAKE ", sex, " ", kind, " ", track.y * 4)
		error = carry_atlas.save_png(args[1].path_join(filename.get_basename() + "-carry.png"))
		if error != OK:
			quit(error)
			return
		var base_height := ceili(float(first_tile) / COLUMNS) * FRAME.y
		var base_atlas := atlas.get_region(Rect2i(0, 0, atlas.get_width(), base_height))
		for tile in range(first_tile, base_height / FRAME.y * COLUMNS):
			base_atlas.fill_rect(Rect2i(Vector2i(tile % COLUMNS, tile / COLUMNS) * FRAME, FRAME), Color.TRANSPARENT)
		error = base_atlas.save_png(args[1].path_join(filename))
		if error != OK:
			quit(error)
			return
		actor.free()
	reference.free()
	quit()
