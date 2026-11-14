extends Control
## A chapter is six sequential encounters. Cleared encounters remain selectable.
const STAGES_PER_CHAPTER := 6
const CHAPTERS := ["초원", "숲"]
const TOTAL_STAGES := STAGES_PER_CHAPTER * 2
const TITLE := preload("res://assets/ui/d0009/hunt_title_stone_crest.png")
const FIELD := preload("res://assets/ui/d0009/hunt_grassland_bg.png")
const LOCK := preload("res://assets/ui/v0158/lock.png")
const BOSS_ICON := preload("res://assets/ui/d0009/hunt_boss_boar_crest.png")
var app: Node
var page: Control

var chapter := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	chapter = app.hunt_stage / STAGES_PER_CHAPTER
	resized.connect(draw_page)
	draw_page()

func progress() -> int:
	return int(app.model.state.get("hunt_cleared", 0))

func draw_page() -> void:
	if size.x <= 0 or size.y <= 0:
		return
	if is_instance_valid(page):
		remove_child(page)
		page.queue_free()
	page = Control.new()
	page.size = size
	add_child(page)
	var bg: TextureRect = app.picture(page, FIELD, Rect2(Vector2.ZERO, size))
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var width := minf(size.x - 2 * app.safe.x, 525)
	var center := Vector2(size.x * .5, size.y * .68)
	var crest := Rect2(size.x * .5 - 125, app.safe.y - 9, 250, 83)
	app.picture(page, TITLE, crest)
	title(page, "사냥터 선택", Rect2(crest.position + Vector2(0,37),Vector2(250,42)), 30)
	var back := action(page, "", Rect2(app.safe, Vector2(46,46)), exit_selection)
	for state in ["normal","hover","pressed","focus"]:
		back.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	app.picture(back,preload("res://assets/ui/d0009/hunt_common_back.png"),Rect2(0,0,46,46))
	action(page, "규칙", Rect2(size.x - app.safe.x - 84, app.safe.y, 84, 38), open_rules)
	var chapter_bar := Panel.new()
	chapter_bar.position = center + Vector2(-132,-95)
	chapter_bar.size = Vector2(264,44)
	chapter_bar.add_theme_stylebox_override("panel",DemoArt.button_style(false))
	page.add_child(chapter_bar)
	chapter_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title(page, "%d장 · %s" % [chapter + 1, CHAPTERS[chapter]], Rect2(center.x - 96, center.y - 95, 192, 44), 22)
	var prev := action(page, "◀", Rect2(center.x - 128, center.y - 95, 44, 44), change_chapter.bind(-1))
	var next := action(page, "▶", Rect2(center.x + 84, center.y - 95, 44, 44), change_chapter.bind(1))
	for arrow in [prev,next]:
		for state in ["normal","hover","pressed","disabled","focus"]:
			arrow.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	prev.disabled = chapter == 0
	next.disabled = chapter + 1 >= CHAPTERS.size()
	var step := width / STAGES_PER_CHAPTER
	for index in STAGES_PER_CHAPTER:
		var stage_id := chapter * STAGES_PER_CHAPTER + index
		var available := stage_id <= progress()
		var done := stage_id < progress()
		var boss := index == STAGES_PER_CHAPTER - 1
		var caption := "보스" if boss else str(index + 1)
		if done:
			caption += " ✓"
		var diameter := minf(step - 6,62)
		var rect := Rect2(center.x - width * .5 + step * (index + .5) - diameter * .5, center.y - diameter * .5, diameter, diameter)
		var tile := action(page, caption, rect, choose.bind(stage_id))
		var fill := Color("9b3028") if boss and not done else Color("575c58") if done else Color("674a30") if not available else Color("236db3")
		var border := Color("e2ad49") if boss or stage_id == app.hunt_stage else Color("c2d5bc")
		for state in ["normal", "hover", "pressed", "disabled"]:
			var style := StyleBoxFlat.new()
			style.bg_color = fill.lightened(.13) if state == "hover" else fill
			style.border_color = border
			style.set_border_width_all(3 if stage_id == app.hunt_stage else 2)
			style.set_corner_radius_all(32)
			tile.add_theme_stylebox_override(state, style)
		tile.disabled = not available
		if boss:
			tile.position -= Vector2(diameter * .35,diameter * .65)
			tile.size = Vector2.ONE * diameter * 1.7
			tile.text = ""
			for state in ["normal","hover","pressed","disabled","focus"]:
				tile.add_theme_stylebox_override(state,StyleBoxEmpty.new())
			var boss_art: TextureRect = app.picture(tile,BOSS_ICON,Rect2(Vector2.ZERO,tile.size))
			if done:boss_art.modulate = Color(.64,.64,.64)
			title(tile,caption,Rect2(0,tile.size.y*.51,tile.size.x,26),17)
		if not available:
			var lock: TextureRect = app.picture(tile, LOCK, Rect2(tile.size.x * .5 - 7, tile.size.y * (.77 if boss else .71), 14, 15))
			lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var prepare := action(page, "사냥 준비", Rect2(center.x - 114, center.y + 60, 228, 54), app.prepare_selected_hunt, true)
	for state in ["normal","hover","pressed","disabled","focus"]:
		prepare.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	for key in ["font_color","font_hover_color","font_pressed_color","font_disabled_color"]:
		prepare.add_theme_color_override(key,Color("47240e"))
	var skin := FigmaSlice.new("gold",42)
	skin.show_behind_parent = true
	prepare.add_child(skin)
	skin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	prepare.disabled = app.hunt_stage / STAGES_PER_CHAPTER != chapter

func choose(stage_id: int) -> void:
	if stage_id > progress():
		return
	app.hunt_stage = stage_id
	draw_page()

func change_chapter(direction: int) -> void:
	chapter = clampi(chapter + direction, 0, CHAPTERS.size() - 1)
	draw_page()

func exit_selection() -> void:
	app.show_screen("play")

func open_rules() -> void:
	if app.modal:
		return
	app.show_modal("사냥 규칙",
		"스테이지를 선택한 뒤 사냥 준비를 누르세요.\n완료한 사냥터는 다시 도전할 수 있습니다.\n일반 사냥터 다섯 곳을 완료하면 보스가 열리고, 보스에 승리하면 다음 장이 열립니다.",
		[{"text": "닫기", "action": app.close_modal}], false, true, false, Vector2(490, 330))

func title(parent: Control, value: String, rect: Rect2, font_size: int) -> void:
	var label: Label = app.label(parent, value, font_size, Color("fff1cd"))
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func action(parent: Control, value: String, rect: Rect2, callback: Callable, primary := false) -> DemoButton:
	var button: DemoButton = app.button(parent, value, callback, primary)
	button.custom_minimum_size = Vector2.ZERO
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_size_override("font_size", 17)
	return button
