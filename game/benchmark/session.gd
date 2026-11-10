extends Node
## Benchmark-only boot contract. No network packs or player data participate.
const BASE_COMMIT := "98fd2d8f71f96783e44446d5c9d997b440fc6d07"
const MODES := ["T0", "T1", "T2", "T3"]
var request: Dictionary = {}
var active := false

static func validate(value: Variant) -> Dictionary:
	if not value is Dictionary or value.get("schema_version") != 1: return {}
	if value.get("mode") not in MODES: return {}
	var id := str(value.get("run_id", ""))
	var pattern := RegEx.new()
	pattern.compile("^[A-Za-z0-9_-]{1,80}$")
	if pattern.search(id) == null: return {}
	for key in ["warmup_seconds", "sample_seconds"]:
		if not (value.get(key) is float or value.get(key) is int): return {}
		var number := float(value[key])
		if not is_finite(number) or number < 0.1 or number > 600: return {}
	return value.duplicate(true)

func _ready() -> void:
	var file := "user://benchmark/request.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--benchmark-request="):
			file = argument.trim_prefix("--benchmark-request=")
	if not FileAccess.file_exists(file): return
	request = validate(JSON.parse_string(FileAccess.get_file_as_string(file)))
	if request.is_empty():
		push_error("ROX_BENCHMARK invalid request; benchmark not started")
		return
	if file == "user://benchmark/request.json":DirAccess.remove_absolute(file)
	active = true
	seed(289)
	ProjectSettings.set_setting("roxhistory/trial/id", request.mode)
	ProjectSettings.set_setting("roxhistory/trial/base_commit", BASE_COMMIT)
	ProjectSettings.set_setting("roxhistory/benchmark/request", request)
static func build_commit() -> String:
	return FileAccess.get_file_as_string("res://benchmark/build-commit.txt").strip_edges()
