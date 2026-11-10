extends Control

const BASE_VERSION := "0.1.85"
const BASE_COMMIT := "8dbab7655bba5c535a95f26c308cbd784358af02"
const RUNTIME := "godot-4.5.1-android-pck-1"
const RELEASE_ROOT := "https://github.com/byungho-cho/roxhistory/releases/download/android-patches/"
const GAME_SCENE := "res://scenes/main.tscn"
const TRUST := preload("res://patch_test/patch_key.gd")

var cache := "user://rox-patches/"
@onready var index := cache + "current.json"
const TRIAL_LOADER:=preload("res://patch_test/trial_loader.gd")
var trials:TRIAL_LOADER
var shade:ColorRect
var popup:CenterContainer
var update_rows:VBoxContainer
var trial_rows:VBoxContainer
var trial_status:Label
var trial_buttons:Dictionary={}
var trial_close:Button
var trial_restart:Button
var trial_regular:Button
var request: HTTPRequest
var status: Label
var update_button: Button
var progress_bar: ProgressBar
var downloading := false
var previous_mouse_emulation := false
var cached := {}
var candidate := {}
var envelope := PackedByteArray()
func _ready() -> void:
	previous_mouse_emulation = Input.emulate_mouse_from_touch
	Input.emulate_mouse_from_touch = true
	DirAccess.make_dir_recursive_absolute(cache)
	discard(cache + "incoming.part")
	discard(index + ".part")
	cached = verified_manifest(FileAccess.get_file_as_bytes(index)) if FileAccess.file_exists(index) else {}
	if not cached.is_empty() and not valid_pack(pack_path(cached),cached):cached = {}
	build_title_backdrop()
	shade = ColorRect.new()
	shade.color = Color(0.08, 0.06, 0.03, 0.55)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup = CenterContainer.new()
	add_child(popup)
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("34261b")
	style.border_color = Color("d4a45f")
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	popup.add_child(panel)
	update_rows = VBoxContainer.new()
	var rows:=update_rows
	rows.custom_minimum_size.x = 360
	rows.add_theme_constant_override("separation", 14)
	panel.add_child(rows)
	status = Label.new()
	status.add_theme_font_override("font", load("res://assets/fonts/BlackHanSans-Regular.ttf"))
	status.add_theme_font_size_override("font_size", 24)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.text = "설치된 게임 버전  " + cached.get("version",BASE_VERSION)
	rows.add_child(status)
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size.y = 24
	progress_bar.hide()
	rows.add_child(progress_bar)
	update_button = action(rows, "업데이트 받기", download_patch)
	action(rows, "닫기", close_popup)
	request = HTTPRequest.new()
	request.timeout = 30.0
	request.body_size_limit = 8192
	add_child(request)
	request.request_completed.connect(request_completed)
	ProjectSettings.set_setting("roxhistory/native/diagnostic_zip",true)
	trials=TRIAL_LOADER.new()
	trials.folder=cache.path_join("trials")
	trials.verify_payload=verify_payload
	add_child(trials)
	trials.catalog_ready.connect(refresh_trial_buttons)
	trials.message.connect(func(value:String):trial_status.text=value)
	trials.selection_saved.connect(show_restart)
	build_trial_panel(panel)
	build_title_controls()
	shade.hide()
	popup.hide()
	if trials.selected.is_empty():check_for_patch.call_deferred()

func build_title_controls()->void:
	var dock:=CenterContainer.new()
	add_child(dock)
	move_child(dock,1)
	dock.set_anchor_and_offset(SIDE_RIGHT,1,0)
	dock.set_anchor_and_offset(SIDE_BOTTOM,1,0)
	dock.set_anchor_and_offset(SIDE_TOP,.72,0)
	var rows:=VBoxContainer.new()
	dock.add_child(rows)
	action(rows,"게임 시작 · "+trials.label(),play_current)
	var links:=HBoxContainer.new()
	rows.add_child(links)
	action(links,"◈ 성능 시험판",show_trials)
	action(links,"업데이트 확인",check_for_patch)

