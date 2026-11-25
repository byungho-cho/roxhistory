extends Control

const ART := "res://assets/ui/hero-level-up/"
const DESIGN := Vector2(1670, 941)
const CREAM := Color("f8e2ad")
const GOLD := Color("ffd283")
const DARK := Color(0.16, 0.14, 0.10, 0.82)
const REPEAT_SECONDS := 0.25
const FEED_RAMP_SECONDS := 1.5
const FEED_TOP_SPEED := 2.5
const NONE := -2
const HERO_INTERACTION := Rect2(679, 100, 413, 560)
const SWIPE_SLOP := 20.0
const SWIPE_PREVIEW_SLOP := 5.0
const SWIPE_COMMIT := 70.0
const MOTION_SIZE := Vector2(1280, 720)
const PANEL_HEIGHT := 520.0
const GROWTH_WIDTH := 297.0
const ROSTER_WIDTH := 280.0
const ROSTER_X := 1342.0
const GOLD_LOCK := preload("res://assets/ui/d0024/08-ui-padlock-gold.png")
const FOLD_SHADER := preload("res://shaders/hero_landscape_feather.gdshader")
const VALLEY_ART := ART + "valley/"
const VALLEY_TERRAIN := preload("res://assets/ui/hero-level-up/valley/valley.jpg")
const VALLEY_MIST := preload("res://assets/ui/hero-level-up/valley/mist.png")
const VALLEY_PACKED_SHADER := preload("res://shaders/packed_alpha_cutin.gdshader")
const VALLEY_SOURCE_SIZE := Vector2(1112, 834)
const VALLEY_SPAN_RATIO := 366.0 / 960.0
const HEROES_PER_PANORAMA := 3
const VALLEY_PANORAMAS := [VALLEY_TERRAIN, preload("res://assets/ui/hero-level-up/valley/riverbend.jpg")]
# x is the foot centre; y is the first-frame footline. Heights exclude the spear.
const VALLEY_LAYOUT := [[552, 792, 728], [553, 748, 535], [550, 645, 507], [525, 735, 615], [553, 783, 679]]
const MOTIONS := [
	{
		"idle": preload("res://assets/ui/hero-level-up/han-idle.ogv"),
		"action": preload("res://assets/ui/hero-level-up/han-action.ogv"),
		"poster": preload("res://assets/ui/hero-level-up/han-action-start.webp"),
	},
	{
		"idle": preload("res://assets/ui/hero-level-up/uram-idle.ogv"),
		"action": preload("res://assets/ui/hero-level-up/uram-tap.ogv"),
		"fold_full_action": preload("res://assets/ui/hero-level-up/uram-full-fold-action.ogv"),
		"poster": preload("res://assets/ui/hero-level-up/uram-action-start.webp"),
	},
	{
		"idle": preload("res://assets/ui/hero-level-up/saebom-idle.ogv"),
		"action": preload("res://assets/ui/hero-level-up/saebom-action.ogv"),
		"poster": preload("res://assets/ui/hero-level-up/saebom-action-start.webp"),
	},
	{
		"idle": preload("res://assets/ui/hero-level-up/gahui-idle.ogv"),
		"action": preload("res://assets/ui/hero-level-up/gahui-action.ogv"),
		"poster": preload("res://assets/ui/hero-level-up/gahui-action-start.webp"),
		"size": Vector2(960, 960), "anchor": Vector2(451, 812), "stature": 674.0,
	},
	{
		"idle": preload("res://assets/ui/hero-level-up/bau-idle.ogv"),
		"action": preload("res://assets/ui/hero-level-up/bau-action.ogv"),
		"poster": preload("res://assets/ui/hero-level-up/bau-action-start.webp"),
		"size": Vector2(768, 768), "anchor": Vector2(369, 650), "stature": 538.0,
	},
]
const DATA := [
	["한결", "han", "근접", "ally-melee", "han-3sp-A.png"],
	["우람", "uram", "방어", "ally-tank", "uram-3sp.png"],
	["새봄", "saebom", "원거리", "ally-ranged", "saebom-3sp-transparent.png"],
	["가희", "gahui", "치유", "ally-healer", ""], ["바우", "bau", "주술", "ally-shaman", ""]
]
const PREVIEW_SKILLS := {
	3: [
		[preload("res://assets/ui/hero-level-up/gahui-preview-2sp.svg"), "물화살 연타"],
		[preload("res://assets/ui/hero-level-up/gahui-preview-3sp.svg"), "생명의 샘"],
	],
	4: [
		[preload("res://assets/ui/hero-level-up/bau-preview-2sp.svg"), "낙인 불기둥"],
		[preload("res://assets/ui/hero-level-up/bau-preview-3sp.svg"), "화염 문양"],
	],
}
const BACK := preload("res://assets/ui/d0024/08-ui-back-button.png")
const Readiness := preload("res://scripts/hunt_readiness_art.gd")

var app
var board: Control
var world_view: Control
var active_scene: Control
var active_background: TextureRect
var active_foreground: Control
var back_button: Button
var bag_button: Button
var screen_title: Label
var fold_material: ShaderMaterial
var fold_motion := false
var hero_video: VideoStreamPlayer
var hero_frame: TextureRect
var motion_generation := 0
var outgoing_scene: Control
var slide: Tween
var celebration: Tween
var selected := 0
var navigable: Array[int] = []
var roster: Array[Button] = []
var locks: Array[TextureRect] = []
var level_text: Label
var xp_text: Label
var remaining_text: Label
var meat_text: Label
var xp_fill: Panel
var before_text: Array[Label] = []
var after_text: Array[Label] = []
var upgrade: Button
var debug_growth_reset: Button
var previous: Button
var forward: Button
var arrow_fade: Tween
var nav_opacity := 1.0
var previous_arrow: TextureRect
var forward_arrow: TextureRect
var swipe_card_hint: Panel
var hero_name: Label
var role_name: Label
var role_art: TextureRect
var skills: Control
var hero_details: Control
var roster_roles: Array[TextureRect] = []
var skill_art: Array[TextureRect] = []
var skill_value: Array[Label] = []
var skill_frame: Array[Panel] = []
var chain_lock: TextureRect
var celebration_text: Label
var held := NONE
var swipe := NONE
var swipe_start := Vector2.ZERO
var swipe_moved := false
var swipe_can_activate := false
var roster_frame: NinePatchRect
var roster_scroll: ScrollContainer
var roster_touch := NONE
var roster_touch_start := Vector2.ZERO
var roster_scroll_start := 0
var roster_dragging := false
var swipe_follow_hero := true
var swipe_scene_tween: Tween
var valley_view: Control
var valley_terrain: TextureRect
var valley_mist: TextureRect
var valley_viewport := Rect2()
var valley_camera := 0.0
var valley_mist_phase := -1.0
var valley_group := 0
var valley_departing: TextureRect
var valley_anim: Tween

