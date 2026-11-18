extends Control

const UramRig := preload("res://scripts/uram_lab_rig.gd")
const Res011Preview := preload("res://scripts/res011_lab_preview.gd")
const NAMES := {"uram":"우람","hangyeol":"한결","saebom":"새봄"}
const MOTIONS := {"idle":"대기","walk":"걷기","run":"달리기","attack":"공격","hit_reaction":"피격","parry":"받아치기","full":"전체 모션"}
const CLIPS := {
	"uram":{"idle":"idle","walk":"walk","run":"run","attack":"club_attack","hit_reaction":"hit_reaction","parry":"parry","full":"full_motion"},
	"hangyeol":{"attack":"stone_spear_thrust"},
	"saebom":{"attack":"sling_cast"},
}
# The approved Uram composite starts its club attack at frame 216 (60 fps).
const COMPOSITE_ATTACK_START := 216.0/60.0
const REPEATS := ["idle","walk","run"]
const VIEW := Vector2i(256,232)

var previews: Dictionary = {}
var statuses: Dictionary = {}
var selection := ""
var age := 0.0
var duration := 0.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("2c2018e8")
	skin.border_color = Color("c5a775")
	skin.set_border_width_all(1)
	skin.set_corner_radius_all(8)
	for character in NAMES:
		var index := previews.size()
		var card := Panel.new()
		card.name = character
		card.position = Vector2(69+278*index,155)
		card.size = Vector2(266,266)
		card.mouse_filter = MOUSE_FILTER_IGNORE
		card.clip_contents = true
		card.add_theme_stylebox_override("panel",skin)
		add_child(card)
		var name_label := FigmaArt.text(card,NAMES[character],Rect2(8,6,250,27),18,FigmaArt.BODY,Color("fff1d8"))
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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
		card.add_child(preview)
		previews[character] = preview
		preview.viewport.size = VIEW
		preview.camera.position = Vector3(0,4.2,7)
		preview.camera.look_at(Vector3(0,1.12,0))
		preview.camera.size = 3.25
		preview.pivot.rotation.y = deg_to_rad(29.0)
		preview.display.position = Vector2(16,32)
		preview.display.scale = Vector2.ONE*.91
		preview.set_enabled(true)
		var status := FigmaArt.text(card,"대기",Rect2(8,233,250,26),15,FigmaArt.BODY,Color("e8cc9f"))
		status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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
		caption.text = "대기" if selection.is_empty() else "미연결" if clip.is_empty() else "재생 중" if playing else "대기"
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
