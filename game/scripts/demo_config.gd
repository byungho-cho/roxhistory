class_name DemoConfig
extends RefCounted

static var data: Dictionary = {}
const HOME_SITES := [Vector2(1145,625),Vector2(1390,810),Vector2(1060,1030)]
# HOME_SITES remains the immutable mapping for old saves without a site field.
const BUILD_SITES := [Vector2(1170,760),Vector2(1510,830),Vector2(1080,1150),Vector2(500,640),Vector2(350,1240),Vector2(1780,1230)]
const HOME_GOAL := 3

static func get_data() -> Dictionary:
	if data.is_empty():
		data = JSON.parse_string(FileAccess.get_file_as_string("res://data/demo.json"))
	return data

static func point(value: Array) -> Vector2:
	return Vector2(float(value[0]),float(value[1]))

static func fresh() -> Dictionary:
	var c := get_data()
	return {"schema":1,"region":"amsa","position":c.spawn.duplicate(),"wood":0,"stone":0,
		"depleted":{},"built":false,"reward_claimed":false,"tokens":0,"intro_seen":false}
