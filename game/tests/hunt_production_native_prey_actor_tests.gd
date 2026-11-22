extends SceneTree
const Actor := preload("res://scripts/hunt_production_boar_actor.gd")
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func run() -> void:
	for id in ["adult","forest"]:
		var actor := Actor.new()
		if id == "forest":actor.native_species=id
		actor.position=Vector2(300,200)
		actor.world_height=120.
		root.add_child(actor)
		actor.set_process(false)
		await process_frame
		check(actor is WorldAnimal and actor.is_native_ready(),id+" native actor")
		if not actor.is_native_ready():continue
		check(actor.native.profile_key==id and actor.viewport==actor.native.viewport and actor.rig==actor.native.skeleton,id+" preserves viewport/rig")
		var floor := actor.display.to_global(actor.camera.unproject_position(Vector3.ZERO))
		check(floor.distance_to(actor.global_position)<.001,id+" grounded origin")
		var body := actor.native_body_points()
		check(actor.native_body_bones()[1]==("head" if id=="adult" else "neck") and body.has("a") and body.has("b"),id+" role-specific capsule bones")
		if body.has("a"):
			check(actor.camera.unproject_position(body.a).is_finite() and actor.camera.unproject_position(body.b).distance_to(actor.camera.unproject_position(body.a))>.5,id+" distinct projected capsule points")
		var marks := actor.native_markers()
		var release:float=marks.charge_release
		check(actor.sample_native_phase("charge",release-.001) and actor.native.clip=="req046_skill_anticipation",id+" native windup")
		check(actor.sample_native_phase("charge",release) and actor.native.clip=="req046_skill_execute",id+" native release")
		var tip:=actor.native_muzzle()
		check(tip.is_finite() and actor.camera.unproject_position(tip).is_finite(),id+" projected muzzle")
		print(id, " ", actor.native_body_bones(), " ", body, " muzzle ", tip)
		actor.queue_free()
		await process_frame
	print("Native prey actor failures=",failures)
	quit(1 if failures else 0)