func build_trial_panel(panel:PanelContainer)->void:
	trial_rows=VBoxContainer.new()
	trial_rows.custom_minimum_size.x=360
	trial_rows.add_theme_constant_override("separation",12)
	panel.add_child(trial_rows)
	trial_status=Label.new()
	trial_status.add_theme_font_override("font",status.get_theme_font("font"))
	trial_status.add_theme_font_size_override("font_size",20)
	trial_rows.add_child(trial_status)
	var reserved:=Label.new()
	reserved.add_theme_font_override("font",status.get_theme_font("font"))
	reserved.text="T2~T5 · 준비 예정"
	trial_rows.add_child(reserved)
	var choices:=GridContainer.new()
	choices.columns=2
	trial_rows.add_child(choices)
	for id in TRIAL_LOADER.IDS:
		var caption:String=id
		if id=="T0":caption+=" · 공통 기준판"
		elif id=="T1":caption+=" · 남성 주민 2D"
		trial_buttons[id]=action(choices,caption,trials.select.bind(id))
	trial_regular=action(trial_rows,"일반판으로 돌아가기",trials.select.bind(""))
	trial_close=action(trial_rows,"닫기",close_popup)
	trial_restart=action(trial_rows,"게임 종료 · 다시 열어 적용",get_tree().quit)
	trial_rows.hide()

func show_trials()->void:
	request.cancel_request()
	update_rows.hide()
	trial_rows.show()
	shade.show()
	popup.show()
	trial_restart.hide()
	trial_close.show()
	trial_regular.show()
	refresh_trial_buttons()
	trials.refresh()

func refresh_trial_buttons()->void:
	trial_status.text="선택: "+trials.label()+"\n기준: "+str(trials.catalog.get("baseline_id","확인 중"))
	for id in trial_buttons:
		trial_buttons[id].visible=not trials.record(id).is_empty()

func show_restart()->void:
	trial_status.text="선택을 저장했습니다. 게임을 완전히 종료한 뒤 다시 열어 주세요."
	for button in trial_buttons.values():button.hide()
	trial_regular.hide()
	trial_close.hide()
	trial_restart.show()

func close_popup()->void:
	request.cancel_request()
	trials.cancel()
	downloading=false
	progress_bar.hide()
	popup.hide()
	shade.hide()

