extends Control

const BASE_VERSION := "0.1.85"
const BASE_COMMIT := "8dbab7655bba5c535a95f26c308cbd784358af02"
const RUNTIME := "godot-4.5.1-android-pck-1"
const RELEASE_ROOT := "https://github.com/byungho-cho/roxhistory/releases/download/android-patches/"
const GAME_SCENE := "res://scenes/main.tscn"
const TRUST := preload("res://patch_test/patch_key.gd")

var cache := "user://rox-patches/"
@onready var index := cache + "current.json"
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
	var shade := ColorRect.new()
	shade.color = Color(0.08, 0.06, 0.03, 0.55)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("34261b")
	style.border_color = Color("d4a45f")
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var rows := VBoxContainer.new()
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
	update_button = action(rows, "업데이트 확인", check_for_patch)
	action(rows, "현재 버전 실행", play_current)
	request = HTTPRequest.new()
	request.timeout = 30.0
	request.body_size_limit = 8192
	add_child(request)
	request.request_completed.connect(request_completed)

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

func action(rows: VBoxContainer, caption: String, callback: Callable) -> Button:
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
		downloading = true
		progress_bar.value = 0
		progress_bar.show()
		status.text = candidate.version + " 다운로드 중…"
		request.download_file = cache + "incoming.part"
		request.body_size_limit = int(candidate.size)
		if request.request(RELEASE_ROOT + candidate.file) != OK:
			show_failure()
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

func verified_manifest(bytes:PackedByteArray) -> Dictionary:
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
	if not data is Dictionary:return {}
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
	return true

func show_failure() -> void:
	downloading = false
	progress_bar.hide()
	discard(cache + "incoming.part")
	status.text = "업데이트 실패 · 현재 버전으로 실행할 수 있어요"
	update_button.disabled = false

func play_current() -> void:
	request.cancel_request()
	discard(cache + "incoming.part")
	mount_cached()
	open_game()

func open_game() -> void:
	Input.emulate_mouse_from_touch = previous_mouse_emulation
	get_tree().change_scene_to_file.call_deferred(GAME_SCENE)

func discard(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
