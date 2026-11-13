extends Control
## A chapter is six sequential encounters. Cleared encounters remain selectable.
const STAGES_PER_CHAPTER := 6
const CHAPTERS := ["초원", "숲"]
const TOTAL_STAGES := STAGES_PER_CHAPTER * 2
const TITLE := preload("res://assets/figma-latest/stone-title-surface.png")
const FIELD := preload("res://assets/ui/hunting-formation/clearing.png")
const LOCK := preload("res://assets/ui/v0158/lock.png")
const BOSS_ICON := preload("res://assets/ui/hunting-formation/boar-boss.svg")
var app: Node
var page: Control
var rules_overlay: Control
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
	bg.modulate = Color(.82, .88, .73)
	var width := minf(size.x - 2 * app.safe.x, 650)
	var center := size * .5
	var plaque := Panel.new()
	plaque.position = center + Vector2(-140,-154)
	plaque.size = Vector2(280,72)
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stone := StyleBoxTexture.new()
	stone.texture = TITLE
	stone.modulate_color = Color("777266")
	stone.set_content_margin_all(8)
	plaque.add_theme_stylebox_override("panel", stone)
	page.add_child(plaque)
	title(page, "사냥터 선택", Rect2(center.x - 140, center.y - 154, 280, 72), 30)
	action(page, "뒤로", Rect2(app.safe, Vector2(70, 44)), exit_selection)
	action(page, "규칙", Rect2(size.x - app.safe.x - 72, app.safe.y, 72, 44), open_rules)
	title(page, "%d장 · %s" % [chapter + 1, CHAPTERS[chapter]], Rect2(center.x - 96, center.y - 68, 192, 40), 22)
	var prev := action(page, "◀", Rect2(center.x - 146, center.y - 68, 44, 40), change_chapter.bind(-1))
	var next := action(page, "▶", Rect2(center.x + 102, center.y - 68, 44, 40), change_chapter.bind(1))
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
		var rect := Rect2(center.x - width * .5 + step * index + 3, center.y - 12, step - 6, 62)
		var tile := action(page, caption, rect, choose.bind(stage_id))
		var fill := Color("9b3028") if boss and not done else Color("575c58") if done or not available else Color("236db3")
		var border := Color("e2ad49") if boss or stage_id == app.hunt_stage else Color("c2d5bc")
		for state in ["normal", "hover", "pressed", "disabled"]:
			var style := StyleBoxFlat.new()
			style.bg_color = fill.lightened(.13) if state == "hover" else fill
			style.border_color = border
			style.set_border_width_all(3 if stage_id == app.hunt_stage else 2)
			style.set_corner_radius_all(8)
			tile.add_theme_stylebox_override(state, style)
		tile.disabled = not available
		if boss:
			tile.icon = BOSS_ICON
			tile.expand_icon = true
			tile.add_theme_constant_override("icon_max_width", 24)
		if not available:
			var lock: TextureRect = app.picture(tile, LOCK, Rect2(rect.size.x - 21, 4, 17, 19))
			lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var prepare := action(page, "사냥 준비", Rect2(center.x - 88, center.y + 88, 176, 52), app.prepare_selected_hunt, true)
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
