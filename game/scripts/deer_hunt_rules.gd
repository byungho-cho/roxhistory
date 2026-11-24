extends RefCounted

signal hp_lost(victim: int, before: int, after: int)
const PREY_VICTIM := 3
## Provisional encounter timing. The shared lock applies only to orb skills.
const MAX_HP := 100
const COUNTER_DAMAGE := 2
const MAX_ORBS := 3
const PARTY_HP := [34, 33, 33]
const CHARGE_SECONDS := [1.5, 1.8, 2.0]
const PARTY_SKILLS := ["thrust", "strike", "team"]
const BASIC_INTERVAL := 10.0 / 14.0
const POSE_SECONDS := 0.52
const SAEBOM := 2
const URAM_SHIELD_COUNTER_DAMAGE := 18
const URAM_SHIELD_COUNTER_STUN := 1.15
var prey_stun_remaining := 0.0
const RALLY_COST := 3
const RALLY_SECONDS := 5.0
const RALLY_RADIUS := 190.0
const RallyCloud := preload("res://scripts/saebom_rally_cloud.gd")
const AUTO_INTERVAL := 2.6
const SKILLS := {
	"thrust": {"label": "찌르기", "cost": 1, "damage": 8},
	"strike": {"label": "강타", "cost": 1, "damage": 31},
	"team": {"label": "협동", "cost": 2, "damage": 58},
}

var skills_enabled:=true
var first_hunt := false
var manual_only := false
var han_ordinary_damage := RallyCloud.ORDINARY_BASE

var charges: Array[float] = [0.0, 0.0, 0.0]
var party_hp: Array[int] = [34, 33, 33]
var party_max_hp: Array[int] = [34, 33, 33]
var party_growth: Array[float] = [1.0, 1.0, 1.0]
var hunter_hp: int:
	get: return party_hp[0]+party_hp[1]+party_hp[2]
var next_target := 0
var deer_max_hp := MAX_HP
var deer_hp := MAX_HP
var pending_damage := 0
var pending_counter := false
var rally_cast_pending := false
var rally_cloud_fifths := 0
var rally_cloud_growth_remainder := 0.0
var rally_remaining: Array[float] = [0.0, 0.0, 0.0]
# Integer fifths, independent per recipient. A sequence of five 1-point
# attacks really gains one damage instead of each attack rounding back to 1.
# Only boosted attacks can consume the earned fraction, even after another cast.
var rally_fifths: Array[int] = [0, 0, 0]
# Preserve the old rally rounding sequence outside a confirmed finisher.
var han_combo_hundredths := 0
var next_attacker := 0
var attacker := 0
var outcome := ""
var exchange_clock := 0.0
var hunter_turn := true
var basic_lock := 0.0
var orb_lock := 0.0
var action_lock := 0.0
var auto_enabled := false
var reserved_skill := ""
var rng := RandomNumberGenerator.new()

func apply_growth(index: int, multiplier: float) -> void:
	party_growth[index] = multiplier
	party_max_hp[index] = roundi(PARTY_HP[index] * multiplier)
	party_hp[index] = party_max_hp[index]

func enable_motion_trial() -> void:
	deer_max_hp = MAX_HP * 10
	deer_hp = deer_max_hp

func living_from(start: int) -> int:
	for offset in party_hp.size():
		var index := (start+offset)%party_hp.size()
		if party_hp[index]>0:return index
	return -1

func queue_attack(damage: int, index: int) -> void:
	attacker = index
	pending_damage = damage

func resolve_attack(ordered_han_finisher := false, contact_into_frame := 0.0) -> void:
	var damage := pending_damage
	pending_damage = 0
	if damage > 0:
		if party_growth[attacker] > 1.0:
			var final_damage := damage * party_growth[attacker]
			var ordered_han := ordered_han_finisher and attacker == 0
			var remaining := maxf(0.0, contact_into_frame) if ordered_han else 0.0
			if party_hp[attacker] > 0 and rally_remaining[attacker] > remaining:
				final_damage *= 1.32 if ordered_han else 1.20
			damage = roundi(final_damage)
		elif ordered_han_finisher and attacker == 0:
			if party_hp[0] > 0 and rally_remaining[0] > maxf(0.0,contact_into_frame):
				var scaled := damage * 132 + han_combo_hundredths
				han_combo_hundredths = scaled % 100
				damage = floori(float(scaled) / 100.0)
		else:
			damage = _rally_damage(damage, attacker)
		damage_deer(damage)
	if pending_counter:
		pending_counter = false
		_resolve_prey_damage(attacker)


