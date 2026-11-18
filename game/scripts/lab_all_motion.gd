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
const URAM_RATIOS := [1.0,1.1,1.2,1.3,1.4,1.5]
const URAM_STEP := 126
const URAM_VIEW := Vector2i(576,648)

var previews: Dictionary = {}
var statuses: Dictionary = {}
var uram_scroll: ScrollContainer
var navigation_buttons: Array[Button] = []
var scroll_finger := -1
var scroll_origin := Vector2.ZERO
var scroll_start := 0
var scroll_dragging := false
var selection := ""
var age := 0.0
var duration := 0.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	uram_scroll = ScrollContainer.new()
	uram_scroll.name = "UramSizeScroll"
	uram_scroll.position = Vector2(78,130)
	uram_scroll.size = Vector2(252,256)
	uram_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	uram_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	uram_scroll.mouse_filter = MOUSE_FILTER_PASS
	uram_scroll.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	add_child(uram_scroll)
	var strip := Control.new()
	strip.custom_minimum_size = Vector2(URAM_STEP*6+6,232)
	strip.mouse_filter = MOUSE_FILTER_IGNORE
	uram_scroll.add_child(strip)
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
			var camera_size := preview.camera.size
			var old_height := preview.viewport.size.y
			preview.viewport.size = URAM_VIEW
			preview.camera.size = camera_size*float(URAM_VIEW.y)/old_height
			preview.display.position = -preview.camera.unproject_position(Vector3.ZERO)*preview.display.scale
			preview.reparent(strip,false)
			preview.position = Vector2(66,195)
		preview.set_enabled(true)
		var status := FigmaArt.text(self,NAMES[character],Rect2(preview.position.x-90,preview.position.y+12,180,24),16,FigmaArt.BODY,Color("fff1d8"))
		status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		status.add_theme_color_override("font_outline_color",Color("49321e"))
		status.add_theme_constant_override("outline_size",5)
		statuses[character] = status
		sample(character,"",0)
	for i in range(1,URAM_RATIOS.size()):
		var reference := previews.uram as UramRig
		var preview := UramRig.new()
		preview.use_retouch = true
		preview.render_size_factor = reference.render_size_factor
		preview.name = "uram%d" % roundi(URAM_RATIOS[i]*100)
		preview.scale = Vector2.ONE*Res011Preview.MOTION_DISPLAY_SCALE*URAM_RATIOS[i]
		preview.position = Vector2(66+URAM_STEP*i,195)
		strip.add_child(preview)
		preview.viewport.size = URAM_VIEW
		preview.camera.transform = reference.camera.transform
		preview.camera.size = reference.camera.size
		preview.pivot.rotation = reference.pivot.rotation
		preview.display.scale = reference.display.scale
		preview.display.position = reference.display.position
		preview.set_enabled(true)
		previews[preview.name] = preview
		var caption := FigmaArt.text(strip,"",Rect2(preview.position.x-60,207,120,24),13,FigmaArt.BODY,Color("fff1d8"))
		caption.add_theme_color_override("font_outline_color",Color("49321e"))
		caption.add_theme_constant_override("outline_size",5)
		statuses[preview.name] = caption
	var first_caption := statuses.uram as Label
	first_caption.reparent(strip,false)
	first_caption.position = Vector2(6,207)
	first_caption.size = Vector2(120,24)
	first_caption.add_theme_font_size_override("font_size",13)
	render_frame()

func scroll_by(amount: int) -> void:
	uram_scroll.scroll_horizontal += amount

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if event is InputEventScreenTouch:
		if event.pressed and uram_scroll.get_global_rect().has_point(event.position):
			scroll_finger = event.index
			scroll_origin = event.position
			scroll_start = uram_scroll.scroll_horizontal
			scroll_dragging = false
		elif not event.pressed and event.index==scroll_finger:
			scroll_finger = -1
			if scroll_dragging: get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index==scroll_finger:
		if event.position.distance_to(scroll_origin)>8: scroll_dragging = true
		if scroll_dragging:
			var factor := get_global_transform().get_scale().x
			uram_scroll.scroll_horizontal = scroll_start+roundi((scroll_origin.x-event.position.x)/factor)
			get_viewport().set_input_as_handled()

func character_for(key: String) -> String:
	return "uram" if key.begins_with("uram") else key

func caption_for(key: String) -> String:
	if key=="uram": return "현재 (100%)"
	if key.begins_with("uram"):
		var percent := key.trim_prefix("uram").to_int()
		return "+%d%% (%d%%)" % [percent-100,percent]
	return NAMES[key]

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
		caption.text = caption_for(character)+(" · 미연결" if not selection.is_empty() and clip.is_empty() else "")
		sample(character,clip if playing else "",fposmod(elapsed,length) if playing else 0.0)

func clip_for(character: String) -> String:
	var source := character_for(character)
	var category := "attack" if selection=="full" and source!="uram" else selection
	return CLIPS[source].get(category,"")

func start_for(character: String) -> float:
	return COMPOSITE_ATTACK_START if selection=="full" and character_for(character)!="uram" else 0.0

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
