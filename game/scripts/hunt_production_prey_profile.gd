extends RefCounted
## Production wildlife presentation adapter only. Never owns rewards, HP,
## stage unlocks, AI, navigation or hit resolution.

const Motion := preload("res://scripts/model_motion_profile.gd")
const WildlifeRig := preload("res://scripts/wildlife_lab_preview.gd")
const SPECIES := ["forest", "stag", "juvenile", "adult"]
const FIRST_CHAPTER_FINAL_STAGE := 5

static func encounter_species(stage_id: int, cleared: int, candidate_enabled: bool) -> String:
	if candidate_enabled and stage_id == FIRST_CHAPTER_FINAL_STAGE and stage_id <= cleared:
		return "adult"
	return "forest"

static func model_path(species: String) -> String:
	return Motion.ANIMAL_MODELS[species] if accepts(species) else ""
const CHARGE_WINDUP := "req046_skill_anticipation"
const CHARGE_EXECUTE := "req046_skill_execute"
const FEET := ["front_foot.R", "front_foot.L", "hind_foot.R", "hind_foot.L"]
const FLOOR_CLEARANCE := .005

static func accepts(species: String) -> bool:
	return species in SPECIES

## Call with the prey resolved by the existing stage/encounter (or an explicit opt-in).
## A missing or unsupported identifier tells the caller to keep its current renderer.
static func create(species: String, parent: Node) -> WildlifeRig:
	if not accepts(species) or not is_instance_valid(parent):
		return null
	if not ResourceLoader.exists(Motion.ANIMAL_MODELS[species]):
		return null
	var rig := WildlifeRig.new()
	rig.profile_key = species
	rig.model_path = Motion.ANIMAL_MODELS[species]
	parent.add_child(rig)
	if not is_instance_valid(rig.animation) or not is_instance_valid(rig.skeleton):
		rig.queue_free()
		return null
	return rig

static func clips(species: String) -> Dictionary:
	if not accepts(species):
		return {}
	return {
		"idle": Motion.animal_clip(species, "idle"),
		"approach": Motion.animal_clip(species, "run"),
		"basic": Motion.animal_clip(species, "attack"),
		"windup": CHARGE_WINDUP,
		"execute": CHARGE_EXECUTE,
		"hit": Motion.animal_clip(species, "hit"),
		"ko": Motion.animal_clip(species, "death"),
	}

## Read after the full rig is attached. Includes playback-rate-adjusted markers.
## attack contact remains owned by the caller's existing hit resolver.
static func markers(rig: WildlifeRig) -> Dictionary:
	if not is_instance_valid(rig) or not accepts(rig.profile_key) or not is_instance_valid(rig.animation):
		return {}
	var v := clips(rig.profile_key)
	for phase in v:
		if rig.length(v[phase]) <= 0.:
			return {}
	var windup := rig.length(v.windup)
	var execute := rig.length(v.execute)
	var contact := clampf(float(Motion.CONTACT[rig.profile_key]), windup, windup + execute)
	return {"idle": rig.length(v.idle), "approach": rig.length(v.approach),
		"basic": rig.length(v.basic), "hit": rig.length(v.hit), "windup": windup,
		"execute": execute, "charge_release": windup, "charge_contact_reference": contact,
		"charge_end": windup + execute, "ko": rig.presentation_length(v.ko)}

## Clips are sampled from elapsed presentation time, not a frame counter.
## False preserves the prior clip and is safe for unsupported states.
static func sample(rig: WildlifeRig, phase: String, elapsed: float) -> bool:
	if not is_instance_valid(rig) or not is_finite(elapsed) or not is_instance_valid(rig.animation):
		return false
	var map := clips(rig.profile_key)
	if phase == "charge":
		var wind := rig.length(CHARGE_WINDUP)
		return sample(rig, "windup" if elapsed < wind else "execute", elapsed if elapsed < wind else elapsed-wind)
	if not map.has(phase) or rig.length(map[phase]) <= 0.:
		return false
	var clip: String = map[phase]
	if rig.clip != clip:
		rig.start(clip)
	rig.sample(maxf(0., elapsed), false)
	rig.skeleton.force_update_all_bone_transforms()
	return true

static func bone_world(rig: WildlifeRig, name: String) -> Vector3:
	if not is_instance_valid(rig) or not is_instance_valid(rig.skeleton):
		return Vector3.INF
	var i := rig.skeleton.find_bone(name)
	if i < 0:
		return Vector3.INF
	return rig.skeleton.to_global(rig.skeleton.get_bone_global_pose(i).origin)

## Cosmetic muzzle anchor; not a damage collider or a ground-ring anchor.
static func muzzle(rig: WildlifeRig) -> Vector3:
	var head := bone_world(rig, "head")
	if head == Vector3.INF:
		return head
	if rig.profile_key == "adult":
		var trunk := bone_world(rig, "trunk")
		if trunk == Vector3.INF:
			return head
		var forward := head - trunk
		forward.y = 0.
		return head + forward.normalized() * .46 + Vector3.UP * .025
	var s := rig.skeleton
	var pose := s.get_bone_global_pose(s.find_bone("head"))
	return s.to_global(pose * Vector3(0., 0., .23))

## Grounding helper in world units; caller may convert to its native parent.
## Corrects only floor intersections; does not snap authored hops to the floor.
static func safe_floor_lift(rig: WildlifeRig, ground_y: float=0.) -> float:
	var low := INF
	for foot in FEET:
		var point := bone_world(rig, foot)
		if point != Vector3.INF:
			low = minf(low, point.y)
	return clampf(ground_y + FLOOR_CLEARANCE - low, 0., .38) if is_finite(low) else 0.
