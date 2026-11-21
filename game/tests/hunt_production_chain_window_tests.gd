extends SceneTree

const Chain = preload("res://scripts/hunt_production_chain_window.gd")
const HuntRules = preload("res://scripts/deer_hunt_rules.gd")
var checks := 0
var failures := 0


func ck(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(text)


func _initialize() -> void:
	var clock := Chain.new()
	var reserved: Array[StringName] = []
	var allow := func(hero: StringName) -> bool:
		reserved.append(hero)
		return true
	var no_sp := func(_hero: StringName) -> bool: return false
	ck(clock.accept(&"saebom", 0.0, allow).is_empty(), "wrong starter cannot reserve")
	ck(clock.accept(&"uram", 0.0, no_sp).is_empty() and not clock.active(), "failed reservation cannot start")
	var u := clock.accept(&"uram", 0.0, allow)
	ck(u.get("await_guard", false) and clock.deadline == 2.0 and clock.actionable() == &"", "Uram click alone starts exactly 2 seconds, not Saebom unlock")
	ck(clock.accept(&"uram", .10, allow).is_empty() and clock.deadline == 2., "duplicate Uram no spend, no refresh")
	ck(clock.accept(&"saebom", .30, allow).is_empty() and reserved.size() == 1, "real guard required before accepting")
	ck(not clock.confirm_guard(.40, u.generation+1), "stale/different arm cannot unlock")
	ck(clock.confirm_guard(.60,u.generation) and clock.actionable() == &"saebom" and clock.deadline == 2., "actual guard within original timer unlocks without refresh")
	ck(not clock.confirm_guard(1.10,u.generation) and clock.deadline == 2., "repeated guard does not refresh")
	ck(clock.accept(&"hangyeol",1.21,allow).is_empty() and reserved.size() == 1, "wrong order even during valid guard period")
	ck(clock.accept(&"saebom",1.70,no_sp).is_empty() and clock.deadline == 2., "bad Saebom SP no advancement")
	var s := clock.accept(&"saebom",1.75,allow)
	ck(s.get("next") == &"hangyeol" and is_equal_approx(clock.deadline,3.75), "Saebom click starts its own fresh 2 seconds")
	ck(clock.accept(&"saebom",1.751,allow).is_empty() and clock.deadline == 3.75, "duplicate Saebom no refresh")
	ck(not clock.advance(1.751) and not clock.advance(1.751), "paused active clock can stay unchanged")
	var h := clock.accept(&"hangyeol",3.50,allow)
	ck(h.get("finished",false) and not clock.active() and reserved == [&"uram",&"saebom",&"hangyeol"], "manual Han accepted during Saebom window, independently of total time")

	clock.reset()
	reserved.clear()
	u=clock.accept(&"uram",8.0,allow)
	ck(not clock.confirm_guard(10.0,u.generation) and not clock.active(), "guard exactly at expired boundary never unlocks")
	ck(clock.accept(&"saebom",10.2,allow).is_empty() and reserved.size() == 1, "late Saebom cannot activate or reserve")
	clock.reset()
	reserved.clear()
	u=clock.accept(&"uram",1.0,allow)
	ck(clock.advance(3.001) and reserved.size() == 1, "no successful guard expires without auto action")
	clock.reset()
	reserved.clear()
	var rules := HuntRules.new()
	rules.charges[HuntRules.SAEBOM] = 3.
	u=clock.accept(&"uram",20.0,allow)
	ck(clock.confirm_guard(20.4,u.generation), "legitimate guard for independent buff check")
	var real_rally := func(_hero: StringName) -> bool: return rules.start_rally()
	s=clock.accept(&"saebom",20.85,real_rally)
	ck(s.get("next") == &"hangyeol" and rules.rally_cast_pending, "real ordinary Saebom cast reserves independently")
	var team: Array[Vector2] = [Vector2(25.,0),Vector2(300.,0),Vector2.ZERO]
	ck(rules.apply_rally(team) and rules.rally_remaining[HuntRules.SAEBOM] == 5., "buff starts on actual rally application")
	rules.advance_rally_clock(2.1)
	ck(clock.advance(22.96) and is_equal_approx(rules.rally_remaining[HuntRules.SAEBOM],2.9) and rules.rally_remaining[1] == 0., "expiry does not cancel applied five-second buff; outside ally unaffected")
	ck(clock.accept(&"hangyeol",22.97,allow).is_empty() and reserved.size() == 1, "expired Han never auto-finishes or reserves")
	rules.advance_rally_clock(3.0)
	ck(rules.rally_remaining[HuntRules.SAEBOM] == 0., "buff independently expires normally")
	clock.reset()
	ck(not clock.confirm_guard(.2,u.generation) and clock.expected() == &"uram", "retry invalidates previous arm and resets")
	print("Production chain intake/actual rally: ", checks," checks, ",failures," failures")
	quit(int(failures>0))
