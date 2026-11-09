class_name ResidentLoadVisual
extends BoneAttachment3D

const LOADS := {
	"wood": preload("res://assets/characters/residents/cargo/wood.glb"),
	"stone": preload("res://assets/characters/residents/cargo/stone.glb"),
	"grain": preload("res://assets/characters/residents/cargo/grain.glb"),
}
const BASKET_SCALE := 3.0
var displayed_kind := ""
var prop: Node3D

func update_load(cargo: Dictionary) -> void:
	var kind := str(cargo.get("kind", ""))
	if not LOADS.has(kind): kind = ""
	if kind == displayed_kind: return
	if is_instance_valid(prop):
		remove_child(prop)
		prop.queue_free()
	displayed_kind = kind
	if kind.is_empty() or bone_idx < 0: return
	var correction := get_skeleton().get_bone_global_rest(bone_idx).basis.inverse()
	var basket := kind != "wood"
	var size_factor := BASKET_SCALE if basket else 1.0
	var offset := Vector3(0, .02, -.64 if basket else -.28)
	prop = LOADS[kind].instantiate()
	prop.transform = Transform3D(correction.scaled(Vector3.ONE * size_factor), correction * offset)
	add_child(prop)
