extends WorldAnimal
## Native adult-boar or forest-deer presentation with ordinary encounter actor API.
## The screen retains its rules and positions; this actor only poses actual art and exposes live bones.

const Prey := preload("res://scripts/hunt_production_prey_profile.gd")
## Set before add_child. Adult remains the default for existing call sites.
var native_species := "adult"
var native: Prey.WildlifeRig
var native_phase := "idle"
var native_elapsed := 0.
var externally_driven := false

func _ready() -> void:
	native = Prey.create(native_species, self)
	if native == null:
		return
	native.name = "NativeAdultBoar" if native_species == "adult" else "NativeForestDeer"
	native.set_process(false)
	native.set_physics_process(false)
	native.position = Vector2.ZERO
	native.scale = Vector2.ONE
	viewport = native.viewport
	render_size = viewport.size.x
	pivot = native.pivot
	camera = native.camera
	display = native.display
	rig = native.skeleton
	for i in rig.get_bone_count():
		bones[rig.get_bone_name(i)] = i
		rest_rotations[i] = rig.get_bone_rest(i).basis.get_rotation_quaternion()
	footprint_body = StaticBody2D.new()
	footprint_body.name = "NonCollidingEncounterFootprint"
	footprint_body.collision_layer = 0
	footprint_body.collision_mask = 0
	add_child(footprint_body)
	camera.position.y = 7.
	camera.look_at(Vector3(0, 1, 0))
	update_geometry()
	sample_native_phase("idle", 0.)
	externally_driven = false

func is_native_ready() -> bool:
	return is_instance_valid(native) and is_instance_valid(rig) and not Prey.markers(native).is_empty()

func sample_native_phase(phase: String, elapsed: float) -> bool:
	if not is_instance_valid(native) or not Prey.sample(native, phase, elapsed):
		return false
	externally_driven = true
	native_phase = phase
	native_elapsed = elapsed
	pivot.rotation.y = heading
	pivot.position.y += Prey.safe_floor_lift(native)
	rig.force_update_all_bone_transforms()
	return true

func animate_rig(delta: float) -> void:
	if not is_instance_valid(native):
		return
	if externally_driven:
		pivot.rotation.y = heading
		return
	var phase := "approach" if walking > .20 else "idle"
	if phase != native_phase: native_elapsed = 0.
	sample_native_phase(phase, native_elapsed + maxf(delta, 0.))
	externally_driven = false

func native_muzzle() -> Vector3:
	return Prey.muzzle(native)

func native_markers() -> Dictionary:
	return Prey.markers(native)

## Profile-specific contact capsule bones; enclosing radius is encounter-owned.
func native_body_bones() -> PackedStringArray:
	match native_species:
		"adult": return PackedStringArray(["trunk", "head"])
		"forest": return PackedStringArray(["trunk", "neck"])
	return PackedStringArray()

func native_body_points() -> Dictionary:
	if not is_native_ready():return {}
	var keys := native_body_bones()
	if keys.size()!=2:return {}
	rig.force_update_all_bone_transforms()
	var a := Prey.bone_world(native,keys[0])
	var b := Prey.bone_world(native,keys[1])
	if not a.is_finite() or not b.is_finite() or a.distance_squared_to(b)<=0.000001:return {}
	return {"a":a,"b":b}
