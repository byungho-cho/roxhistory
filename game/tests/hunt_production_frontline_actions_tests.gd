extends SceneTree

# Run: godot --headless --path game --script res://tests/hunt_production_frontline_actions_tests.gd
const Frontline := preload("res://scripts/hunt_production_frontline_actions.gd")
const FACE := Transform3D.IDENTITY
const HALF := Vector2(0.45, 0.52)
const IN := Vector3(0, 0, 1)
const OUT := Vector3(0, 0, -1)
var _failures := 0
var _checks := 0

func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(label)

func _guard() -> Frontline.Guard:
	var guard := Frontline.Guard.new()
	guard.arm(7, 0.0)
	return guard

func _initialize() -> void:
	_expect(Frontline.describe("han_spear_2", 8).sp == 2 and Frontline.describe("han_spear_2", 8).damage == 8, "Han spear 2 uses 2SP/legacy damage")
	_expect(Frontline.describe("han_spear_3", 8).sp == 3 and Frontline.describe("han_spear_3", 8).clip == "chain" and Frontline.describe("han_spear_3", 8).damage == 8, "Han spear 3 uses 3SP/chain/legacy damage")
	_expect(Frontline.describe("uram_club_2", 31).sp == 2 and Frontline.describe("uram_club_2", 31).damage == 31, "Uram club 2 uses 2SP/legacy damage")
	_expect(Frontline.describe("uram_guard_3", 31).sp == 3 and Frontline.describe("uram_guard_3", 31).damage == 0, "Uram guard 3 has no invented counter damage")
	_expect(Frontline.describe("strike", 31).is_empty(), "legacy IDs remain external")

	var guard := _guard()
	var result := guard.step(.10, .20, 7, IN, OUT, FACE, FACE, HALF, true)
	_expect(not result.is_empty() and result.defender_id == 7 and is_equal_approx(result.time, .1425) and result.point.is_equal_approx(Vector3.ZERO) and result.normal.is_equal_approx(Vector3.BACK), "inbound physical shield contact")
	_expect(guard.step(.20, .30, 7, IN, OUT, FACE, FACE, HALF, true).is_empty(), "same shield cannot accept twice")
	_expect(_guard().step(.10, .20, 8, IN, OUT, FACE, FACE, HALF, true).is_empty(), "other party member is not protected")
	_expect(_guard().step(.10, .20, 7, IN, OUT, FACE, FACE, HALF, false).is_empty(), "idle/wrong attack phase")
	_expect(_guard().step(.10, .20, 7, OUT, IN, FACE, FACE, HALF, true).is_empty(), "rear approach")
	_expect(_guard().step(.10, .20, 7, IN + Vector3.RIGHT, OUT + Vector3.RIGHT, FACE, FACE, HALF, true).is_empty(), "misses shield rim")
	_expect(_guard().step(.10, .20, 7, IN, OUT, FACE, FACE, HALF, true, .40).is_empty(), "body hit occurred first")
	_expect(_guard().step(.01, .02, 7, IN, OUT, FACE, FACE, HALF, true).is_empty(), "too early")
	_expect(_guard().step(.31, .40, 7, IN, OUT, FACE, FACE, HALF, true).is_empty(), "too late within a spanning step")
	_expect(_guard().step(.0, .08, 7, IN, OUT, FACE, FACE, HALF, true).has("fraction"), "whole step spanning window can hit")
	_expect(_guard().step(.10, .20, 7, Vector3.BACK * .1, Vector3.BACK * .1, FACE, FACE, HALF, true).is_empty(), "stationary surface overlap is not a parry")
	var pushed := Transform3D(Basis.IDENTITY, Vector3.BACK * .8)
	_expect(_guard().step(.10, .20, 7, Vector3.BACK * .6, Vector3.BACK * .6, FACE, pushed, HALF, true).has("point"), "forward moving shield meets probe in relative space")
	guard = _guard()
	_expect(not guard.arm(8, .16) and guard.arm(8, .33), "cannot replace live window; can rearm after expiry")
	guard.cancel()
	_expect(guard.step(.41, .52, 8, IN, OUT, FACE, FACE, HALF, true).is_empty(), "cancel clears guard")
	print("Frontline actions: %s/%s passed" % [_checks - _failures, _checks])
	quit(1 if _failures else 0)
