extends Control

const ART := "res://assets/ui/hero-level-up/"
const DESIGN := Vector2(1670, 941)
const CREAM := Color("f8e2ad")
const GOLD := Color("ffd283")
const DARK := Color(0.16, 0.14, 0.10, 0.82)
const REPEAT_SECONDS := 0.25
const NONE := -2
const HERO_INTERACTION := Rect2(679, 100, 413, 560)
const MOTION_SIZE := Vector2(1280, 720)
const PANEL_HEIGHT := 639.0
const GOLD_LOCK := preload("res://assets/ui/d0024/08-ui-padlock-gold.png")
const FOLD_SHADER := preload("res://shaders/hero_landscape_feather.gdshader")
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
		"size": Vector2(1280, 720), "anchor": Vector2(630, 495), "stature": 315.0,
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
var previous: Button
var forward: Button
var hero_name: Label
var role_name: Label
var role_art: TextureRect
var skills: Control
var skill_art: Array[TextureRect] = []
var skill_value: Array[Label] = []
var skill_frame: Array[Panel] = []
var chain_lock: TextureRect
var celebration_text: Label
var held := NONE
var swipe := NONE
var swipe_start := Vector2.ZERO
var repeats_in := REPEAT_SECONDS
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
	make_scene()
	make_header()
	make_growth()
	make_hero_details()
	make_roster()
	app.model.changed.connect(refresh)
	resized.connect(fit)
	fit()
	refresh()
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
	var hud_margin := Vector2(maxf(57.0 * factor, safe.x), maxf(48.0 * factor, safe.y))
	back_button.position = (hud_margin - board.position) / factor
	screen_title.position = back_button.position + Vector2(96, (back_button.size.y - screen_title.size.y) * 0.5)
	if is_instance_valid(hero_video):
		fit_hero_motion(viewport)
	if is_instance_valid(outgoing_scene):
		var background := outgoing_scene.get_child(0) as TextureRect
		background.position = viewport.position
		background.size = viewport.size

func fit_hero_motion(viewport: Rect2) -> void:
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