var repeats_in := REPEAT_SECONDS
var hold_seconds := 0.0
var bold := FontVariation.new()

func _ready() -> void:
	name = "HeroLevelUp"
	bold.base_font = FigmaArt.NOTO
	bold.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700}
	mouse_filter = Control.MOUSE_FILTER_STOP
	board = Control.new()
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.size = DESIGN
	add_child(board)
	world_view = Control.new()
	world_view.name = "MovingHeroScene"
	world_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(world_view)
	make_valley()
	make_scene()
	make_header()
	make_bag_button()
	make_growth()
	make_hero_details()
	make_roster()
	app.model.changed.connect(refresh)
	resized.connect(fit)
	fit()
	refresh()
	show_nav_hints()
	set_process(false)

func fit() -> void:
	if size.x < 1 or size.y < 1: return
	var safe: Vector2 = app.safe
	# Inset only when a design control would cross the physical safe area.
	var factor := maxf(0.01, minf(minf(size.x / DESIGN.x, size.y / DESIGN.y),
		minf((size.x - 2.0 * safe.x) / 1556.0, (size.y - 2.0 * safe.y) / 881.0)))
	board.scale = Vector2.ONE * factor
	board.position = (size - DESIGN * factor) * 0.5
	var bleed := -board.position / factor
	var viewport := Rect2(bleed, size / factor)
	active_background.position = viewport.position
	active_background.size = viewport.size
	valley_viewport = viewport
	fit_valley()
	skills.position.y = viewport.end.y - DESIGN.y - maxf(0.0, safe.y / factor - 48.0)
	hero_details.position.y = skills.position.y
	debug_growth_reset.position.y = 841.0 + skills.position.y
	var hud_margin := Vector2(maxf(48.0 * factor, safe.x), maxf(48.0 * factor, safe.y))
	back_button.position = (hud_margin - board.position) / factor
	screen_title.position = back_button.position + Vector2(96, (back_button.size.y - screen_title.size.y) * 0.5)
	bag_button.position = Vector2(viewport.end.x - hud_margin.x / factor - bag_button.size.x, back_button.position.y)
	if is_instance_valid(hero_video):
		fit_hero_motion(viewport)
	if is_instance_valid(outgoing_scene):
		var background := outgoing_scene.get_child(0) as TextureRect
		background.position = viewport.position
		background.size = viewport.size

func fit_hero_motion(viewport: Rect2) -> void:
	if swipe_follow_hero:
		var a: Array = VALLEY_LAYOUT[selected]
		var unit := viewport.size.y / MOTION_SIZE.y
		var scale_to_stature := unit * 400.0 / float(a[2])
		var feet := viewport.position + Vector2(viewport.size.x * 0.5, unit * (590.0 if selected == 0 else 550.0))
		hero_video.size = VALLEY_SOURCE_SIZE * scale_to_stature
		hero_video.position = feet - Vector2(a[0], a[1]) * scale_to_stature
		hero_video.material = fold_material
		hero_frame.material = fold_material
		hero_frame.position = hero_video.position
		hero_frame.size = hero_video.size
		return
	var fold_layout := viewport.size.aspect() <= 1.5
	if fold_layout != fold_motion:
		fold_motion = fold_layout
		play_hero_motion(not hero_video.loop, true)

	# Match the 16:9 cover's screen-height ratio. On Fold only the sides crop.
	var cover := viewport.size.y / MOTION_SIZE.y if fold_motion else maxf(viewport.size.x / MOTION_SIZE.x, viewport.size.y / MOTION_SIZE.y)
	var clip: Dictionary = MOTIONS[selected]
	if clip.has("anchor"):
		var unit := viewport.size.y / MOTION_SIZE.y
		var scale_to_stature := unit * 400.0 / float(clip.stature)
		var feet := viewport.position + Vector2(viewport.size.x * 0.5, unit * 500.0)
		hero_video.size = Vector2(clip.size) * scale_to_stature
		hero_video.position = feet - Vector2(clip.anchor) * scale_to_stature
	else:
		hero_video.size = MOTION_SIZE * cover
		hero_video.position = viewport.get_center() - hero_video.size * 0.5
	hero_video.material = fold_material if fold_motion or clip.has("anchor") else null
	hero_frame.material = hero_video.material
	hero_frame.position = hero_video.position
	hero_frame.size = hero_video.size

func make_valley() -> void:
	valley_view = Control.new()
	valley_view.name = "ContinuousValleyViewport"
	valley_view.clip_contents = true
	valley_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_view.add_child(valley_view)
	valley_terrain = TextureRect.new()
	valley_terrain.name = "ContinuousValleyPanorama"
	valley_terrain.texture = VALLEY_TERRAIN
	valley_terrain.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	valley_terrain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	valley_view.add_child(valley_terrain)
	valley_mist = TextureRect.new()
	valley_mist.name = "ContinuousValleyMist"
	valley_mist.texture = VALLEY_MIST
	valley_mist.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	valley_mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	valley_view.add_child(valley_mist)
	valley_view.hide()

func fit_valley() -> void:
	if not is_instance_valid(valley_view): return
	valley_view.visible = swipe_follow_hero
	if not swipe_follow_hero: return
	var area := valley_viewport
	valley_view.position = area.position
	valley_view.size = area.size
	var first := valley_group * HEROES_PER_PANORAMA
	var last := mini(first + HEROES_PER_PANORAMA - 1, DATA.size() - 1)
	# Leave enough overscan to keep showing this section until release.
	var low := -0.9 if first > 0 else 0.0
	var high := float(last - first) + (0.9 if last < DATA.size() - 1 else 0.0)
	var span_slots := maxf(1.0, high - low)
	var scene_art := VALLEY_PANORAMAS[mini(valley_group, VALLEY_PANORAMAS.size()-1)] as Texture2D
	if valley_terrain.texture != scene_art: valley_terrain.texture = scene_art
	var native := scene_art.get_size()
	var fit_ratio := maxf(area.size.y / native.y, area.size.x / native.x)
	var target_step := area.size.x * VALLEY_SPAN_RATIO
	var max_zoom := fit_ratio * (1.32 if valley_group == 0 else 1.24)
	var scale_fit := minf(maxf(fit_ratio, (area.size.x + target_step * span_slots + 20.0) / native.x), max_zoom)
	valley_terrain.size = native * scale_fit
	var step := minf(target_step, maxf(0.0, valley_terrain.size.x - area.size.x - 20.0) / span_slots)
	var lead := (valley_terrain.size.x - area.size.x - step * span_slots) * 0.5
	var x := clampf((valley_camera - float(first) - low) * step, -maxf(0.0, lead - 10.0) if first == 0 else 0.0, (high - low) * step + (maxf(0.0, lead - 10.0) if last == DATA.size() - 1 else 0.0))
	valley_terrain.position = Vector2(-lead - x, (area.size.y - valley_terrain.size.y) * 0.5)
	# Fog is common to every section. Do not reset its offset at a landscape change.
	var mist_travel := area.size.x * 0.34
	valley_mist.size = Vector2(area.size.x + mist_travel + 30.0, area.size.y * (370.0 / 720.0))
	var phase := valley_mist_phase if valley_mist_phase >= 0.0 else clampf(valley_camera, 0.0, float(DATA.size()-1))
	valley_mist.position = Vector2(-15.0 - mist_travel * phase / maxf(1.0, float(DATA.size()-1)), area.size.y - valley_mist.size.y)

