class_name SaveStore
extends RefCounted

var directory := "user://"
var blocked := false
var message := ""
var recovered := false

func _init(folder: String = "user://") -> void:
	directory = folder
	DirAccess.make_dir_recursive_absolute(directory)

func valid(s: Variant) -> bool:
	if not s is Dictionary:
		return false
	for k in ["schema","region","position","wood","stone","depleted","built","reward_claimed","tokens","intro_seen"]:
		if not s.has(k):
			return false
	if s.schema != 1 or s.region != "amsa" or not s.position is Array or s.position.size() != 2:
		return false
	for n in s.position:
		if not (n is int or n is float) or not is_finite(float(n)):
			return false
	var p := DemoConfig.point(s.position)
	if p.x < 20 or p.x > 2380 or p.y < 20 or p.y > 1330:
		return false
	for k in ["wood","stone","tokens"]:
		if not (s[k] is int or s[k] is float) or s[k] < 0 or s[k] != int(s[k]) or s[k] > 10000:
			return false
	for k in ["built","reward_claimed","intro_seen"]:
		if not s[k] is bool:
			return false
	if not s.depleted is Dictionary or (s.reward_claimed and not s.built):
		return false
	var allowed := {}
	for n in DemoConfig.get_data().nodes:
		allowed[n.id] = n.charges
	for k in s.depleted:
		if not allowed.has(k) or not (s.depleted[k] is int or s.depleted[k] is float):
			return false
		if s.depleted[k] < 0 or s.depleted[k] > allowed[k] or s.depleted[k] != int(s.depleted[k]):
			return false
	return true

func _read(file: String) -> Dictionary:
	if not FileAccess.file_exists(file):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(file)) != OK:
		return {}
	var envelope: Variant = parser.data
	if not envelope is Dictionary or not envelope.get("payload") is String:
		return {}
	if envelope.get("sha256","") != envelope.payload.sha256_text():
		return {}
	if parser.parse(envelope.payload) != OK:
		return {}
	var s: Variant = parser.data
	return s if valid(s) else {}

func load_game() -> Dictionary:
	blocked = false
	recovered = false
	message = ""
	var current := directory.path_join("save.json")
	var backup := directory.path_join("save.backup.json")
	var s := _read(current)
	if not s.is_empty():
		return s
	s = _read(backup)
	if not s.is_empty():
		recovered = true
		message = "저장 파일을 읽지 못해 직전 백업을 복원했습니다."
		return s
	if FileAccess.file_exists(current) or FileAccess.file_exists(backup):
		blocked = true
		message = "저장 파일을 읽을 수 없습니다. 원본을 보존했습니다. 새 게임으로 초기화하려면 확인해 주세요."
	return {}

func save_game(s: Dictionary, reset: bool = false) -> bool:
	message = ""
	if (blocked and not reset) or not valid(s):
		message = "저장할 수 없습니다. 기존 저장 파일은 보존됩니다."
		return false
	var current := directory.path_join("save.json")
	var temp := directory.path_join("save.pending.json")
	var backup := directory.path_join("save.backup.json")
	var payload := JSON.stringify(s)
	var file := FileAccess.open(temp,FileAccess.WRITE)
	if file == null:
		message = "저장 공간을 확인해 주세요. 진행을 저장하지 못했습니다."
		return false
	file.store_string(JSON.stringify({"payload":payload,"sha256":payload.sha256_text()}))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or _read(temp).is_empty():
		message = "저장 검증에 실패했습니다. 기존 저장 파일은 보존됩니다."
		return false
	if FileAccess.file_exists(current):
		if reset or _read(current).is_empty():
			var archive := directory.path_join("save.preserved.%s.json" % str(Time.get_ticks_usec()))
			if DirAccess.rename_absolute(current,archive) != OK:
				message = "기존 저장 파일을 보존하지 못했습니다."
				return false
		else:
			if FileAccess.file_exists(backup) and DirAccess.remove_absolute(backup) != OK:
				message = "저장 백업을 갱신하지 못했습니다."
				return false
			if DirAccess.rename_absolute(current,backup) != OK:
				message = "저장 백업을 만들지 못했습니다."
				return false
	if DirAccess.rename_absolute(temp,current) != OK:
		message = "저장 교체에 실패했습니다. 백업을 보존했습니다."
		return false
	blocked = false
	return true
