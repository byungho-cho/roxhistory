extends SceneTree
const Rules := preload("res://scripts/deer_hunt_rules.gd")
var failures := 0
var checks := 0

func ck(value:bool,label:String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr(label)

func _initialize() -> void:
	var r := Rules.new()
	r.charges.assign([3.,3.,3.])
	r.attacker = 1
	r.pending_counter = true
	r.action_lock = .3
	r.orb_lock = .8
	r.auto_enabled = true
	r.reserved_skill = "strike"
	ck(r.reserve_manual(1,3) and r.orbs(1) == 0,"guard spends exactly three through the old shared lock")
	ck(not r.reserve_manual(1,3),"double tap can't spend again")
	ck(r.resolve_guard() and r.party_hp[1] == Rules.PARTY_HP[1] and not r.pending_counter,"shield consumes only the pending body contact")
	ck(not r.resolve_guard(),"same guarded contact cannot be processed twice")
	ck(r.reserve_manual(2,3) and r.orbs(2) == 0 and not r.start_rally_paid(),"accepted second tap paid independently; action not overwritten")
	ck(r.reserve_manual(0,3) and r.orbs(0) == 0,"accepted third tap may be held separately")
	ck(r.advance(.31,false,true).is_empty() and r.reserved_skill == "strike","reserved manual wins boundary over stock auto turn")
	ck(r.start_rally_paid() and not r.start_frontline_paid(0,8,.96),"cannot overwrite live Rally")
	var feet:Array[Vector2] = [Vector2.ZERO,Vector2(5,0),Vector2(10,0)]
	ck(r.apply_rally(feet) and r.rally_remaining[1] == 5.0,"applied Rally affects nearby living by real combat clock")
	r.advance(.53,false,true)
	ck(r.start_frontline_paid(0,8,.96) and r.pending_damage == 8,"third native skill preserves stock Han base")
	var before := r.deer_hp
	r.resolve_attack()
	ck(before-r.deer_hp == 9 and is_equal_approx(r.rally_remaining[0],5.),"paid strike qualifies for x1.20 without changing duration")
	r.party_hp[0] = 0
	r.charges[0] = 3.
	ck(not r.reserve_manual(0,3),"dead hero cannot be reserved")
	print("Ordinary manual intake: %d checks, %d failures" % [checks,failures])
	quit(int(failures>0))