func clear_valley_departure() -> void:
	if is_instance_valid(valley_departing):
		valley_departing.hide()
		valley_departing.queue_free()
	valley_departing = null

func capture_valley_departure() -> void:
	clear_valley_departure()
	valley_departing = TextureRect.new()
	valley_departing.texture = valley_terrain.texture
	valley_departing.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	valley_departing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	valley_view.add_child(valley_departing)
	valley_view.move_child(valley_departing, valley_mist.get_index())
	valley_departing.position = valley_terrain.position
	valley_departing.size = valley_terrain.size

func valley_group_for(index: int) -> int:
	return floori(float(index) / HEROES_PER_PANORAMA)


func set_valley_camera(value: float) -> void:
	valley_camera = value
	fit_valley()

func make_scene() -> void:
	active_scene = Control.new()
	active_scene.name = "HeroAndLandscape"
	active_scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_view.add_child(active_scene)
	active_background = picture(active_scene, "background-landscape-reconstructed.png", Rect2(Vector2.ZERO, DESIGN), TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	active_background.visible = not swipe_follow_hero
	active_foreground = Control.new()
	active_foreground.name = "HeroForeground"
	active_foreground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	active_scene.add_child(active_foreground)
	if selected < MOTIONS.size():
		make_hero_motion()

func make_hero_motion() -> void:
	fold_material = ShaderMaterial.new()
	fold_material.shader = VALLEY_PACKED_SHADER if swipe_follow_hero else FOLD_SHADER
	fold_motion = size.y > 0 and size.aspect() <= 1.5
	hero_video = VideoStreamPlayer.new()
	hero_video.name = "HeroLevelUpMotion"
	hero_video.expand = true
	hero_video.volume_db = -80.0
	hero_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_video.finished.connect(_finish_hero_motion.bind(hero_video))
	active_foreground.add_child(hero_video)
	hero_frame = TextureRect.new()
	hero_frame.name = "HeroTransitionFrame"
	hero_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	active_foreground.add_child(hero_frame)
	if swipe_follow_hero:
		show_valley_start()
	else:
		play_hero_motion(true)

func show_valley_start() -> void:
	var id := str(DATA[selected][1])
	hero_frame.texture = load(VALLEY_ART + id + "-start.png") as Texture2D
	hero_frame.show()
	hero_video.hide()

func play_hero_motion(action: bool, mode_changed := false) -> void:
	if not is_instance_valid(hero_video): return
	var player := hero_video
	if swipe_follow_hero:
		play_valley_action(action)
		return
	var clips: Dictionary = MOTIONS[selected]
	motion_generation += 1
	if action or mode_changed:
		# Show the requested first frame at once, including rapid action restarts.
		hero_frame.texture = clips.poster
		hero_frame.show()
	else:
		freeze_hero_frame()
	player.stop()
	var stream: VideoStream = clips.get("fold_full_action", clips.action) if action and fold_motion else (clips.action if action else clips.idle)
	if player.stream != stream:
		player.stream = stream
	player.loop = not action
	player.hide()
	player.play()
	show_hero_when_ready(player, motion_generation)

func play_valley_action(action: bool) -> void:
	var player := hero_video
	motion_generation += 1
	if not action:
		# Preserve the approved end pose, including Uram's lowered shield.
		freeze_hero_frame()
		player.stop()
		player.hide()
		if not is_instance_valid(hero_frame.texture):
			show_valley_start()
		return
	show_valley_start()
	player.stop()
	if not is_instance_valid(player.stream):
		player.stream = load(VALLEY_ART + str(DATA[selected][1]) + "-action.ogv") as VideoStream
	player.loop = false
	player.play()
	show_hero_when_ready(player, motion_generation)

func show_hero_when_ready(player: VideoStreamPlayer, generation: int) -> void:
	while is_instance_valid(player) and player == hero_video and generation == motion_generation:
		if player.stream_position >= 1.0 / 24.0 and player.get_video_texture().get_width() > 0:
			player.show()
			hero_frame.hide()
			hero_frame.texture = null
			return
		await get_tree().process_frame

func freeze_hero_frame() -> void:
	if not hero_video.visible: return
	var video_texture := hero_video.get_video_texture()
	if video_texture == null: return
	var pixels := video_texture.get_image()
	if pixels == null or pixels.is_empty(): return
	hero_frame.texture = ImageTexture.create_from_image(pixels)
	hero_frame.show()

func _finish_hero_motion(player: VideoStreamPlayer) -> void:
	if player == hero_video and not player.loop:
		_resume_hero_idle.call_deferred(player, motion_generation)

func _resume_hero_idle(player: VideoStreamPlayer, generation: int) -> void:
	if player == hero_video and generation == motion_generation:
		play_hero_motion(false)

func stop_hero_motion() -> void:
	motion_generation += 1
	if is_instance_valid(hero_video):
		hero_video.stop()
		hero_video.stream = null
		hero_video.hide()
	hero_video = null
	hero_frame = null

func _exit_tree() -> void:
	stop_hero_motion()

func make_header() -> void:
	back_button = action(board, Rect2(48, 48, 80, 80), "Back", app.go_back)
	app.picture(back_button, BACK, Rect2(0, 0, 80, 80))
	screen_title = text_at(board, "영웅 레벨업", Rect2(153, 55, 333, 66), 46, Color("ffe2a7"), HORIZONTAL_ALIGNMENT_LEFT, true)

func make_bag_button() -> void:
	bag_button = action(board, Rect2(1542, 48, 80, 80), "HeroBagButton", app.inventory_summary)
	bag_button.tooltip_text = "가방"
	var rim := panel_at(bag_button, Rect2(4, 4, 72, 72), Color(0.16, 0.11, 0.05, 0.86), Color("d6a65a"), 2, 15)
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	app.picture(bag_button, DemoArt.play_icon("bag"), Rect2(11, 11, 58, 58))

func make_growth() -> void:
	var frame := Control.new()
	frame.name = "GrowthPanel"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(board, frame, Rect2(80, (DESIGN.y - PANEL_HEIGHT) * 0.5, GROWTH_WIDTH, PANEL_HEIGHT))
	panel_at(frame, Rect2(5, 5, GROWTH_WIDTH - 10, PANEL_HEIGHT - 10), DARK, Color.TRANSPARENT, 0, 25)
	picture(frame, "growth-wood-frame.png", Rect2(0, 0, GROWTH_WIDTH, PANEL_HEIGHT), TextureRect.STRETCH_SCALE)
	level_text = text_at(frame, "", Rect2(20, 20, 257, 52), 38, GOLD, HORIZONTAL_ALIGNMENT_LEFT, true)
	level_text.name = "LevelAndCap"
	text_at(frame, "현재 경험치", Rect2(20, 79, 85, 29), 16)
	xp_text = text_at(frame, "", Rect2(106, 79, 78, 29), 16, Color("f6ce78"), HORIZONTAL_ALIGNMENT_LEFT, true)
	remaining_text = text_at(frame, "", Rect2(184, 79, 93, 29), 16, CREAM, HORIZONTAL_ALIGNMENT_RIGHT)
	panel_at(frame, Rect2(20, 108, 257, 20), Color("1c160c"), Color("966336"), 2, 9)
	xp_fill = panel_at(frame, Rect2(24, 112, 0, 11), Color("e9ba66"), Color("ffe6aa"), 1, 6)
	for i in 3:
		var y: int = 139 + i * 52
		text_at(frame, ["체력", "공격", "스킬"][i], Rect2(20, y, 104, 43), 22)
		before_text.append(text_at(frame, "", Rect2(127, y, 50, 43), 24, Color("ffe8bc"), HORIZONTAL_ALIGNMENT_RIGHT, true))
		text_at(frame, "→", Rect2(188, y, 24, 43), 23, Color("f0bb52"), HORIZONTAL_ALIGNMENT_CENTER, true)
		after_text.append(text_at(frame, "", Rect2(226, y, 51, 43), 24, Color("a9dd70"), HORIZONTAL_ALIGNMENT_RIGHT, true))
		panel_at(frame, Rect2(20, y + 45, 257, 1), Color("9e80507a"))
	app.picture(frame, DemoArt.icon("meat"), Rect2(20, 309, 48, 46))
	meat_text = text_at(frame, "", Rect2(146, 309, 131, 46), 20, Color("ffcc75"), HORIZONTAL_ALIGNMENT_RIGHT, true)
	meat_text.name = "MeatBalance"
	upgrade = action(frame, Rect2(20, 432, 257, 68), "FeedHero", Callable())
	make_wood_button(upgrade, "레벨업")
	debug_growth_reset = action(board, Rect2(80, 841, 154, 52), "HeroGrowthResetShortcut", app.confirm_hero_growth_reset.bind(app.close_modal))
	make_wood_button(debug_growth_reset, "초기화")
	debug_growth_reset.modulate.a = 0.82
	celebration_text = text_at(frame, "", Rect2(20, 365, 257, 53), 16, GOLD, HORIZONTAL_ALIGNMENT_CENTER, true)
	celebration_text.name = "LevelUpCelebration"
	celebration_text.hide()

func make_wood_button(button: Button, label: String) -> void:
	var area := Rect2(Vector2.ZERO, button.size)
	picture(button, "levelup-wood-cta-blank.png", area, TextureRect.STRETCH_SCALE)
	text_at(button, label, area, 36, Color("371c06"), HORIZONTAL_ALIGNMENT_CENTER, true)
	button.focus_mode = Control.FOCUS_NONE

func apply_skill_outline(label: Label) -> void:
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)

