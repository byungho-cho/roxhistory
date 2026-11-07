class_name DemoConfig
extends RefCounted

static var data: Dictionary = {}
const HOME_SITES := [Vector2(1145,625),Vector2(1390,810),Vector2(1060,1030)]
# HOME_SITES remains the immutable mapping for old saves without a site field.
const BUILD_SITES := [Vector2(1322,712),Vector2(874,712),Vector2(1098,824),Vector2(1322,936),Vector2(874,936),Vector2(1098,1048)]
const MAX_RESIDENT_HOMES := 3
const MAX_SAVED_RESIDENT_HOMES := 5 # Retain every previously valid owned home.
const CHIEF_POSITION := Vector2(1098,600)
const HOME_GOAL := 3

static func get_data() -> Dictionary:
	if data.is_empty():
		data = JSON.parse_string(FileAccess.get_file_as_string("res://data/demo.json"))
	return data

static func point(value: Array) -> Vector2:
	return Vector2(float(value[0]),float(value[1]))

static func fresh() -> Dictionary:
	var c := get_data()
	return {"schema":1,"terrain_revision":34,"resource_revision":35,"family_joined":false,"family_unlocked":false,"region":"amsa","position":c.spawn.duplicate(),"wood":99999,"stone":99999,"hq_can_be_absent":true,"chief_level":0,
		"debug_unlimited_buildings":false,"debug_fast_build":false,"debug_show_boundary":false,"debug_unlimited_builders":true,"construction_jobs":[],"facilities":[],"resident_count":0,"pending_family_count":0,"family_next_at":0.0,
		"depleted":{},"built":false,"reward_claimed":false,"tokens":99999,"intro_seen":false}