func build_title_backdrop() -> void:
	var background := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = preload("res://assets/ui/title-hanbando/hanbando-start-background-v1.png")
	atlas.region = Rect2(0, 0, atlas.atlas.get_width(), 720)
	background.texture = atlas
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var logo := TextureRect.new()
	logo.texture = preload("res://assets/ui/title-hanbando/hanbando-upheaval-logo-v1.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)
	logo.set_anchor_and_offset(SIDE_RIGHT, .75, 0)
	logo.set_anchor_and_offset(SIDE_LEFT, .25, 0)
	logo.set_anchor_and_offset(SIDE_BOTTOM, .25, 0)
	logo.set_anchor_and_offset(SIDE_TOP, .025, 0)

func _process(_delta: float) -> void:
	if downloading:
		progress_bar.value = minf(99.0, 100.0 * request.get_downloaded_bytes() / float(candidate.size))

func action(rows: Container, caption: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.add_theme_font_override("font",status.get_theme_font("font"))
	button.custom_minimum_size.y = 52
	button.pressed.connect(callback)
	rows.add_child(button)
	return button

func check_for_patch() -> void:
	update_button.disabled = true
	status.text = "업데이트 확인 중…"
	if not trials.selected.is_empty():return
	request.cancel_request()
	request.download_file = ""
	request.body_size_limit = 8192
	if request.request(RELEASE_ROOT + "latest.json") != OK:
		show_failure()

func request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		show_failure()
		return
	if not downloading:
		candidate = verified_manifest(body)
		if candidate.is_empty():
			show_failure()
			return
		if version_number(candidate.version) <= version_number(cached.get("version", BASE_VERSION)):
			status.text = "이미 최신 버전입니다"
			update_button.disabled = false
			return
		envelope = body
		status.text = "새 버전 "+candidate.version
		update_button.disabled=false
		trial_rows.hide()
		update_rows.show()
		shade.show()
		popup.show()
		return
	if not valid_pack(cache + "incoming.part",candidate):
		show_failure()
		return
	if DirAccess.rename_absolute(cache + "incoming.part",pack_path(candidate)) != OK:
		show_failure()
		return
	var old := cached
	cached = candidate
	if not mount_cached():
		cached = old
		show_failure()
		return
	if save_index() and not old.is_empty():discard(pack_path(old))
	open_game()

func download_patch()->void:
	if candidate.is_empty():return
	update_button.disabled=true
	downloading=true
	progress_bar.value=0
	progress_bar.show()
	status.text=candidate.version+" 다운로드 중…"
	request.download_file=cache+"incoming.part"
	request.body_size_limit=int(candidate.size)
	if request.request(RELEASE_ROOT+candidate.file)!=OK:show_failure()

func verify_payload(bytes:PackedByteArray) -> Dictionary:
	if bytes.is_empty():return {}
	var wrapper:Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not wrapper is Dictionary:return {}
	if not wrapper.get("payload") is String or not wrapper.get("signature") is String:return {}
	var payload := Marshalls.base64_to_raw(wrapper.payload)
	var signature := Marshalls.base64_to_raw(wrapper.signature)
	var key := CryptoKey.new()
	if key.load_from_string(TRUST.PATCH_PUBLIC_KEY,true) != OK:return {}
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(payload)
	if not Crypto.new().verify(HashingContext.HASH_SHA256,hash.finish(),signature,key):return {}
	var data:Variant = JSON.parse_string(payload.get_string_from_utf8())
	return data if data is Dictionary else {}

func verified_manifest(bytes:PackedByteArray) -> Dictionary:
	var data:=verify_payload(bytes)
	if data.get("base") != BASE_VERSION or data.get("base_commit") != BASE_COMMIT or data.get("runtime") != RUNTIME:return {}
	if not data.get("version") is String or not data.get("sha256") is String or not data.get("size") is float:return {}
	var regex := RegEx.new()
	regex.compile("^[0-9]{1,4}\\.[0-9]{1,4}\\.[0-9]{1,4}$")
	if regex.search(data.version)==null or version_number(data.version)<=version_number(BASE_VERSION):return {}
	regex.compile("^[0-9a-f]{64}$")
	if regex.search(data.sha256)==null or data.size<=0 or data.size>600000000 or data.size!=floorf(data.size):return {}
	if data.get("file") != "Roxhistory_%s_to_%s.pck"%[BASE_VERSION,data.version]:return {}
	return data

func version_number(version:String) -> int:
	var parts:=version.split(".")
	return int(parts[0])*100000000+int(parts[1])*10000+int(parts[2])

func pack_path(manifest:Dictionary) -> String:
	return cache + manifest.sha256 + ".pck"

func valid_pack(path:String,manifest:Dictionary) -> bool:
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null:return false
	var length:=file.get_length()
	file.close()
	return length==int(manifest.size) and FileAccess.get_sha256(path)==manifest.sha256

func save_index() -> bool:
	var file:=FileAccess.open(index + ".part",FileAccess.WRITE)
	if file==null:return false
	file.store_buffer(envelope)
	var ok:=file.get_error()==OK
	file.close()
	return ok and DirAccess.rename_absolute(index + ".part",index)==OK

func mount_cached() -> bool:
	if cached.is_empty() or not ProjectSettings.load_resource_pack(pack_path(cached),true):return false
	ProjectSettings.set_setting("application/config/version",cached.version)
	ProjectSettings.set_setting("roxhistory/trial/base_commit",cached.get("commit",""))
	return true

func show_failure() -> void:
	downloading = false
	progress_bar.hide()
	discard(cache + "incoming.part")
	status.text = "업데이트 실패 · 현재 버전으로 실행할 수 있어요"
	update_button.disabled = false

func play_current() -> void:
	request.cancel_request()
	discard(cache+"incoming.part")
	if not trials.mount_selected():
		mount_cached()
		if not cached.is_empty():ProjectSettings.set_setting("roxhistory/trial/base_commit",cached.get("commit",""))
	ProjectSettings.set_setting("roxhistory/bootstrap/launch_start",true)
	open_game()

func open_game() -> void:
	Input.emulate_mouse_from_touch = previous_mouse_emulation
	get_tree().change_scene_to_file.call_deferred(GAME_SCENE)

func discard(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
