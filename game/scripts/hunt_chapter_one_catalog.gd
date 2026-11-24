class_name HuntChapterOneCatalog
extends RefCounted
## Basic Chapter 1 encounter contract, not a combat implementation.
## C30000 / node 3610:379. Stage 1 keeps the later shipped v0.2.306 input policy.
## Stable keys decouple slot order from the old six-encounter save counter.

const CLEARS_KEY := "hunt_ch1_completed"
const RECRUITS_KEY := "hunt_ch1_recruited"
const ALLY_HAN := "han"
const ALLY_URAM := "uram"
const ALLY_SAEBOM := "saebom"
const FLOWER := "forest"
const STAG := "stag"
const JUVENILE := "juvenile"
const ADULT := "adult"
const SOLO := [ALLY_HAN]
const TEAM := [ALLY_HAN, ALLY_URAM, ALLY_SAEBOM]
const STAGE_KEYS := ["ch1-01", "ch1-02", "ch1-03", "ch1-04", "ch1-05", "ch1-06", "ch1-07", "ch1-08", "ch1-09", "ch1-10"]
# Keep all existing runtime stage ids. New 1-6..1-9 occupy the unused ids
# after both old chapters, not the old Chapter 2's ids 6..11.
const ROUTE_IDS := [0, 1, 2, 3, 4, 12, 13, 14, 15, 5]
const LEGACY_KEYS := ["ch1-01", "ch1-02", "ch1-03", "ch1-04", "ch1-05", "ch1-10"]
const ROWS := [
	{"party": SOLO, "prey": [FLOWER], "enemy_skill": "none", "lesson": "han_manual_2sp", "rank": "normal", "seconds": 50, "base_meat": 10, "first_clear_stars": 3},
	{"party": SOLO, "prey": [FLOWER, FLOWER], "enemy_skill": "none", "lesson": "han_ground_thrust", "rank": "normal", "seconds": 50, "base_meat": 20},
	{"party": [ALLY_HAN, ALLY_URAM], "opening_party": SOLO, "prey": [STAG, FLOWER], "enemy_skill": "none", "lesson": "uram_club", "rank": "normal", "seconds": 50, "base_meat": 30, "story_join": [ALLY_URAM]},
	{"party": TEAM, "opening_party": [ALLY_HAN, ALLY_URAM], "story_join": [ALLY_SAEBOM], "prey": [STAG, FLOWER, FLOWER], "enemy_skill": "none", "lesson": "saebom_sling", "rank": "normal", "seconds": 50, "base_meat": 40},
	{"party": TEAM, "prey": [JUVENILE], "enemy_skill": "juvenile_charge", "lesson": "uram_parry_only", "rank": "midboss", "seconds": 60, "base_meat": 30},
	{"party": TEAM, "prey": [JUVENILE, FLOWER], "enemy_skill": "juvenile_charge", "lesson": "first_parry_demo_then_chain", "rank": "normal", "seconds": 50, "base_meat": 40},
	{"party": TEAM, "prey": [JUVENILE, FLOWER, FLOWER], "enemy_skill": "juvenile_charge", "lesson": "parry_chain_practice", "rank": "normal", "seconds": 50, "base_meat": 50},
	{"party": TEAM, "prey": [JUVENILE, STAG, FLOWER], "enemy_skill": "juvenile_charge", "lesson": "parry_chain_practice", "rank": "normal", "seconds": 50, "base_meat": 60},
	{"party": TEAM, "prey": [JUVENILE, STAG, STAG], "enemy_skill": "juvenile_charge", "lesson": "parry_chain_practice", "rank": "normal", "seconds": 50, "base_meat": 70},
	{"party": TEAM, "prey": [ADULT], "enemy_skill": "adult_successive_charge", "lesson": "boss_parry", "rank": "finalboss", "seconds": 90, "base_meat": 90},
]


static func encounter(number: int) -> Dictionary:
	if number < 1 or number > ROWS.size():
		return {}
	var row: Dictionary = ROWS[number - 1].duplicate(true)
	row.number = number
	row.key = STAGE_KEYS[number - 1]
	return row


static func legacy_display_number(old_stage_id: int) -> int:
	if old_stage_id < 0 or old_stage_id >= LEGACY_KEYS.size():
		return 0
	return STAGE_KEYS.find(LEGACY_KEYS[old_stage_id]) + 1


static func completion_view(old_cleared_count: int, persisted: Dictionary = {}) -> Dictionary:
	# Pure view over both formats. Do not rewrite hunt_cleared, which also owns Ch. 2.
	var completed := {}
	for key: String in STAGE_KEYS:
		if persisted.get(key, false) == true:
			completed[key] = true
	for i in range(clampi(old_cleared_count, 0, LEGACY_KEYS.size())):
		completed[LEGACY_KEYS[i]] = true
	return completed


static func is_unlocked(number: int, completed: Dictionary) -> bool:
	if number < 1 or number > STAGE_KEYS.size():
		return false
	if number == 1 or completed.get(STAGE_KEYS[number - 1], false) == true:
		return true
	return completed.get(STAGE_KEYS[number - 2], false) == true


## Story joiners become available for free replay only after the corresponding victory is saved.
static func replay_opening_party(completed: Dictionary, retained: Variant = []) -> Array:
	var recruited: Array = retained.duplicate() if retained is Array else []
	for i in range(ROWS.size()):
		if completed.get(STAGE_KEYS[i],false) == true:
			recruited.append_array(ROWS[i].get("story_join",[]))
	# Deployment/HUD slots are a roster prefix, and Saebom joins after Uram.
	var party := SOLO.duplicate()
	if ALLY_URAM in recruited:
		party.append(ALLY_URAM)
		if ALLY_SAEBOM in recruited:
			party.append(ALLY_SAEBOM)
	return party


## First attempts retain the authored encounter. Only a recorded clear
## changes these two tutorials into a normal hunt with the owned roster.
static func playable_encounter(number: int, completed: Dictionary, retained: Variant = []) -> Dictionary:
	var row:=encounter(number)
	if row.is_empty():return row
	row.first_visit=completed.get(row.key,false)!=true
	if number in [2,3] and not row.first_visit:
		var owned:=replay_opening_party(completed,retained)
		row.party=owned
		row.opening_party=owned.duplicate()
		row.erase("story_join")
		row.free_replay=true
	return row

static func next_number(completed: Dictionary) -> int:
	for number in range(1, STAGE_KEYS.size() + 1):
		if completed.get(STAGE_KEYS[number - 1], false) != true:
			return number
	return 0

static func route_id(number: int) -> int:
	return ROUTE_IDS[number - 1] if number >= 1 and number <= ROUTE_IDS.size() else -1


static func story_number(route: int) -> int:
	return ROUTE_IDS.find(route) + 1


static func after_first_win(number: int, completed: Dictionary) -> Dictionary:
	if not is_unlocked(number, completed):
		return {}
	var key: String = STAGE_KEYS[number - 1]
	if completed.get(key, false) == true:
		return {}
	var next := completed.duplicate(true)
	next[key] = true
	return next


static func legacy_prefix(completed: Dictionary) -> int:
	var done := 0
	for key: String in LEGACY_KEYS:
		if completed.get(key, false) != true:
			break
		done += 1
	return done