# Stage 1-1 prey owns an independent action, not the shared pending Han action.
func resolve_independent_prey_basic(victim:int) -> void:
	if outcome.is_empty() and deer_hp>0 and victim in range(party_hp.size()) and party_hp[victim]>0:
		_resolve_prey_damage(victim)


func _resolve_prey_damage(victim:int) -> void:
	var before := party_hp[victim]
	party_hp[victim] = maxi(0, before - COUNTER_DAMAGE)
	if party_hp[victim] < before:hp_lost.emit(victim,before,party_hp[victim])
	if party_hp[victim]==0:
		charges[victim]=0.0
		rally_remaining[victim]=0.0
		rally_fifths[victim]=0
		if victim==0:han_combo_hundredths=0
		if auto_enabled:reserved_skill=next_auto_skill()
	if hunter_hp == 0:
		outcome = "loss"
		set_auto(false)

func orbs(index: int) -> int:
	return mini(MAX_ORBS,floori(charges[index]+0.000001))

func set_auto(enabled: bool) -> void:
	auto_enabled = enabled and outcome.is_empty()
	reserved_skill = next_auto_skill() if auto_enabled else ""

func next_auto_skill() -> String:
	if manual_only or not skills_enabled:return ""
	var options: Array[String] = []
	if party_hp[1]>0:options.append("strike")
	if party_hp[2]>0 and (party_hp[0]>0 or party_hp[1]>0):options.append("team")
	if options.is_empty() and party_hp[0]>0:return "thrust"
	return "" if options.is_empty() else options[rng.randi_range(0,options.size()-1)]

func can_use(skill: String) -> bool:
	if not skills_enabled:return false
	if not SKILLS.has(skill) or not outcome.is_empty() or action_lock > 0 or pending_damage > 0 or pending_counter or rally_cast_pending:
		return false
	var index := PARTY_SKILLS.find(skill)
	if party_hp[index]<=0 or orbs(index)<SKILLS[skill].cost:return false
	if skill=="team" and party_hp[0]<=0 and party_hp[1]<=0:return false
	return basic_lock<=0 if skill=="thrust" else orb_lock<=0

func use_skill(skill: String) -> bool:
	if not can_use(skill):
		return false
	var index := PARTY_SKILLS.find(skill)
	action_lock = POSE_SECONDS
	charges[index] = maxf(0.0,charges[index]-SKILLS[skill].cost)
	if skill == "thrust":
		basic_lock = BASIC_INTERVAL
	else:
		orb_lock = 1.0
	queue_attack(SKILLS[skill].damage,index)
	return true

# Manual chain input owns its own valid tap/SP reservation; ordinary scheduling stays separate.
func can_reserve_manual(index: int, cost: int) -> bool:
	return skills_enabled and outcome.is_empty() and index >= 0 and index < party_hp.size() and party_hp[index] > 0 and cost > 0 and orbs(index) >= cost


func reserve_manual(index: int, cost: int) -> bool:
	if not can_reserve_manual(index,cost):
		return false
	charges[index] = maxf(0.0, charges[index] - cost)
	return true


func can_execute_manual() -> bool:
	return skills_enabled and outcome.is_empty() and action_lock <= 0.0 and pending_damage == 0 and not pending_counter and not rally_cast_pending


func can_use_frontline_skill(index: int, cost: int) -> bool:
	return can_execute_manual() and can_reserve_manual(index,cost) and (basic_lock <= 0.0 if index == 0 else orb_lock <= 0.0)


func start_frontline_paid(index: int, damage: int, lock_seconds: float) -> bool:
	if not can_execute_manual() or index < 0 or index >= party_hp.size() or party_hp[index] <= 0 or damage <= 0:
		return false
	action_lock = maxf(POSE_SECONDS,lock_seconds)
	if index == 0:
		basic_lock = BASIC_INTERVAL
	else:
		orb_lock = 1.0
	queue_attack(damage,index)
	return true


func start_rally_paid() -> bool:
	if not can_execute_manual() or party_hp[SAEBOM] <= 0:
		return false
	action_lock = POSE_SECONDS
	orb_lock = 1.0
	rally_cast_pending = true
	return true


func resolve_guard() -> bool:
	if not pending_counter or not outcome.is_empty():
		return false
	pending_counter = false
	return true


func resolve_uram_shield_counter(ordinary:bool) -> int:
	if deer_hp <= 0 or not outcome.is_empty() or party_hp[1] <= 0 or pending_counter:
		return 0
	if ordinary:
		if attacker != 1 or pending_damage != URAM_SHIELD_COUNTER_DAMAGE:
			return 0
		pending_damage = 0
	var before := deer_hp
	damage_deer(roundi(URAM_SHIELD_COUNTER_DAMAGE * party_growth[1]))
	if deer_hp > 0:
		prey_stun_remaining = URAM_SHIELD_COUNTER_STUN
	return before-deer_hp


