extends RefCounted
## Player battle's manual frontline actions and single-contact forward shield window.
## All vectors/transforms passed to the guard must use the same collision space.

const HAN_SPEAR_2 := "han_spear_2"
const HAN_SPEAR_3 := "han_spear_3"
const URAM_CLUB_2 := "uram_club_2"
const URAM_GUARD_3 := "uram_guard_3"
const GUARD_OPEN := 0.03
const GUARD_CLOSE := 0.32

static func describe(action: String, legacy_damage: int) -> Dictionary:
	var damage := maxi(0, legacy_damage)
	match action:
		HAN_SPEAR_2:
			return {"id": action, "actor": "han", "sp": 2, "clip": "skill", "contact": "spear", "damage": damage}
		HAN_SPEAR_3:
			return {"id": action, "actor": "han", "sp": 3, "clip": "chain", "contact": "spear", "damage": damage}
		URAM_CLUB_2:
			return {"id": action, "actor": "uram", "sp": 2, "clip": "skill", "contact": "club", "damage": damage}
		URAM_GUARD_3:
			return {"id": action, "actor": "uram", "sp": 3, "clip": "counter", "contact": "shield", "damage": 0}
	return {}

class Guard extends RefCounted:
	var _defender := -1
	var _armed_at := 0.0

	func arm(defender_id: int, clock: float) -> bool:
		if defender_id < 0 or not is_finite(clock) or (_defender >= 0 and clock < _armed_at + GUARD_CLOSE):
			return false
		_defender = defender_id
		_armed_at = clock
		return true

	func cancel() -> void:
		_defender = -1

	## Interpolates the visible face and muzzle to the open interval, then sweeps
	## in relative face space. Body fraction is optional, relative to the full step.
	func step(frame_start: float, frame_end: float, target_id: int, old_muzzle: Vector3, new_muzzle: Vector3, old_face: Transform3D, new_face: Transform3D, half_size: Vector2, attack_active: bool, body_hit_fraction: float = INF, nose_radius: float = 0.15) -> Dictionary:
		if _defender < 0 or not is_finite(frame_start) or not is_finite(frame_end) or frame_end <= frame_start:
			return {}
		var close := _armed_at + GUARD_CLOSE
		var lo := maxf(frame_start, _armed_at + GUARD_OPEN)
		var hi := minf(frame_end, close)
		if hi <= lo or target_id != _defender or not attack_active:
			if frame_end >= close:
				cancel()
			return {}
		var u := inverse_lerp(frame_start, frame_end, lo)
		var v := inverse_lerp(frame_start, frame_end, hi)
		var f0 := old_face.interpolate_with(new_face, u)
		var f1 := old_face.interpolate_with(new_face, v)
		var t := FrontlineFace.sweep(old_muzzle.lerp(new_muzzle, u), old_muzzle.lerp(new_muzzle, v), f0, f1, half_size, nose_radius)
		var f := lerpf(u, v, t) if is_finite(t) else INF
		if f == INF or f > body_hit_fraction:
			if frame_end >= close:
				cancel()
			return {}
		var face := old_face.interpolate_with(new_face, f)
		var point := face.affine_inverse() * old_muzzle.lerp(new_muzzle, f)
		point.z = 0.0
		var hit := {"kind": "shield", "defender_id": _defender, "fraction": f, "time": lerpf(frame_start, frame_end, f), "point": face * point, "normal": (face.basis.inverse().transposed() * Vector3.BACK).normalized()}
		cancel()
		return hit

class FrontlineFace:
	## Half size and nose radius are in face-local units. +Z is the visible outward normal.
	static func sweep(old_probe: Vector3, new_probe: Vector3, old_face: Transform3D, new_face: Transform3D, half_size: Vector2, nose_radius: float) -> float:
		if half_size.x <= 0.0 or half_size.y <= 0.0 or nose_radius < 0.0 or absf(old_face.basis.determinant()) < 0.000001 or absf(new_face.basis.determinant()) < 0.000001:
			return INF
		var a := old_face.affine_inverse() * old_probe
		var b := new_face.affine_inverse() * new_probe
		if a.z < 0.0 or b.z > nose_radius or b.z >= a.z - 0.0001:
			return INF
		var t := 0.0 if a.z <= nose_radius else (a.z - nose_radius) / (a.z - b.z)
		var at := a.lerp(b, t)
		var radial := Vector2(at.x, at.y) / (half_size + Vector2.ONE * nose_radius)
		return t if radial.length_squared() <= 1.0 else INF
