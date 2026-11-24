extends RefCounted
## Queues resources only. Never creates or moves scene nodes on a worker thread.
enum State { MISSING, PENDING, READY, FAILED }

var wanted: Dictionary = {}
var in_flight: Dictionary = {}
var held: Dictionary = {}
var failed: Dictionary = {}
var last_pump_frame := -1


func set_paths(paths: PackedStringArray) -> void:
	wanted.clear()
	for path in paths:
		wanted[path] = true
	for path in held.keys():
		if not wanted.has(path):held.erase(path)
	for path in failed.keys():
		if not wanted.has(path):failed.erase(path)
	for path in paths:request(path)


func state(path: String) -> State:
	if held.has(path):return State.READY
	if in_flight.has(path):return State.PENDING
	if failed.has(path):return State.FAILED
	return State.MISSING


func request(path: String, retry := false) -> bool:
	var current := state(path)
	if current == State.READY or current == State.PENDING:return true
	if current == State.FAILED and not retry:return false
	failed.erase(path)
	var ready := _cached(path)
	if _is_usable(path, ready):
		held[path] = ready
		return true
	if _exists(path) and _request(path) == OK:
		in_flight[path] = true
		return true
	failed[path] = true
	return false


func pump() -> void:
	if in_flight.is_empty():return
	var frame := Engine.get_process_frames()
	if last_pump_frame == frame:return
	last_pump_frame = frame
	# Drain old requests too. Only the current stage and shared resources stay pinned.
	for path: String in in_flight.keys():
		var status := _status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:continue
		var resource: Resource = null
		# A failed but finished token must also be collected before retrying.
		if status in [ResourceLoader.THREAD_LOAD_LOADED, ResourceLoader.THREAD_LOAD_FAILED]:
			resource = _collect(path)
		in_flight.erase(path)
		if not wanted.has(path):continue
		if status == ResourceLoader.THREAD_LOAD_LOADED and _is_usable(path,resource):
			held[path] = resource
		else:
			failed[path] = true


func _is_usable(path: String, resource: Resource) -> bool:
	if path.ends_with(".glb"):
		return resource is PackedScene and resource.can_instantiate()
	return resource != null


func _cached(path: String) -> Resource:
	return ResourceLoader.get_cached_ref(path)


func _exists(path: String) -> bool:
	return ResourceLoader.exists(path)


func _request(path: String) -> Error:
	return ResourceLoader.load_threaded_request(path)


func _status(path: String) -> int:
	return ResourceLoader.load_threaded_get_status(path)


func _collect(path: String) -> Resource:
	return ResourceLoader.load_threaded_get(path)
