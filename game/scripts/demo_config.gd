class_name DemoConfig
extends RefCounted

static var data: Dictionary = {}

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
