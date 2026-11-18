extends Control

const UramRig := preload("res://scripts/uram_lab_rig.gd")
const Res011Preview := preload("res://scripts/res011_lab_preview.gd")
const NAMES := {"uram":"우람","hangyeol":"한결","saebom":"새봄"}
const Catalog := preload("res://scripts/lab_motion_catalog.gd")
const MOTIONS := Catalog.MOTIONS
const CLIPS := Catalog.CLIPS
const REPEATS := Catalog.REPEATS

var previews: Dictionary = {}
var statuses: Dictionary = {}
var selection := ""
var age := 0.0
var duration := 0.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	for character in NAMES:
		var index := previews.size()
		var preview: HybridCharacter
		if character=="uram":
			var uram := UramRig.new()
			uram.use_retouch = true
			preview = uram
		else:
			var resident := Res011Preview.new()
			resident.character = character
			resident.shared_motion_view = true
			preview = resident
		preview.name = character
		preview.render_size_factor = Res011Preview.MOTION_RENDER_FACTOR
		preview.scale = Vector2.ONE*Res011Preview.MOTION_DISPLAY_SCALE
		preview.position = Vector2(278+202*index,Res011Preview.MOTION_GROUND_Y)
		add_child(preview)
		previews[character] = preview
		if preview is UramRig:
			preview.camera.position = Res011Preview.GAME_CAMERA
			preview.camera.look_at(Res011Preview.GAME_AIM)
			preview.pivot.rotation.y = Res011Preview.MOTION_HEADING
			preview.display.position = -preview.camera.unproject_position(Vector3.ZERO)*preview.display.scale
			preview.scale *= 1.3
		else:
			preview.scale *= 1.05
		# Double the vertical extent at unchanged pixel density so R03 can jump
		# and travel inside its own render target without moving the 2D actor.
		preview.viewport.size = Vector2i(768,720)
		preview.camera.size = 7.0
		preview.display.position = -preview.camera.unproject_position(Vector3.ZERO)*preview.display.scale
		preview.set_enabled(true)
		var status := FigmaArt.text(self,NAMES[character],Rect2(preview.position.x-90,preview.position.y+12,180,24),16,FigmaArt.BODY,Color("fff1d8"))
		status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		status.add_theme_color_override("font_outline_color",Color("49321e"))
		status.add_theme_constant_override("outline_size",5)
		statuses[character] = status
		sample(character,"",0)
	render_frame()

func play(key: String) -> void:
	if not MOTIONS.has(key): return
	selection = key
	age = 0.0
	duration = 0.0
	for character in previews:
		var clip := clip_for(character)
		if not clip.is_empty():
			duration = maxf(duration,start_for(character)+clip_duration(character,clip))
	render_frame()

func advance(delta: float) -> void:
	if selection.is_empty() or (selection not in REPEATS and age>=duration): return
	age += delta
	render_frame()

func render_frame() -> void:
	for character in previews:
		var clip := clip_for(character)
		var start := start_for(character)
		var elapsed := age-start
		var length := clip_duration(character,clip) if not clip.is_empty() else 0.0
		var playing := not clip.is_empty() and elapsed>=0 and (selection in REPEATS or elapsed<length)
		var caption: Label = statuses[character]
		caption.text = NAMES[character]+(" · 미연결" if not selection.is_empty() and clip.is_empty() else "")
		sample(character,clip if playing else "",fposmod(elapsed,length) if playing else 0.0)

func clip_for(character: String) -> String:
	return CLIPS[character].get(selection,"")

func start_for(_character: String) -> float:
	return 0.0

func clip_duration(character: String, clip: String) -> float:
	var preview: HybridCharacter = previews[character]
	if preview is UramRig: return preview.clip_length(clip)
	return preview.motion_duration(selection)

func sample(character: String, clip: String, seconds: float) -> void:
	var preview: HybridCharacter = previews[character]
	if preview is UramRig:
		preview.show_pose("idle" if clip.is_empty() else clip,seconds)
	else:
		preview.sample_motion("idle" if clip.is_empty() else selection,seconds)
	preview.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
