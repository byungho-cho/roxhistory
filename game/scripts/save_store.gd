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
	if not s is Dictionary:return false
	for k in ["schema","region","position","wood","stone","depleted","built","reward_claimed","tokens","intro_seen"]:
		if not s.has(k):return false
	if s.schema!=1 or s.region!="amsa" or not BuildingRules.valid_position(s.position):return false
	for k in ["wood","stone","tokens"]:
		if not BuildingRules.valid_number(s[k],0,BuildingRules.MAX_RESOURCE,true):return false
	for k in ["built","reward_claimed","intro_seen","family_joined","family_unlocked","hq_can_be_absent","debug_fast_build","debug_show_boundary","debug_unlimited_builders","debug_unlimited_buildings"]:
		if s.has(k) and not s[k] is bool:return false
	if not s.depleted is Dictionary or (s.reward_claimed and not s.built):return false
	if s.has("hut_style") and not BuildingRules.valid_number(s.hut_style,0,2,true):return false
	var hq:Variant=s.get("chief_level",0 if s.get("hq_can_be_absent",false) else 1)
	if not BuildingRules.valid_number(hq,0 if s.get("hq_can_be_absent",false) else 1,4,true):return false
	if s.has("chief_position") and not BuildingRules.valid_position(s.chief_position):return false
	if s.has("chief_upgrade"):
		var job:Variant=s.chief_upgrade
		if not BuildingRules.valid_clock(job):return false
		if not BuildingRules.valid_number(job.get("from"),1,3,true) or not BuildingRules.valid_number(job.get("to"),2,4,true):return false
		if job.from!=hq or job.to!=hq+1:return false
	for serial in ["outpost_serial","home_serial","construction_serial"]:
		if s.has(serial) and not BuildingRules.valid_number(s[serial],0,BuildingRules.MAX_RESOURCE,true):return false
	if not _valid_buildings(s,int(hq)):return false
	if not ResidentAdmission.valid_saved_population(s):return false
	if not ResidentJobs.valid_saved_jobs(s):return false
	if not VillageActivityState.valid(s):return false
	if s.has("resource_seed") and not BuildingRules.valid_number(s.resource_seed,1,2147483646,true):return false
	var allowed := {}
	for n in DemoConfig.get_data().nodes:
		allowed[n.id] = n.charges if int(s.get("resource_revision",0))>=35 else (5 if n.kind=="wood" else 4)
	for k in s.depleted:
		if not allowed.has(k) or not BuildingRules.valid_number(s.depleted[k],0,allowed[k],true):return false
	for key in ["node_positions","respawn_due"]:
		if not s.get(key,{}) is Dictionary:return false
		for id in s.get(key,{}):
			if not allowed.has(id):return false
			var value:Variant=s[key][id]
			if key=="node_positions":
				if not value is Array or value.size()!=2:return false
				for coordinate in value:
					if not BuildingRules.valid_number(coordinate,-BuildingRules.MAX_RESOURCE,BuildingRules.MAX_RESOURCE):return false
				if not VillageBounds.RESOURCE_RELOCATION_RECT.has_point(DemoConfig.point(value)):return false
			elif not BuildingRules.valid_number(value):return false
	return true

func _valid_buildings(s:Dictionary,hq:int)->bool:
	var sites:Array=[]
	var occupied_uids:Array=[]
	for collection in ["homes","outposts","facilities"]:
		var entries:Variant=s.get(collection,[])
		var limit:=DemoConfig.MAX_SAVED_RESIDENT_HOMES if collection=="homes" else BuildingRules.MAX_ENTRIES
		if not entries is Array or entries.size()>limit:return false
		var ids:Array=[];var legacy_slots:Array=[]
		for entry in entries:
			if not entry is Dictionary or not OwnedBuildingUpgrades.valid(entry):return false
			if entry.has("uid"):
				if not entry.uid is String or entry.uid.is_empty() or entry.uid in ids:return false
				ids.append(entry.uid);occupied_uids.append(entry.uid)
			elif collection!="homes":return false
			if entry.has("position") and not BuildingRules.valid_position(entry.position):return false
			if entry.has("site"):
				var id:Variant=entry.site
				if not BuildingRules.valid_number(id,0,DemoConfig.BUILD_SITES.size()-1,true) or int(id) in sites:return false
				sites.append(int(id))
			elif collection!="homes" and not entry.has("position"):return false
			if entry.has("cost"):
				if not BuildingRules.valid_cost(entry.cost):return false
			elif collection!="homes":return false
			if collection=="homes":
				if not entry.get("claimed") is bool or not BuildingRules.valid_number(entry.get("style"),0,2,true):return false
				if entry.has("legacy_slot"):
					var slot:Variant=entry.legacy_slot
					if not BuildingRules.valid_number(slot,0,DemoConfig.HOME_SITES.size()-1,true) or int(slot) in legacy_slots:return false
					legacy_slots.append(int(slot))
			elif collection=="facilities":
				if not entry.get("kind") is String or not entry.kind in BuildingRules.FACILITY_KINDS:return false
	if s.has("homes"):
		if s.built!=(s.homes.size()>0):return false
		if not s.homes.is_empty() and s.reward_claimed!=s.homes[0].claimed:return false
	var jobs:Variant=s.get("construction_jobs",[])
	if not jobs is Array or jobs.size()>BuildingRules.MAX_ENTRIES:return false
	var job_ids:Array=[]
	var chief_jobs:=0
	for job in jobs:
		if not BuildingRules.valid_clock(job):return false
		if not job.get("uid") is String or job.uid.is_empty() or job.uid in job_ids or job.uid in occupied_uids:return false
		job_ids.append(job.uid)
		if not job.get("kind") is String or not job.kind in BuildingRules.KINDS:return false
		if not BuildingRules.valid_number(job.get("from"),0,0,true) or not BuildingRules.valid_number(job.get("to"),1,1,true):return false
		if not BuildingRules.valid_position(job.get("position")):return false
		if job.has("site"):
			if not BuildingRules.valid_number(job.site,0,DemoConfig.BUILD_SITES.size()-1,true) or int(job.site) in sites:return false
			sites.append(int(job.site))
		if job.kind=="chief":
			chief_jobs+=1
			if hq!=0 or chief_jobs>1:return false
		if job.kind=="hut" and not BuildingRules.valid_number(job.get("style",1),0,2,true):return false
	return true

func erase_progress() -> bool:
	# Only this game's save files, including reset backups; never traverse folders.
	var absolute:=ProjectSettings.globalize_path(directory)
	var folder:=DirAccess.open(absolute)
	if folder==null:
		message="저장 폴더를 열지 못해 초기화를 중단했습니다."
		return false
	for name in folder.get_files():
		if name == "save.json" or name == "save.backup.json" or name == "save.pending.json" or (name.begins_with("save.") and name.ends_with(".json")):
			if DirAccess.remove_absolute(absolute.path_join(name)) != OK:
				message = "진행 초기화를 완료하지 못했습니다. 저장 공간을 확인해 주세요."
				return false
	blocked=false;recovered=false;message=""
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
	if reset and FileAccess.file_exists(backup):
		var archive := directory.path_join("save.backup.preserved.%s.json" % str(Time.get_ticks_usec()))
		if DirAccess.rename_absolute(backup,archive) != OK:
			message = "이전 여정의 백업을 보존하지 못했습니다."
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