func can_start_rally() -> bool:
	return (
		skills_enabled and outcome.is_empty() and party_hp[SAEBOM] > 0 and orbs(SAEBOM) >= RALLY_COST
		and action_lock <= 0.0 and orb_lock <= 0.0
		and pending_damage == 0 and not pending_counter and not rally_cast_pending
	)


func start_rally() -> bool:
	if not can_start_rally():
		return false
	charges[SAEBOM] = maxf(0.0, charges[SAEBOM] - RALLY_COST)
	action_lock = POSE_SECONDS
	orb_lock = 1.0
	rally_cast_pending = true
	return true


func apply_rally(positions: Array[Vector2]) -> bool:
	if not rally_cast_pending:
		return false
	rally_cast_pending = false
	if not outcome.is_empty() or party_hp[SAEBOM] <= 0 or positions.size() != party_hp.size():
		return false
	var caster := positions[SAEBOM]
	for i in party_hp.size():
		if party_hp[i] <= 0 or caster.distance_squared_to(positions[i]) > RALLY_RADIUS * RALLY_RADIUS:
			continue
		rally_remaining[i] = RALLY_SECONDS
	# This encounter uses one-point unbuffed basics, including Saebom.
	# Preserve exactly one fifth of that attack without touching the buff remainder.
	if deer_hp > 0:
		var damage: int
		if party_growth[SAEBOM] > 1.0:
			var grown := RallyCloud.accrue_grown(rally_cloud_growth_remainder, RallyCloud.ORDINARY_BASE, party_growth[SAEBOM])
			rally_cloud_growth_remainder = grown.y
			damage = int(grown.x)
		else:
			var wind := RallyCloud.accrue(rally_cloud_fifths, RallyCloud.ORDINARY_BASE)
			rally_cloud_fifths = wind.y
			damage = wind.x
		if damage > 0: damage_deer(damage)
	return true


func _rally_damage(damage: int, index: int) -> int:
	if party_hp[index] <= 0 or rally_remaining[index] <= 0.0:
		return damage
	var fifths := damage + rally_fifths[index]
	rally_fifths[index] = fifths % 5
	return damage + floori(float(fifths) / 5.0)



func damage_deer(amount: int) -> void:
	var before := deer_hp
	deer_hp = maxi(0, before - amount)
	if deer_hp < before:hp_lost.emit(PREY_VICTIM,before,deer_hp)
	if deer_hp == 0:
		outcome = "win"
		set_auto(false)

func advance_rally_clock(delta: float) -> void:
	for index in party_hp.size():
		if rally_remaining[index] > 0.0:
			rally_remaining[index] = maxf(0.0, rally_remaining[index] - delta)
			if rally_remaining[index] <= .000001:
				rally_remaining[index] = 0.0


func advance(delta: float, tick_rally := true, prefer_manual := false) -> String:
	if not outcome.is_empty():
		return ""
	if tick_rally:
		advance_rally_clock(delta)
	for index in party_hp.size():
		if skills_enabled and party_hp[index]>0:charges[index]=minf(MAX_ORBS,charges[index]+delta/CHARGE_SECONDS[index])
	prey_stun_remaining = maxf(0.0, prey_stun_remaining - delta)
	action_lock = maxf(0.0, action_lock - delta)
	basic_lock = maxf(0.0, basic_lock - delta)
	orb_lock = maxf(0.0, orb_lock - delta)
	exchange_clock = minf(AUTO_INTERVAL, exchange_clock + delta)
	if prefer_manual:
		return ""
	var queued := reserved_skill
	if auto_enabled and use_skill(queued):
		if auto_enabled:
			reserved_skill = next_auto_skill()
		return queued
	if exchange_clock < AUTO_INTERVAL or action_lock > 0 or pending_damage > 0 or pending_counter or rally_cast_pending:
		return ""
	# Wait out a stun before scheduling a fresh enemy turn; never clear a pending hit.
	if not hunter_turn and prey_stun_remaining > 0.0:
		return ""
	exchange_clock = 0.0
	action_lock = POSE_SECONDS
	hunter_turn = not hunter_turn
	if not hunter_turn:
		var index := living_from(next_attacker)
		queue_attack(han_ordinary_damage if index==0 else RallyCloud.ORDINARY_BASE,index)
		next_attacker = (index+1)%party_hp.size()
		return "auto_thrust"
	attacker = living_from(next_target)
	next_target = (attacker+1)%party_hp.size()
	pending_counter = true
	return "counter"
