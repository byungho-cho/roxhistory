extends Control

const BASE_VERSION := "0.1.85"
const TARGET_VERSION := "0.1.86"
const PATCH_SIZE := 127304
# The APK pins this reviewed payload. A replacement file on the same host cannot authorize itself.
const PATCH_SHA256 := "e546618f6ca58f069516dfc5cceb8a1d2fedb8197f5f4d1c4e8bb1189822d4af"
const PATCH_URL := "https://github.com/byungho-cho/roxhistory/releases/download/pck-test-0.1.85-to-0.1.86/Roxhistory_0.1.85_to_0.1.86.pck"
const GAME_SCENE := "res://scenes/main.tscn"

var patch_path := "user://roxhistory-patch-0.1.85-to-0.1.86.pck"
var request: HTTPRequest
var status: Label
var update_button: Button
var progress_bar: ProgressBar
var downloading := false
var previous_mouse_emulation := false

func _ready() -> void:
	previous_mouse_emulation = Input.emulate_mouse_from_touch
	Input.emulate_mouse_from_touch = true
	discard(patch_path + ".part")
	if valid_patch(patch_path) and mount_patch():
		open_game()
		return
	var had_invalid_patch := FileAccess.file_exists(patch_path)
	discard(patch_path)
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
	status.text = "RoxHistory PCK test  %s → %s" % [BASE_VERSION, TARGET_VERSION]
	if had_invalid_patch: status.text = "Invalid patch removed. Base %s is available." % BASE_VERSION
	rows.add_child(status)
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size.y = 24
	progress_bar.hide()
	rows.add_child(progress_bar)
	update_button = action(rows, "Download and play " + TARGET_VERSION, download_patch)
	action(rows, "Play base / cancel download", play_base)
	request = HTTPRequest.new()
	request.timeout = 30.0
	request.body_size_limit = PATCH_SIZE
	add_child(request)
	request.request_completed.connect(download_complete)

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
	logo.set_anchor_and_offset(SIDE_LEFT, .25, 0)
	logo.set_anchor_and_offset(SIDE_RIGHT, .75, 0)
	logo.set_anchor_and_offset(SIDE_BOTTOM, .25, 0)

func _process(_delta: float) -> void:
	if downloading:
		progress_bar.value = minf(99.0, 100.0 * request.get_downloaded_bytes() / PATCH_SIZE)

func action(rows: VBoxContainer, caption: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 52
	button.pressed.connect(callback)
	rows.add_child(button)
	return button

func download_patch() -> void:
	update_button.disabled = true
	downloading = true
	progress_bar.value = 0
	progress_bar.show()
	status.text = "Downloading " + TARGET_VERSION + "…"
	request.download_file = patch_path + ".part"
	if request.request(PATCH_URL) != OK:
		show_failure()

func download_complete(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or not promote_download():
		show_failure()
		return
	if mount_patch():
		open_game()
	else:
		discard(patch_path)
		show_failure()

func valid_patch(path: String) -> bool:
	if str(ProjectSettings.get_setting("application/config/version")) != BASE_VERSION:
		return false
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() != PATCH_SIZE:
		return false
	file.close()
	return FileAccess.get_sha256(path) == PATCH_SHA256

func promote_download() -> bool:
	var partial := patch_path + ".part"
	if not valid_patch(partial):
		return false
	return DirAccess.rename_absolute(partial, patch_path) == OK

func mount_patch() -> bool:
	if not ProjectSettings.load_resource_pack(patch_path, true):
		return false
	# project.binary was already read by the engine before bootstrap.
	ProjectSettings.set_setting("application/config/version", TARGET_VERSION)
	return true

func show_failure() -> void:
	downloading = false
	progress_bar.hide()
	discard(patch_path + ".part")
	status.text = "Update unavailable. Base %s is available." % BASE_VERSION
	update_button.disabled = false

func play_base() -> void:
	request.cancel_request()
	discard(patch_path + ".part")
	open_game()

func open_game() -> void:
	Input.emulate_mouse_from_touch = previous_mouse_emulation
	get_tree().change_scene_to_file.call_deferred(GAME_SCENE)

func discard(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
