extends Node

signal catalog_ready
signal message(value:String)
signal selection_saved
const ROOT:="https://github.com/byungho-cho/roxhistory/releases/download/android-performance-trials/"
const IDS:=["T0","T1","T2","T3","T4","T5"]
const BASE:="8dbab7655bba5c535a95f26c308cbd784358af02"
const RUNTIME:="godot-4.5.1-android-pck-1"
var folder:String
var verify_payload:Callable
var request:HTTPRequest
var catalog:Dictionary={}
var envelope:=PackedByteArray()
var selected:=""
var target:=""
var queue:Array[Dictionary]=[]
var active_pack:Dictionary={}

func _ready()->void:
	DirAccess.make_dir_recursive_absolute(folder)
	DirAccess.remove_absolute(folder.path_join("trial.part"))
	var selected_path:=folder.path_join("selection.json")
	var state:Variant=JSON.parse_string(FileAccess.get_file_as_string(selected_path)) if FileAccess.file_exists(selected_path) else {}
	if state is Dictionary:
		envelope=Marshalls.base64_to_raw(str(state.get("catalog","")))
		catalog=validate_catalog(envelope)
		selected=str(state.get("id",""))
	if selected not in IDS:selected=""
	request=HTTPRequest.new()
	request.timeout=45
	add_child(request)
	request.request_completed.connect(completed)

func validate_catalog(bytes:PackedByteArray)->Dictionary:
	var data:Dictionary=verify_payload.call(bytes)
	if data.get("base_commit")!=BASE or data.get("runtime")!=RUNTIME or not data.get("packs") is Array:return {}
	if not data.get("version") is String or not data.get("baseline_id") is String or not data.get("baseline_commit") is String:return {}
	var pattern:=RegEx.new()
	pattern.compile("^[0-9]+\\.[0-9]+\\.[0-9]+$")
	if pattern.search(data.version)==null:return {}
	pattern.compile("^[0-9a-f]{40}$")
	if pattern.search(data.baseline_commit)==null:return {}
	pattern.compile("^[0-9a-f]{64}$")
	var ids:=[]
	for item in data.packs:
		if not item is Dictionary or item.get("id") not in IDS or item.id in ids:return {}
		if not item.get("sha256") is String or pattern.search(item.sha256)==null:return {}
		if not item.get("size") is float or item.size<=0 or item.size>600000000 or floorf(item.size)!=item.size:return {}
		if item.get("file")!="Roxhistory_%s_%s.pck"%[item.id,data.version]:return {}
		ids.append(item.id)
	if "T0" not in ids:return {}
	var base_hash:String=record_from(data,"T0").sha256
	for id in ids:
		if id!="T0" and record_from(data,id).get("requires")!=base_hash:return {}
	return data

func record_from(data:Dictionary,id:String)->Dictionary:
	for entry in data.get("packs",[]):
		if entry.id==id:return entry
	return {}

func record(id:String)->Dictionary:
	return record_from(catalog,id)

func label()->String:
	if selected.is_empty():return "일반판"
	return "%s · %s"%[selected,catalog.get("baseline_id","공통 기준 미확인")]

func refresh()->void:
	request.cancel_request()
	target=""
	active_pack={}
	queue.clear()
	request.download_file=""
	request.body_size_limit=16384
	if request.request(ROOT+"catalog.json")!=OK:fail()

func select(id:String)->void:
	request.cancel_request()
	target=id
	active_pack={}
	queue.clear()
	if id.is_empty():
		finish_selection()
		return
	if record(id).is_empty():fail();return
	queue.append(record("T0"))
	if id!="T0":queue.append(record(id))
	next_pack()

func completed(result:int,code:int,_headers:PackedStringArray,body:PackedByteArray)->void:
	if result!=HTTPRequest.RESULT_SUCCESS or code!=200:fail();return
	if active_pack.is_empty():
		var data:=validate_catalog(body)
		if data.is_empty():fail();return
		catalog=data
		envelope=body
		catalog_ready.emit()
		return
	var partial:=folder.path_join("trial.part")
	if not valid_file(partial,active_pack) or DirAccess.rename_absolute(partial,pack_path(active_pack))!=OK:fail();return
	next_pack()

func next_pack()->void:
	while not queue.is_empty():
		active_pack=queue.pop_front()
		if valid_file(pack_path(active_pack),active_pack):continue
		request.body_size_limit=int(active_pack.size)
		request.download_file=folder.path_join("trial.part")
		message.emit(active_pack.id+" 다운로드 중…")
		if request.request(ROOT+active_pack.file)!=OK:fail()
		return
	finish_selection()

func finish_selection()->void:
	var state:=JSON.stringify({"id":target,"catalog":Marshalls.raw_to_base64(envelope)})
	if not write_atomic("selection.json",state.to_utf8_buffer()):
		fail()
		return
	selection_saved.emit()

func write_atomic(name:String,bytes:PackedByteArray)->bool:
	var path:=folder.path_join(name)
	var f:=FileAccess.open(path+".part",FileAccess.WRITE)
	if f==null:return false
	f.store_buffer(bytes)
	var ok:=f.get_error()==OK
	f.close()
	return ok and DirAccess.rename_absolute(path+".part",path)==OK

func pack_path(entry:Dictionary)->String:
	return folder.path_join(entry.sha256+".pck")

func valid_file(path:String,entry:Dictionary)->bool:
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null:return false
	var size:=file.get_length()
	file.close()
	return size==int(entry.size) and FileAccess.get_sha256(path)==entry.sha256

func mount_selected()->bool:
	if selected.is_empty():return false
	var base:=record("T0")
	if base.is_empty() or not valid_file(pack_path(base),base) or not ProjectSettings.load_resource_pack(pack_path(base),true):return false
	var applied:="T0"
	if selected!="T0":
		var overlay:=record(selected)
		if not overlay.is_empty() and valid_file(pack_path(overlay),overlay) and ProjectSettings.load_resource_pack(pack_path(overlay),true):
			applied=selected
	ProjectSettings.set_setting("application/config/version",catalog.version)
	ProjectSettings.set_setting("roxhistory/trial/id",applied)
	ProjectSettings.set_setting("roxhistory/trial/base_commit",catalog.baseline_commit)
	return true

func cancel()->void:
	request.cancel_request()
	queue.clear()
	active_pack={}
	DirAccess.remove_absolute(folder.path_join("trial.part"))

func fail()->void:
	DirAccess.remove_absolute(folder.path_join("trial.part"))
	message.emit("시험판을 준비하지 못했습니다. 이전 선택이 유지됩니다.")
