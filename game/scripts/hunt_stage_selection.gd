extends Control
## A chapter is six sequential encounters. Cleared encounters remain selectable.
const STAGES_PER_CHAPTER := 6
const CHAPTERS := ["초원", "숲"]
const TOTAL_STAGES := STAGES_PER_CHAPTER * 2
const TITLE := preload("res://assets/ui/d0009/hunt_title_stone_crest.png")
const FIELD := preload("res://assets/ui/d0009/hunt_grassland_bg.png")
const SKINS := {
	"rules": preload("res://assets/ui/hunt-selection/rules.svg"),
	"chapter": preload("res://assets/ui/hunt-selection/chapter.svg"),
	"complete": preload("res://assets/ui/hunt-selection/complete.svg"),
	"current": preload("res://assets/ui/hunt-selection/current.svg"),
	"locked": preload("res://assets/ui/hunt-selection/locked.svg"),
	"gold": preload("res://assets/ui/hunt-selection/gold-rim.svg"),
}
const BOSS_ICON := preload("res://assets/ui/d0009/hunt_boss_boar_crest.png")
var app: Node
var page: Control

var chapter := 0
var entry_played := false
var entry_tween: Tween
var entry_positions: Dictionary = {}

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
	finish_entry()
	if is_instance_valid(page):
		remove_child(page)
		page.queue_free()
	page = Control.new()
	page.size = size
	add_child(page)
	var bg: TextureRect = app.picture(page, FIELD, Rect2(Vector2.ZERO, size))
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var unit := minf(size.x / 704.0,size.y / 350.0)
	var center := size * Vector2(.5,.687)
	var crest := Rect2(size.x * .5 - 80 * unit,maxf(5 * unit,app.safe.y - 9),160 * unit,56 * unit)
	app.picture(page, TITLE, crest)
	title(page, "사냥터 선택", Rect2(crest.position + Vector2(0,22)*unit,Vector2(160,28)*unit), roundi(20*unit))
	var back := action(page, "", Rect2(Vector2(maxf(app.safe.x,19*unit),maxf(app.safe.y,10*unit)),Vector2.ONE*maxf(36,28*unit)), exit_selection)
	for state in ["normal","hover","pressed","focus"]:
		back.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	app.picture(back,FigmaArt.texture("back"),Rect2((back.size-Vector2.ONE*28*unit)*.5,Vector2.ONE*28*unit))
	var rules := action(page, "", Rect2(size.x - maxf(app.safe.x,16*unit) - 63*unit,maxf(app.safe.y,10*unit),63*unit,maxf(32,26*unit)),open_rules)
	button_art(rules,SKINS.rules)
	app.picture(rules,preload("res://assets/ui/hunt-selection/book.svg"),Rect2(8*unit,(rules.size.y-13*unit)*.5,13*unit,13*unit))
	title(rules,"규칙",Rect2(Vector2(22*unit,0),Vector2(35*unit,rules.size.y)),roundi(12*unit))
	var footer := Control.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(footer)
	var chapter_rect := Rect2(Vector2(center.x, size.y*.531)-Vector2(94,15)*unit,Vector2(188,30)*unit)
	app.picture(footer,SKINS.chapter,chapter_rect)
	title(footer,"%d장 · %s" % [chapter+1,CHAPTERS[chapter]],chapter_rect,roundi(17*unit))
	var arrow_size := Vector2(42,34)*unit
	var prev := action(footer,"",Rect2(chapter_rect.position-Vector2(0,2)*unit,arrow_size),change_chapter.bind(-1))
	var next := action(footer,"",Rect2(Vector2(chapter_rect.end.x-arrow_size.x,prev.position.y),arrow_size),change_chapter.bind(1))
	for arrow in [prev,next]:
		for state in ["normal","hover","pressed","disabled","focus"]:
			arrow.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		var arrow_art: Texture2D = preload("res://assets/ui/hunt-selection/previous.svg") if arrow == prev else preload("res://assets/ui/hunt-selection/next.svg")
		app.picture(arrow,arrow_art,Rect2((arrow_size-Vector2.ONE*17*unit)*.5,Vector2.ONE*17*unit))
	prev.disabled = chapter == 0
	next.disabled = chapter + 1 >= CHAPTERS.size()
	for index in STAGES_PER_CHAPTER:
		var stage_id := chapter * STAGES_PER_CHAPTER + index
		var available := stage_id <= progress()
		var done := stage_id < progress()
		var boss := index == STAGES_PER_CHAPTER-1
		var current := stage_id == progress()
		var selected: bool = stage_id == app.hunt_stage
		var tile_center := center + Vector2(-167+64*index,0)*unit
		var diameter := 42*unit
		var rect := Rect2(tile_center-Vector2.ONE*diameter*.5,Vector2.ONE*diameter)
		if boss:
			rect = Rect2(center+Vector2(111,-91)*unit,Vector2(96,137)*unit)
		var tile := action(footer,"",rect,choose.bind(stage_id))
		tile.name = "HuntStage%d" % stage_id
		tile.disabled = not available
		for state in ["normal","hover","pressed","disabled","focus"]:
			tile.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		if boss:
			var boss_art: TextureRect = app.picture(tile,BOSS_ICON,Rect2(Vector2.ZERO,rect.size))
			boss_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			if done: boss_art.modulate = Color(.64,.64,.64)
			title(tile,"보스",Rect2(Vector2(0,66)*unit,Vector2(96,23)*unit),roundi(16*unit))
		else:
			button_art(tile,SKINS.complete if done else SKINS.current if current else SKINS.locked)
			if selected and done:
				var selection := Panel.new()
				selection.mouse_filter = Control.MOUSE_FILTER_IGNORE
				selection.add_theme_stylebox_override("panel",rim(Color.TRANSPARENT,Color("ffe0ae"),ceili(diameter*.5),2))
				tile.add_child(selection)
				selection.size = tile.size
			title(tile,str(index+1),Rect2(0,2*unit,diameter,(38 if current else 24)*unit),roundi((20 if current else 15)*unit))
		if done or not available:
			var marker: Texture2D = preload("res://assets/ui/hunt-selection/check.svg") if done else preload("res://assets/ui/hunt-selection/boss-lock.svg") if boss else preload("res://assets/ui/hunt-selection/lock.svg")
			var marker_size := (16 if boss else 11)*unit
			app.picture(tile,marker,Rect2((rect.size.x-marker_size)*.5,(87 if boss else 23)*unit,marker_size,marker_size))
	var prepare := action(footer,"사냥 준비",Rect2(Vector2(center.x,size.y*.864)-Vector2(86,21)*unit,Vector2(172,42)*unit),app.prepare_selected_hunt,true)
	prepare.add_theme_font_size_override("font_size",roundi(20*unit))
	for state in ["normal","hover","pressed","disabled","focus"]:
		prepare.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	for key in ["font_color","font_hover_color","font_pressed_color","font_disabled_color"]:
		prepare.add_theme_color_override(key,Color("47240e"))
	button_art(prepare,SKINS.gold)
	var face: TextureRect = app.picture(prepare,preload("res://assets/ui/hunt-selection/gold-face.png"),Rect2(Vector2.ONE*4*unit,prepare.size-Vector2.ONE*8*unit))
	face.show_behind_parent = true
	face.stretch_mode = TextureRect.STRETCH_SCALE
	prepare.disabled = app.hunt_stage / STAGES_PER_CHAPTER != chapter

	if not entry_played:
		entry_played = true
		entry_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		animate_entry(back,Vector2(-14,0),0.0)
		animate_entry(rules,Vector2(14,0),0.05)
		animate_entry(footer,Vector2(0,20),0.10)

func button_art(button: DemoButton, texture: Texture2D) -> void:
	for state in ["normal","hover","pressed","disabled","focus"]:
		button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	var art: TextureRect = app.picture(button,texture,Rect2(Vector2.ZERO,button.size))
	art.show_behind_parent = true

func rim(fill: Color, border: Color, radius: int, width := 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_corner_radius_all(maxi(radius,0))
	style.set_border_width_all(width)
	return style

func animate_entry(node: Control, offset: Vector2, delay: float) -> void:
	entry_positions[node] = node.position
	node.position += offset
	node.modulate.a = 0.0
	entry_tween.tween_property(node,"position",entry_positions[node],.22).set_delay(delay)
	entry_tween.tween_property(node,"modulate:a",1.0,.22).set_delay(delay)

func finish_entry() -> void:
	if entry_positions.is_empty(): return
	if entry_tween and entry_tween.is_valid(): entry_tween.kill()
	for node: Control in entry_positions:
		node.position = entry_positions[node]
		node.modulate.a = 1.0
	entry_positions.clear()

func _input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		finish_entry()

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