func make_hero_details() -> void:
	previous = action(board, Rect2(397, 377, 60, 81), "PreviousHero", cycle.bind(-1))
	forward = action(board, Rect2(1262, 377, 60, 81), "NextHero", cycle.bind(1))
	previous_arrow = picture(previous, "carousel-left.svg", Rect2(12, 11, 36, 59))
	forward_arrow = picture(forward, "carousel-right.svg", Rect2(12, 11, 36, 59))
	hero_details = Control.new()
	hero_details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(hero_details)
	picture(hero_details, "name-branch.svg", Rect2(650.8, 743.2, 368.4, 43), TextureRect.STRETCH_SCALE)
	hero_name = text_at(hero_details, "", Rect2(695.5, 708.2, 89, 52), 43, Color("ffdaa2"), HORIZONTAL_ALIGNMENT_RIGHT, true)
	panel_at(hero_details, Rect2(811.5, 719.2, 2, 33), Color("bf8b4acc"))
	panel_at(hero_details, Rect2(840.5, 716.2, 134, 44), Color("463215e6"), Color("a8844b"), 2, 12)
	role_art = app.picture(hero_details, null, Rect2(832.5, 710.2, 54, 54))
	role_name = text_at(hero_details, "", Rect2(904.5, 717.2, 54, 41), 23, Color("ffe3ae"), HORIZONTAL_ALIGNMENT_CENTER, true)
	skills = Control.new()
	skills.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(skills)
	for i in 2:
		var x: float = [715.4, 845.8][i]
		var width: float = [102.4, 108.8][i]
		skill_frame.append(panel_at(skills, Rect2(x, 796.2, width, 96.8), Color("332318"), Color("ffb841"), 3, 12))
		skill_art.append(app.picture(skills, null, Rect2(x + 4, 799.4, width - 8, 90.4)))
		skill_art[i].stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		panel_at(skills, Rect2(x + 4, 867.8, width - 8, 22), Color(0, 0, 0, 0.5), Color.TRANSPARENT, 0, 4)
		var sp := text_at(skills, "%dSP" % (i + 2), Rect2(x + width - 59, 798.2, 53, 27), 17, Color("fff0d2"), HORIZONTAL_ALIGNMENT_RIGHT, true)
		apply_skill_outline(sp)
		var value := text_at(skills, "", Rect2(x + 4, 867.8, width - 8, 22), 16, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
		apply_skill_outline(value)
		skill_value.append(value)
	chain_lock = picture(skills, "roster-lock.svg", Rect2(929.6, 841.8, 19, 24))

func make_roster() -> void:
	var top := (DESIGN.y - PANEL_HEIGHT) * 0.5
	panel_at(board, Rect2(ROSTER_X + 5, top + 5, ROSTER_WIDTH - 10, PANEL_HEIGHT - 10), Color(0.16, 0.14, 0.10, 0.78), Color.TRANSPARENT, 0, 25)
	roster_frame = NinePatchRect.new()
	roster_frame.texture = preload("res://assets/ui/hero-level-up/roster-wood-frame.png")
	roster_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	roster_frame.draw_center = false
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		roster_frame.set_patch_margin(side, 48)
	place(board, roster_frame, Rect2(ROSTER_X, top, ROSTER_WIDTH, PANEL_HEIGHT))
	roster_frame.name = "HeroRosterFrame"
	roster_scroll = ScrollContainer.new()
	var scroll := roster_scroll
	scroll.name = "HeroRoster"
	scroll.clip_contents = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	place(board, scroll, Rect2(ROSTER_X + 20, top + 20, 240, 392))
	var content := Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var recruit := action(board, Rect2(ROSTER_X + 20, top + 432, 240, 68), "RecruitHero", Callable())
	make_wood_button(recruit, "모집")
	recruit.disabled = true # Recruitment rules are not part of this patch.
	recruit.modulate.a = 0.62
	var rows := ceili(float(maxi(0, DATA.size() - 3)) / 2.0)
	content.custom_minimum_size = Vector2(240, maxf(240.0, 250.0 + rows * 124.0 - 8.0))
	scroll.add_child(content)
	if DATA.size() > 3:
		panel_at(content, Rect2(0, 244, 240, 2), Color("a78e5a99")).name = "HeroRosterDivider"
	for i in DATA.size():
		var offset := i if i < 3 else i - 3
		var at := Vector2((offset % 2) * 124, floori(float(offset) / 2.0) * 124 + (250 if i >= 3 else 0))
		var card := action(content, Rect2(at, Vector2(116, 116)), "HeroCard" + str(i), choose.bind(i))
		card.set_meta("semantic_text", DATA[i][0])
		roster.append(card)
		var portrait := picture(card, str(DATA[i][1]) + "-portrait-original.png", Rect2(4.5, 4.5, 107, 107), TextureRect.STRETCH_KEEP_ASPECT_COVERED)
		portrait.name = "Portrait"
		var band := panel_at(card, Rect2(4.5, 84.5, 107, 27), Color(0, 0, 0, 0.8), Color.TRANSPARENT, 0, 5)
		band.name = "NameBand"
		text_at(band, DATA[i][0], Rect2(0, 0, 107, 27), 20, Color("f9e6c3"), HORIZONTAL_ALIGNMENT_CENTER, true)
		panel_at(card, Rect2(7.5, 7.5, 26, 26), Color(0.13, 0.09, 0.05, 0.90), Color("edb85e"), 1, 5)
		var badge := app.picture(card, Readiness.role_texture(DATA[i][3]), Rect2(9.5, 9.5, 22, 22)) as TextureRect
		badge.name = "RoleBadge"
		badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		roster_roles.append(badge)
		var lock := app.picture(card, GOLD_LOCK, Rect2(84.5, 9.5, 22, 22)) as TextureRect
		lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		locks.append(lock)
	swipe_card_hint = panel_at(content, Rect2(Vector2.ZERO,Vector2(116,116)),Color.TRANSPARENT,Color("ffd283"),3,11)
	swipe_card_hint.name = "SwipeNextCardHint"
	swipe_card_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swipe_card_hint.hide()

func refresh() -> void:
	var state: Dictionary = app.model.state
	navigable.clear()
	for i in roster.size():
		var unlocked := HeroGrowth.owns(state, HeroGrowth.HEROES[i])
		if unlocked or i >= 3: navigable.append(i)
		var active := i == selected
		var card := roster[i]
		card.disabled = not unlocked and i < 3
		card.get_node("Portrait").modulate.a = 1.0 if unlocked else 0.48 if i >= 3 else 0.75
		locks[i].visible = not unlocked
		var edge := style(Color("33271b") if unlocked else Color("333638"), Color("ffbe50") if active else Color("94704b") if unlocked else Color("888b8c"), 4 if active else 3, 13)
		if active:
			edge.shadow_color = Color("f6a345b2")
			edge.shadow_size = 6
		for button_state in ["normal", "hover", "pressed", "disabled"]:
			card.add_theme_stylebox_override(button_state, edge)
	previous.disabled = navigable.size() < 2
	forward.disabled = previous.disabled
	set_nav_opacity(nav_opacity)

	var id: String = HeroGrowth.HEROES[selected]
	var progress := HeroGrowth.read(state, id)
	var limit := HeroGrowth.MAX_LEVEL
	var has_next: bool = int(progress.level) < limit
	var need := HeroGrowth.needed_at(progress.level) if has_next else 0
	var stats := HeroGrowth.stats_at(id, progress.level)
	var next_stats := HeroGrowth.stats_at(id, progress.level + 1) if has_next else stats
	level_text.text = "Lv. %d/%d" % [progress.level, limit]
	xp_text.text = "%d / %d XP" % [progress.xp, need] if need > 0 else ""
	remaining_text.text = "%d XP 남음" % maxi(0, need - progress.xp) if need > 0 else "최대 레벨"
	var fraction := clampf(float(progress.xp) / need, 0.0, 1.0) if need > 0 else 1.0
	xp_fill.size.x = 249 * fraction
	xp_fill.visible = fraction > 0.0
	meat_text.text = "보유 %d" % int(state.get("meat", 0))
	for i in 3:
		var key: String = HeroGrowth.STATS[i]
		before_text[i].text = str(stats[key])
		after_text[i].text = str(next_stats.get(key, "—"))
		after_text[i].add_theme_color_override("font_color", Color("a9dd70") if has_next else Color("ffe8bc"))
	upgrade.disabled = not HeroGrowth.can_feed(state, id)
	upgrade.modulate.a = 0.62 if upgrade.disabled else 1.0

	var hero: Array = DATA[selected]
	hero_name.text = hero[0]
	role_name.text = hero[2]
	role_art.texture = Readiness.role_texture(hero[3])
	var preview_only := selected >= 3 and not HeroGrowth.owns(state, id)
	if preview_only:
		level_text.text = "미획득"
		xp_text.text = "—"
		remaining_text.text = ""
		xp_fill.hide()
		for i in 3:
			before_text[i].text = "—"
			after_text[i].text = "—"
	if PREVIEW_SKILLS.has(selected):
		var preview: Array = PREVIEW_SKILLS[selected]
		for i in preview.size():
			skill_art[i].texture = preview[i][0]
			skill_value[i].text = preview[i][1]
			skill_art[i].modulate.a = 1.0
			skill_value[i].modulate.a = 1.0
		skill_frame[1].add_theme_stylebox_override("panel", style(Color("332318"), Color("ffb841"), 4, 16))
		chain_lock.hide()
		if upgrade.disabled: stop_hold()
		return
	skill_art[0].texture = load(ART + str(hero[1]) + "-2sp.png")
	skill_art[1].texture = load(ART + str(hero[4]))
	skill_value[0].text = "피해 %d" % int(stats.skill)
	match selected:
		0: skill_value[1].text = "피해 %d" % int(stats.chain)
		1: skill_value[1].text = "반격 피해 %d" % int(stats.chain)
		2: skill_value[1].text = "공격 +20% · 5초"
	var chain_available: bool = selected != 0 or app.chapter_one_story_completions().get("ch1-01", false)
	chain_lock.visible = not chain_available
	skill_frame[1].add_theme_stylebox_override("panel", style(Color("332318") if chain_available else Color("202329"), Color("ffb841") if chain_available else Color("85888b"), 4, 16))
	skill_art[1].modulate.a = 1.0 if chain_available else 0.78
	skill_value[1].modulate.a = skill_art[1].modulate.a
	if upgrade.disabled: stop_hold()

func set_nav_opacity(value: float) -> void:
	nav_opacity = value
	previous.modulate.a = value * (0.4 if previous.disabled else 1.0)
	forward.modulate.a = value * (0.4 if forward.disabled else 1.0)

func show_nav_hints() -> void:
	if arrow_fade: arrow_fade.kill()
	set_nav_opacity(1.0)
	arrow_fade = create_tween()
	arrow_fade.tween_interval(2.0)
	arrow_fade.tween_method(set_nav_opacity, 1.0, 0.12, 0.26)

func cycle(direction: int, fixed_forest := false) -> void:
	if navigable.size() < 2: return
	show_nav_hints()
	var current := navigable.find(selected)
	choose(navigable[posmod(current + direction, navigable.size())], direction, fixed_forest)

func choose(index: int, direction := 0, fixed_forest := false) -> void:
	if index == selected or index not in navigable: return
	if swipe_follow_hero:
		choose_valley(index, direction)
		return
	stop_hold()
	reset_swipe()
	stop_hero_motion()
	active_foreground.hide()
	cancel_celebration()
	if slide:
		slide.kill()
		active_scene.position.x = 0.0
	if is_instance_valid(outgoing_scene): outgoing_scene.queue_free()
	outgoing_scene = active_scene
	var sign_dir := signi(index - selected) if direction == 0 else direction
	selected = index
	make_scene()
	fit()
	refresh()
	if fixed_forest:
		outgoing_scene.hide()
		outgoing_scene.queue_free()
		var entry := Vector2(sign_dir * 155.0, 0.0)
		present_swipe_actor(entry.x, 0.0)
		swipe_scene_tween = create_tween()
		swipe_scene_tween.tween_method(animate_swipe_actor.bind(entry.x), 0.0, 1.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		return
	var span := size.x / board.scale.x
	active_scene.position.x = sign_dir * span
	var departing := outgoing_scene
	slide = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	slide.tween_property(departing, "position:x", -sign_dir * span, 0.28)
	slide.tween_property(active_scene, "position:x", 0.0, 0.28)
	slide.chain().tween_callback(departing.queue_free)

func valley_wrapping(index: int, direction: int) -> bool:
	return (direction < 0 and selected == navigable.front() and index == navigable.back()) or (direction > 0 and selected == navigable.back() and index == navigable.front())

func valley_shift_target(index: int, direction: int) -> float:
	return float(selected + direction) if valley_wrapping(index, direction) else float(index)

func set_valley_mist_phase(value: float) -> void:
	valley_mist_phase = value
	fit_valley()

func choose_valley(index: int, direction: int) -> void:
	if valley_anim and valley_anim.is_running(): return
	stop_hold()
	swipe = NONE
	swipe_moved = false
	if valley_anim: valley_anim.kill()
	clear_valley_departure()
	var sign_dir := signi(index - selected) if direction == 0 else direction
	if not is_instance_valid(active_foreground) or not active_foreground.visible:
		finish_valley_switch(index, sign_dir)
		return
	# A brief exit also handles fast swipes, arrows, and direct roster selection.
	var exit := active_foreground.position.x - sign_dir * valley_viewport.size.x * 0.15
	var initial := active_foreground.position.x
	var opacity := active_foreground.modulate.a
	valley_anim = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	valley_anim.tween_method(func(t: float): present_swipe_actor(lerpf(initial, exit, t), lerpf(opacity, 0.0, t)), 0.0, 1.0, 0.14)
	valley_anim.tween_method(set_valley_camera, valley_camera, lerpf(valley_camera, valley_shift_target(index, sign_dir), 0.55), 0.14)
	valley_anim.chain().tween_callback(finish_valley_switch.bind(index, sign_dir))

func finish_valley_switch(index: int, direction: int) -> void:
	# There is only one hero node. The old one is hidden before the new one exists.
	stop_hero_motion()
	active_scene.hide()
	active_scene.queue_free()
	cancel_celebration()
	var wrapping := valley_wrapping(index, direction)
	if wrapping: valley_mist_phase = clampf(valley_camera, 0.0, float(DATA.size()-1))
	selected = index
	var next_group := valley_group_for(selected)
	if next_group != valley_group:
		# Old hero is gone; change sections before revealing the next hero.
		capture_valley_departure()
		valley_group = next_group
		valley_camera = float(index) - float(direction) * 0.10
	make_scene()
	fit()
	refresh()
	var entry := direction * valley_viewport.size.x * 0.21
	present_swipe_actor(entry, 0.0)
	valley_anim = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if is_instance_valid(valley_departing):
		# The only region dissolve happens following a committed gesture, on an empty scene.
		valley_anim.tween_property(valley_departing, "modulate:a", 0.0, 0.30)
		if wrapping: valley_anim.parallel().tween_method(set_valley_mist_phase, valley_mist_phase, float(index), 0.30)
		valley_anim.tween_callback(clear_valley_departure)
	if wrapping: valley_anim.tween_callback(set_valley_mist_phase.bind(-1.0))
	valley_anim.tween_method(animate_swipe_actor.bind(entry), 0.0, 1.0, 0.42)
	valley_anim.parallel().tween_method(set_valley_camera, valley_camera, float(index), 0.42)

func valley_neighbor(direction: int) -> int:
	var current := navigable.find(selected)
	if current < 0 or navigable.size() < 2: return -1
	return navigable[posmod(current + direction, navigable.size())]

func valley_drag(movement: Vector2) -> void:
	var direction := 1 if movement.x < 0 else -1
	var target := valley_neighbor(direction)
	if not is_horizontal_swipe(movement) or target < 0:
		set_valley_camera(float(selected))
		present_swipe_actor(0.0, 1.0)
		return
	var w := maxf(1.0, valley_viewport.size.x)
	var distance := clampf(absf(movement.x) / w, 0.0, 0.5)
	set_valley_camera(lerpf(float(selected), valley_shift_target(target, direction), 0.9 * minf(1.0, distance / 0.46)))
	# The hero follows faster than the valley; the rest of the UI never moves.
	present_swipe_actor(clampf(movement.x * 1.28, -w * 0.62, w * 0.62), 1.0 - smoothstep(0.22, 0.43, distance))

func cancel_valley_drag() -> void:
	if nav_opacity == 1.0: show_nav_hints()
	if valley_anim: valley_anim.kill()
	if not is_instance_valid(active_foreground): return
	var initial := active_foreground.position.x
	var opacity := active_foreground.modulate.a
	valley_anim = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	valley_anim.tween_method(func(t: float): present_swipe_actor(lerpf(initial, 0.0, t), lerpf(opacity, 1.0, t)), 0.0, 1.0, 0.24)
	valley_anim.tween_method(set_valley_camera, valley_camera, float(selected), 0.24)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not app.application_active or app.modal: return
	if event is InputEventScreenTouch:
		if handle_roster_touch(event): return
		if event.canceled:
			if held == event.index: stop_hold()
			if swipe == event.index:
				if swipe_follow_hero:
					swipe = NONE
					swipe_moved = false
					cancel_valley_drag()
				else:
					reset_swipe()
			return
		pointer(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		if handle_roster_drag(event): return
		pointer_drag(event.index, event.position)
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		pointer_drag(-1, event.position)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
		pointer(-1, event.position, event.pressed)

func handle_roster_touch(event: InputEventScreenTouch) -> bool:
	if event.pressed and roster_touch == NONE and roster_scroll.get_global_rect().has_point(event.position):
		roster_touch = event.index
		roster_touch_start = event.position
		roster_scroll_start = roster_scroll.scroll_vertical
		roster_dragging = false
	elif not event.pressed and event.index == roster_touch:
		var consumed := roster_dragging or event.canceled
		roster_touch = NONE
		roster_dragging = false
		if consumed:
			for card in roster: card.clear()
			get_viewport().set_input_as_handled()
		return consumed
	return false

func handle_roster_drag(event: InputEventScreenDrag) -> bool:
	if event.index != roster_touch: return false
	var delta := (event.position - roster_touch_start) / board.scale.x
	if not roster_dragging and absf(delta.y) >= 14.0 and absf(delta.y) >= absf(delta.x):
		roster_dragging = true
		for card in roster: card.clear()
	if not roster_dragging: return false
	roster_scroll.scroll_vertical = roster_scroll_start - roundi(delta.y)
	get_viewport().set_input_as_handled()
	return true

func pointer(index: int, point: Vector2, pressed: bool) -> void:
	if pressed and upgrade.get_global_rect().has_point(point):
		if held == NONE and not upgrade.disabled:
			held = index
			hold_seconds = 0.0
			repeats_in = REPEAT_SECONDS
			feed()
			set_process(held != NONE)
		get_viewport().set_input_as_handled()
	elif not pressed and held == index:
		stop_hold()
		get_viewport().set_input_as_handled()
	elif pressed and swipe == NONE and is_swipe_origin(point):
		if swipe_follow_hero and valley_anim and valley_anim.is_running(): return
		swipe = index
		swipe_start = point
		swipe_can_activate = HERO_INTERACTION.has_point(board.get_global_transform().affine_inverse() * point)
		swipe_moved = false
		get_viewport().set_input_as_handled()
	elif not pressed and swipe == index:
		var movement := swipe_delta(point)
		var was_drag := swipe_moved
		if nav_opacity == 1.0: show_nav_hints()
		if swipe_follow_hero:
			swipe = NONE
			swipe_moved = false
			var direction := 1 if movement.x < 0 else -1
			var target := valley_neighbor(direction)
			if target >= 0 and absf(movement.x) > maxf(SWIPE_COMMIT, valley_viewport.size.x * 0.09) and is_horizontal_swipe(movement):
				choose(target, direction)
			elif swipe_can_activate and not was_drag and movement.length() < SWIPE_SLOP:
				set_valley_camera(float(selected))
				present_swipe_actor(0.0, 1.0)
				play_hero_motion(true)
			else:
				cancel_valley_drag()
			get_viewport().set_input_as_handled()
			return
		reset_swipe()
		if absf(movement.x) > SWIPE_COMMIT and is_horizontal_swipe(movement):
			cycle(1 if movement.x < 0 else -1, swipe_follow_hero)
		elif swipe_can_activate and not was_drag and movement.length() < SWIPE_SLOP and is_instance_valid(hero_video):
			play_hero_motion(true)
		get_viewport().set_input_as_handled()

func is_swipe_origin(point: Vector2) -> bool:
	var local := board.get_global_transform().affine_inverse() * point
	if not valley_viewport.has_point(local): return false
	# Native scrolling and click targets must see the initial pointer event.
	if roster_frame.get_global_rect().has_point(point): return false
	for button in [back_button, previous, forward, debug_growth_reset, bag_button]:
		if button.is_visible_in_tree() and button.get_global_rect().has_point(point): return false
	return true

func swipe_delta(point: Vector2) -> Vector2:
	return (point - swipe_start) / board.scale.x

func is_horizontal_swipe(movement: Vector2) -> bool:
	return absf(movement.x) > absf(movement.y) * 1.2

func pointer_drag(index: int, point: Vector2) -> void:
	if swipe != index: return
	var movement := swipe_delta(point)
	swipe_moved = swipe_moved or movement.length() >= SWIPE_SLOP
	if swipe_follow_hero:
		if absf(movement.x) >= SWIPE_PREVIEW_SLOP:
			if is_horizontal_swipe(movement):
				if arrow_fade: arrow_fade.kill()
				set_nav_opacity(1.0)
			valley_drag(movement)
		else:
			set_valley_camera(float(selected))
			present_swipe_actor(0.0, 1.0)
		get_viewport().set_input_as_handled()
		return
	clear_swipe_hint()
	if navigable.size() > 1 and absf(movement.x) > SWIPE_SLOP and is_horizontal_swipe(movement):
		var direction := 1 if movement.x < 0 else -1
		if swipe_follow_hero:
			var shift := clampf(movement.x, -205.0, 205.0)
			var opacity := 1.0 - smoothstep(38.0, 175.0, absf(shift))
			present_swipe_actor(shift, opacity)
			get_viewport().set_input_as_handled()
			return
		var arrow := forward_arrow if direction > 0 else previous_arrow
		var progress := clampf((absf(movement.x) - SWIPE_SLOP) / (SWIPE_COMMIT - SWIPE_SLOP), 0.0, 1.0)
		arrow.position.x = 12.0 + signf(movement.x) * 12.0 * progress
		arrow.modulate = Color.WHITE.lerp(GOLD,progress)
		var candidate := navigable[posmod(navigable.find(selected) + direction, navigable.size())]
		swipe_card_hint.position = roster[candidate].position
		swipe_card_hint.modulate.a = 0.30 + 0.70 * progress
		swipe_card_hint.show()
	get_viewport().set_input_as_handled()

func present_swipe_actor(offset: float, opacity: float) -> void:
	if not is_instance_valid(active_foreground): return
	active_foreground.position.x = offset
	active_foreground.modulate.a = opacity
	if not swipe_follow_hero and is_instance_valid(fold_material):
		fold_material.set_shader_parameter("drag_opacity",opacity)
	active_foreground.visible = opacity > 0.001

func animate_swipe_actor(progress: float, start_x: float) -> void:
	present_swipe_actor(lerpf(start_x, 0.0, progress), progress)

func clear_swipe_hint() -> void:
	if swipe_follow_hero:
		if swipe_scene_tween and swipe_scene_tween.is_running(): swipe_scene_tween.kill()
		if valley_anim: valley_anim.kill()
		clear_valley_departure()
		valley_mist_phase = -1.0
		set_valley_camera(float(selected))
		present_swipe_actor(0.0, 1.0)
	for arrow in [previous_arrow, forward_arrow]:
		if is_instance_valid(arrow):
			arrow.position.x = 12.0
			arrow.modulate = Color.WHITE
	if is_instance_valid(swipe_card_hint): swipe_card_hint.hide()

func reset_swipe() -> void:
	swipe = NONE
	swipe_moved = false
	clear_swipe_hint()

func _process(delta: float) -> void:
	if not app.application_active or not is_visible_in_tree() or app.modal or held == NONE:
		stop_hold()
		return
	hold_seconds = minf(hold_seconds + delta, FEED_RAMP_SECONDS)
	repeats_in -= delta
	if repeats_in <= 0.00001:
		var ramp := smoothstep(0.0, 1.0, hold_seconds / FEED_RAMP_SECONDS)
		var interval := REPEAT_SECONDS / lerpf(1.0, FEED_TOP_SPEED, ramp)
		# Preserve sub-frame timing, but never burst multiple charges after a stalled frame.
		repeats_in = maxf(interval * 0.5, repeats_in + interval)
		var progress := HeroGrowth.read(app.model.state, HeroGrowth.HEROES[selected])
		var amount := roundi(lerpf(1.0, float(HeroGrowth.fast_feed_cap(progress.level)), ramp))
		feed(amount)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_EXIT_TREE]:
		reset_swipe()
		roster_touch = NONE
		roster_dragging = false
		for card in roster: card.clear()
		stop_hold()
		if is_instance_valid(hero_video): hero_video.paused = true
	elif what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN]:
		if is_instance_valid(hero_video): hero_video.paused = false

func stop_hold() -> void:
	held = NONE
	hold_seconds = 0.0
	set_process(false)

func feed(amount: int = 1) -> void:
	var result: Dictionary = app.model.feed_hero(HeroGrowth.HEROES[selected], amount)
	if result.is_empty():
		stop_hold()
		return
	if result.after.level > result.before.level:
		cancel_celebration()
		var id: String = HeroGrowth.HEROES[selected]
		var from := HeroGrowth.stats_at(id, result.before.level)
		var to := HeroGrowth.stats_at(id, result.after.level)
		celebration_text.text = "Lv. %d 달성 · 체력 %+d · 공격 %+d · 스킬 %+d" % [result.after.level, to.hp - from.hp, to.attack - from.attack, to.skill - from.skill]
		celebration_text.modulate.a = 1.0
		celebration_text.pivot_offset = celebration_text.size * 0.5
		celebration_text.scale = Vector2.ONE * 0.93
		celebration_text.show()
		celebration = create_tween()
		celebration.tween_property(celebration_text, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		celebration.tween_interval(1.42)
		celebration.tween_property(celebration_text, "modulate:a", 0.0, 0.3)
		celebration.tween_callback(celebration_text.hide)

func cancel_celebration() -> void:
	if celebration: celebration.kill()
	celebration_text.hide()

func place(parent: Control, node: Control, rect: Rect2) -> void:
	parent.add_child(node)
	node.position = rect.position
	node.size = rect.size

func picture(parent: Control, file: String, rect: Rect2, stretch := TextureRect.STRETCH_KEEP_ASPECT_CENTERED) -> TextureRect:
	var node: TextureRect = app.picture(parent, load(ART + file), rect)
	node.stretch_mode = stretch
	return node

func text_at(parent: Control, value: String, rect: Rect2, font_size: int, color := CREAM, alignment := HORIZONTAL_ALIGNMENT_LEFT, heavy := false) -> Label:
	var label := FigmaArt.text(parent, value, rect, font_size, bold if heavy else FigmaArt.NOTO, color, false)
	label.horizontal_alignment = alignment
	return label

func style(fill: Color, edge: Color, border: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(border)
	box.set_corner_radius_all(radius)
	return box

func panel_at(parent: Control, rect: Rect2, fill: Color, edge := Color.TRANSPARENT, border := 0, radius := 0) -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", style(fill, edge, border, radius))
	place(parent, panel, rect)
	return panel

func action(parent: Control, rect: Rect2, key: String, callback: Callable) -> Button:
	var button := DemoButton.new()
	button.name = key
	button.custom_minimum_size = Vector2.ZERO
	for button_state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(button_state, StyleBoxEmpty.new())
	if callback.is_valid(): button.pressed.connect(callback)
	place(parent, button, rect)
	return button
