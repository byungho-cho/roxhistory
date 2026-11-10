extends Control

const BASE_VERSION := "0.2.91"
const BASE_COMMIT := "9c97f052b583c255c4512bc122919c625bef9551"
const RUNTIME := "godot-4.5.1-android-pck-2"
const RELEASE_ROOT := "https://github.com/byungho-cho/roxhistory/releases/download/android-patches-0.2.91/"
signal check_status_changed(value: String)
var check_status := "":
	set(value):
		check_status = value
		check_status_changed.emit(value)
var checked_title := false
var title_active := false
var restart_pending := false
const TRUST := preload("res://patch_test/patch_key.gd")

var cache := "user://rox-patches-0.2.91/"
@onready var index := cache + "current.json"
var shade:ColorRect
var popup:CenterContainer
var update_rows:VBoxContainer
var request: HTTPRequest
var status: Label
var update_button: Button
var close_button: Button
var progress_bar: ProgressBar
var progress_text: Label
var downloading := false
var previous_mouse_emulation := false
var cached := {}
var candidate := {}
var envelope := PackedByteArray()
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	DirAccess.make_dir_recursive_absolute(cache)
	discard(cache + "incoming.part")
	discard(index + ".part")
	cached = verified_manifest(FileAccess.get_file_as_bytes(index)) if FileAccess.file_exists(index) else {}
	if not cached.is_empty() and not valid_pack(pack_path(cached),cached):cached = {}
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
	progress_bar.show_percentage = false
	progress_bar.hide()
	rows.add_child(progress_bar)
	progress_text = Label.new()
	progress_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	progress_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_text.add_theme_color_override("font_outline_color", Color.BLACK)
	progress_text.add_theme_constant_override("outline_size", 4)
	progress_bar.add_child(progress_text)
	progress_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	update_button = action(rows, "업데이트 받기", download_patch)
	close_button = action(rows, "닫기", close_popup)
	request = HTTPRequest.new()
	request.timeout = 30.0
	request.body_size_limit = 8192
	add_child(request)
	request.request_completed.connect(request_completed)
	ProjectSettings.set_setting("roxhistory/native/diagnostic_zip",true)
	shade.hide()
	popup.hide()
	ProjectSettings.set_setting("roxhistory/update/source_commit",BASE_COMMIT)
	mount_cached()

func title_ready() -> void:
	title_active = true
	if not is_inside_tree():return
	if not checked_title and not OS.get_cmdline_user_args().has("--test-ui"):
		checked_title = true
		check_for_patch()

func show_popup() -> void:
	previous_mouse_emulation = Input.emulate_mouse_from_touch
	Input.emulate_mouse_from_touch = true
	shade.show()
	popup.show()

func leave_title() -> void:
	title_active = false
	close_popup()

func close_popup()->void:
	if popup.visible:
		request.cancel_request()
		discard(cache + "incoming.part")
	downloading=false
	progress_bar.hide()
	if popup.visible:Input.emulate_mouse_from_touch = previous_mouse_emulation
	popup.hide()
	shade.hide()

func _process(_delta: float) -> void:
	if downloading:
		update_download_progress(request.get_downloaded_bytes(), int(candidate.size))

func update_download_progress(received: int, total: int) -> void:
	var downloaded := clampi(received, 0, total)
	progress_bar.value = minf(99.0, 100.0 * downloaded / float(total))
	progress_text.text = "%d%%  ·  %.1f / %.1f MB" % [
		floori(progress_bar.value), downloaded / 1000000.0, total / 1000000.0
	]

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
	check_status = status.text
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
		var remote := verify_payload(body)
		if compatible(remote) and remote.get("version")==BASE_VERSION and remote.get("patch_available")==false:
			check_status = ""
			return
		candidate = verified_manifest(body)
		if candidate.is_empty():
			show_failure()
			return
		if version_number(candidate.version) <= version_number(cached.get("version", BASE_VERSION)):
			status.text = "이미 최신 버전입니다"
			check_status = ""
			update_button.disabled = false
			return
		envelope = body
		status.text = "새 버전 "+candidate.version
		update_button.disabled=false
		update_rows.show()
		check_status = ""
		if title_active:
			show_popup()
		else:
			checked_title = false
		return
	if not valid_pack(cache + "incoming.part",candidate):
		show_failure()
		return
	if DirAccess.rename_absolute(cache + "incoming.part",pack_path(candidate)) != OK:
		show_failure()
		return
	if not save_index():
		show_failure()
		return
	downloading = false
	progress_bar.hide()
	restart_pending = true
	status.hide()
	close_button.hide()
	update_button.text = "게임 재실행"
	update_button.disabled = false

func download_patch()->void:
	if restart_pending:
		update_button.disabled = true
		if OS.has_feature("android"):
			# The Android export host restarts its process for create_instance().
			if OS.create_instance(PackedStringArray()) < 0:
				status.text = "게임을 다시 열지 못했습니다. 한 번 더 눌러 주세요."
				status.show()
				update_button.disabled = false
		else:
			OS.set_restart_on_exit(true, OS.get_cmdline_args())
			get_tree().quit()
		return
	if candidate.is_empty():return
	update_button.disabled=true
	downloading=true
	update_download_progress(0, int(candidate.size))
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

func compatible(data: Dictionary) -> bool:
	return data.get("base")==BASE_VERSION and data.get("base_commit")==BASE_COMMIT and data.get("runtime")==RUNTIME

func verified_manifest(bytes:PackedByteArray) -> Dictionary:
	var data:=verify_payload(bytes)
	if not compatible(data):return {}
	if not data.get("version") is String or not data.get("sha256") is String or not data.get("size") is float:return {}
	var regex := RegEx.new()
	regex.compile("^[0-9]{1,4}\\.[0-9]{1,4}\\.[0-9]{1,4}$")
	if regex.search(data.version)==null or version_number(data.version)<=version_number(BASE_VERSION):return {}
	regex.compile("^[0-9a-f]{64}$")
	if not data.get("commit") is String or data.commit.length()!=40:return {}
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
	ProjectSettings.set_setting("roxhistory/update/source_commit",cached.commit)
	return true

func show_failure() -> void:
	downloading = false
	progress_bar.hide()
	discard(cache + "incoming.part")
	status.text = "업데이트 확인 또는 다운로드 실패"
	check_status = status.text
	update_button.disabled = false

func discard(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