func make_scene() -> void:
	active_scene = Control.new()
	active_scene.name = "HeroAndLandscape"
	active_scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_view.add_child(active_scene)
	active_background = picture(active_scene, "background-landscape-reconstructed.png", Rect2(Vector2.ZERO, DESIGN), TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	active_foreground = Control.new()
	active_foreground.name = "HeroForeground"
	active_foreground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	active_scene.add_child(active_foreground)
	if selected < MOTIONS.size():
		make_hero_motion()

func make_hero_motion() -> void:
	fold_material = ShaderMaterial.new()
	fold_material.shader = FOLD_SHADER
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
	play_hero_motion(true)

func play_hero_motion(action: bool, mode_changed := false) -> void:
	if not is_instance_valid(hero_video): return
	var player := hero_video
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

func show_hero_when_ready(player: VideoStreamPlayer, generation: int) -> void:
	while is_instance_valid(player) and player == hero_video and generation == motion_generation:
		if player.stream_position >= 2.0 / 24.0:
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
	back_button = action(board, Rect2(57, 48, 80, 80), "Back", app.go_back)
	app.picture(back_button, BACK, Rect2(0, 0, 80, 80))
	screen_title = text_at(board, "영웅 레벨업", Rect2(153, 55, 333, 66), 46, Color("ffe2a7"), HORIZONTAL_ALIGNMENT_LEFT, true)

func make_growth() -> void:
	var frame := Panel.new()
	frame.name = "GrowthPanel"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(board, frame, Rect2(80, (DESIGN.y - PANEL_HEIGHT) * 0.5, 424, PANEL_HEIGHT))
	panel_at(frame, Rect2(5, 5, 414, PANEL_HEIGHT - 10.0), DARK, Color("76502f"), 5, 20)
	picture(frame, "growth-wood-frame.png", Rect2(0, 0, 424, PANEL_HEIGHT))
	text_at(frame, "성장 미리보기", Rect2(35, 27, 230, 35), 25, Color("f7d499"), HORIZONTAL_ALIGNMENT_LEFT, true)
	text_at(frame, "수치 검수 가안", Rect2(244, 27, 149, 35), 17, Color("f7d499"), HORIZONTAL_ALIGNMENT_RIGHT)
	level_text = text_at(frame, "", Rect2(34, 73, 230, 52), 38, GOLD, HORIZONTAL_ALIGNMENT_LEFT, true)
	level_text.name = "LevelAndCap"
	text_at(frame, "현재 경험치", Rect2(34, 138, 100, 29), 18)
	xp_text = text_at(frame, "", Rect2(138, 138, 126, 29), 18, Color("f6ce78"), HORIZONTAL_ALIGNMENT_LEFT, true)
	remaining_text = text_at(frame, "", Rect2(273, 138, 120, 29), 18, CREAM, HORIZONTAL_ALIGNMENT_RIGHT)
	panel_at(frame, Rect2(33, 171, 359, 20), Color("1c160c"), Color("966336"), 2, 9)
	xp_fill = panel_at(frame, Rect2(37, 175, 0, 11), Color("e9ba66"), Color("ffe6aa"), 1, 6)
	for i in 3:
		var y: int = [217, 275, 330][i]
		text_at(frame, ["체력", "기본 공격", "스킬 피해"][i], Rect2(34, y, 146, 43), 24)
		before_text.append(text_at(frame, "", Rect2(189, y, 93, 43), 24, Color("ffe8bc"), HORIZONTAL_ALIGNMENT_RIGHT, true))
		text_at(frame, "→", Rect2(300, y, 32, 43), 23, Color("f0bb52"), HORIZONTAL_ALIGNMENT_CENTER, true)
		after_text.append(text_at(frame, "", Rect2(337, y, 56, 43), 24, Color("a9dd70"), HORIZONTAL_ALIGNMENT_RIGHT, true))
		panel_at(frame, Rect2(34, [267, 323, 381][i], 359, 1), Color("9e80507a"))
	app.picture(frame, DemoArt.icon("meat"), Rect2(40, 406, 55, 46))
	text_at(frame, "고기", Rect2(104, 410, 52, 35), 22)
	panel_at(frame, Rect2(162, 408, 136, 43), Color("322010e6"), Color("a8844b"), 2, 12)
	meat_text = text_at(frame, "", Rect2(166, 408, 128, 43), 21, Color("ffcc75"), HORIZONTAL_ALIGNMENT_CENTER)
	meat_text.name = "MeatBalance"
	# Figma's inner lip is y=777 and the visual bottom of the CTA is y=757.
	upgrade = action(frame, Rect2(34, 517, 358, 84), "FeedHero", Callable())
	picture(upgrade, "levelup-wood-cta-blank.png", Rect2(0, 0, 358, 84))
	text_at(upgrade, "레벨업", Rect2(0, 0, 358, 84), 39, Color("371c06"), HORIZONTAL_ALIGNMENT_CENTER, true)
	upgrade.focus_mode = Control.FOCUS_NONE
	celebration_text = text_at(frame, "", Rect2(36, 451, 352, 53), 24, GOLD, HORIZONTAL_ALIGNMENT_CENTER, true)
	celebration_text.name = "LevelUpCelebration"
	celebration_text.hide()

func make_hero_details() -> void:
	previous = action(board, Rect2(609, 377, 60, 81), "PreviousHero", cycle.bind(-1))
	forward = action(board, Rect2(1098, 377, 60, 81), "NextHero", cycle.bind(1))
	picture(previous, "carousel-left.svg", Rect2(12, 11, 36, 59))
	picture(forward, "carousel-right.svg", Rect2(12, 11, 36, 59))
	picture(board, "name-divider.svg", Rect2(625, 687, 506, 45))
	hero_name = text_at(board, "", Rect2(650, 666, 104, 52), 43, Color("ffdaa2"), HORIZONTAL_ALIGNMENT_RIGHT, true)
	panel_at(board, Rect2(781, 677, 2, 33), Color("bf8b4acc"))
	panel_at(board, Rect2(810, 674, 134, 44), Color("463215e6"), Color("a8844b"), 2, 12)
	role_art = app.picture(board, null, Rect2(802, 668, 54, 54))
	role_name = text_at(board, "", Rect2(865, 675, 74, 41), 23, Color("ffe3ae"), HORIZONTAL_ALIGNMENT_CENTER, true)
	skills = Control.new()
	skills.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(skills)
	text_at(skills, "스킬", Rect2(653, 757, 101, 48), 39, Color("f1c573"), HORIZONTAL_ALIGNMENT_RIGHT, true)
	panel_at(skills, Rect2(756, 769, 2, 80), Color("bf8b4acc"))
	for i in 2:
		var x: int = [782, 938][i]
		var width: int = [128, 136][i]
		skill_frame.append(panel_at(skills, Rect2(x, 748, width, 121), Color("332318"), Color("ffb841"), 4, 16))
		skill_art.append(app.picture(skills, null, Rect2(x + 5, 752, width - 10, 113)))
		skill_art[i].stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		text_at(skills, "%dSP" % (i + 2), Rect2(x + width - 66, 750, 52, 32), 19, Color("fff0d2"), HORIZONTAL_ALIGNMENT_RIGHT, true)
		skill_value.append(text_at(skills, "", Rect2(x - 12, 873, width + 24, 38), 22, CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	chain_lock = picture(skills, "roster-lock.svg", Rect2(1044, 837, 19, 24))

func make_roster() -> void:
	var top := (DESIGN.y - PANEL_HEIGHT) * 0.5
	panel_at(board, Rect2(1232, top + 5, 340, PANEL_HEIGHT - 10), Color(0.16, 0.14, 0.10, 0.78), Color("76502f"), 5, 20)
	var frame := NinePatchRect.new()
	frame.texture = preload("res://assets/ui/hero-level-up/roster-wood-frame.png")
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.draw_center = false
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		frame.set_patch_margin(side, 48)
	place(board, frame, Rect2(1227, top, 350, PANEL_HEIGHT))
	frame.name = "HeroRosterFrame"
	picture(board, "allied-heading.svg", Rect2(1259, top + 7, 28, 31))
	text_at(board, "아군", Rect2(1297, top + 4, 124, 36), 26, Color("f6d38d"), HORIZONTAL_ALIGNMENT_LEFT, true)
	var scroll := ScrollContainer.new()
	scroll.name = "HeroRoster"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	place(board, scroll, Rect2(1248, top + 41, 314, PANEL_HEIGHT - 43))
	var content := Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.custom_minimum_size = Vector2(312, 596)
	scroll.add_child(content)
	panel_at(content, Rect2(4, 394, 296, 2), Color("a78e5a99")).name = "HeroRosterDivider"
	for i in DATA.size():
		var at: Vector2 = [Vector2(4,1), Vector2(160,1), Vector2(4,194), Vector2(4,405), Vector2(160,405)][i]
		var card := action(content, Rect2(at, Vector2(146, 191)), "HeroCard" + str(i), choose.bind(i))
		card.set_meta("semantic_text", DATA[i][0])
		roster.append(card)
		var portrait := picture(card, str(DATA[i][1]) + "-portrait-original.png", Rect2(6, 5, 134, 141), TextureRect.STRETCH_KEEP_ASPECT_COVERED)
		portrait.name = "Portrait"
		var band := panel_at(card, Rect2(5, 147, 136, 39), Color("35281c"), Color.TRANSPARENT, 0, 6)
		band.name = "NameBand"
		text_at(band, DATA[i][0], Rect2(0, 0, 136, 39), 25, Color("f9e6c3"), HORIZONTAL_ALIGNMENT_CENTER, true)
		if i >= 3:
			var lock := app.picture(card, GOLD_LOCK, Rect2(104, 113, 35, 32)) as TextureRect
			lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			locks.append(lock)
		else:
			locks.append(picture(card, "roster-lock.svg", Rect2(118, 125, 19, 24)))

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
		card.get_node("NameBand").add_theme_stylebox_override("panel", style(Color("35281c") if unlocked else Color("202224"), Color.TRANSPARENT, 0, 6))
		locks[i].visible = not unlocked
		var edge := style(Color("33271b") if unlocked else Color("333638"), Color("ffbe50") if active else Color("94704b") if unlocked else Color("888b8c"), 4 if active else 3, 13)
		if active:
			edge.shadow_color = Color("f6a345b2")
			edge.shadow_size = 6
		for button_state in ["normal", "hover", "pressed", "disabled"]:
			card.add_theme_stylebox_override(button_state, edge)
	previous.disabled = navigable.size() < 2
	forward.disabled = previous.disabled
	previous.modulate.a = 0.4 if previous.disabled else 1.0
	forward.modulate.a = previous.modulate.a

	var id: String = HeroGrowth.HEROES[selected]
	var progress := HeroGrowth.read(state, id)
	var limit := HeroGrowth.MAX_LEVEL
	var has_next: bool = int(progress.level) < limit
	var need := HeroGrowth.needed_at(progress.level) if has_next else 0
	var stats := HeroGrowth.stats_at(id, progress.level)
	var next_stats := HeroGrowth.stats_at(id, progress.level + 1) if has_next else {}
	level_text.text = "Lv. %d/%d" % [progress.level, limit]
	xp_text.text = "%d / %s XP" % [progress.xp, str(need) if need > 0 else "—"]
	remaining_text.text = "%d XP 남음" % maxi(0, need - progress.xp) if need > 0 else "최대 레벨"
	var fraction := clampf(float(progress.xp) / need, 0.0, 1.0) if need > 0 else 1.0
	xp_fill.size.x = 351 * fraction
	xp_fill.visible = fraction > 0.0
	meat_text.text = "보유 %d" % int(state.get("meat", 0))
	for i in 3:
		var key: String = HeroGrowth.STATS[i]
		before_text[i].text = str(stats[key])
		after_text[i].text = str(next_stats.get(key, "—"))
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

func cycle(direction: int) -> void:
	if navigable.size() < 2: return
	var current := navigable.find(selected)
	choose(navigable[posmod(current + direction, navigable.size())], direction)

func choose(index: int, direction := 0) -> void:
	if index == selected or index not in navigable: return
	stop_hold()
	swipe = NONE
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
	var span := size.x / board.scale.x
	active_scene.position.x = sign_dir * span
	var departing := outgoing_scene
	slide = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	slide.tween_property(departing, "position:x", -sign_dir * span, 0.28)
	slide.tween_property(active_scene, "position:x", 0.0, 0.28)
	slide.chain().tween_callback(departing.queue_free)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not app.application_active: return
	if event is InputEventScreenTouch:
		if event.canceled:
			if held == event.index: stop_hold()
			if swipe == event.index: swipe = NONE
			return
		pointer(event.index, event.position, event.pressed)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
		pointer(-1, event.position, event.pressed)

func pointer(index: int, point: Vector2, pressed: bool) -> void:
	if pressed and upgrade.get_global_rect().has_point(point):
		if held == NONE and not upgrade.disabled:
			held = index
			repeats_in = REPEAT_SECONDS
			feed()
			set_process(held != NONE)
		get_viewport().set_input_as_handled()
	elif not pressed and held == index:
		stop_hold()
		get_viewport().set_input_as_handled()
	elif pressed and swipe == NONE and HERO_INTERACTION.has_point(board.get_global_transform().affine_inverse() * point):
		swipe = index
		swipe_start = point
		get_viewport().set_input_as_handled()
	elif not pressed and swipe == index:
		swipe = NONE
		var movement := (point - swipe_start) / board.scale.x
		if absf(movement.x) > 70 and absf(movement.x) > absf(movement.y) * 1.2:
			cycle(-signi(int(movement.x)))
		elif movement.length() < 20.0 and is_instance_valid(hero_video):
			play_hero_motion(true)
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not app.application_active or not is_visible_in_tree() or held == NONE:
		stop_hold()
		return
	repeats_in -= delta
	if repeats_in <= 0.0:
		repeats_in += REPEAT_SECONDS
		if repeats_in <= 0.0: repeats_in = REPEAT_SECONDS
		feed()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_EXIT_TREE]:
		swipe = NONE
		stop_hold()
		if is_instance_valid(hero_video): hero_video.paused = true
	elif what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN]:
		if is_instance_valid(hero_video): hero_video.paused = false

func stop_hold() -> void:
	held = NONE
	set_process(false)

func feed() -> void:
	var result: Dictionary = app.model.feed_hero(HeroGrowth.HEROES[selected])
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
