extends Control

const UramRig := preload("res://scripts/uram_lab_rig.gd")
const Res011Preview := preload("res://scripts/res011_lab_preview.gd")
const NAMES := {"uram":"우람","hangyeol":"한결","saebom":"새봄"}
const MOTIONS := {"idle":"대기","walk":"걷기","run":"달리기","attack":"공격","hit_reaction":"피격","parry":"받아치기","full":"전체 모션"}
const CLIPS := {
	"uram":{"idle":"idle","walk":"walk","run":"run","attack":"club_attack","hit_reaction":"hit_reaction","parry":"parry","full":"full_motion"},
	"hangyeol":{"attack":Res011Preview.JUMP_CLIP},
	"saebom":{"attack":"sling_cast"},
}
# The approved Uram composite starts its club attack at frame 216 (60 fps).
const COMPOSITE_ATTACK_START := 216.0/60.0
const REPEATS := ["idle","walk","run"]

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
	var category := "attack" if selection=="full" and character!="uram" else selection
	return CLIPS[character].get(category,"")

func start_for(character: String) -> float:
	return COMPOSITE_ATTACK_START if selection=="full" and character!="uram" else 0.0

func clip_duration(character: String, clip: String) -> float:
	var preview: HybridCharacter = previews[character]
	if preview is UramRig: return preview.clip_length(clip)
	return (preview as Res011Preview).duration()

func sample(character: String, clip: String, seconds: float) -> void:
	var preview: HybridCharacter = previews[character]
	if preview is UramRig:
		preview.show_pose("idle" if clip.is_empty() else clip,seconds)
	else:
		(preview as Res011Preview).sample(seconds)
	preview.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
