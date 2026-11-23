extends Node2D
## Transient presentation only; values come from committed before/after HP.
const LIFETIME := .66
const FONT_SIZE := 23
const TeamPalette := preload("res://scripts/battle_head_hud.gd")
const FILL_OPACITY := .90
const OUTLINE := Color("#25191d")
var entries: Array[Dictionary] = []
var clock := 0.0

func _ready() -> void:
	set_process(false)

func show_loss(victim: int, before: int, after: int, anchor: Vector2, ally: bool) -> void:
	var lost := before - after
	if lost <= 0 or not anchor.is_finite():
		return
	var lane := 0
	for ev in entries:
		if ev.victim == victim and clock - float(ev.born) < .29:
			lane = maxi(lane, int(ev.lane)+1)
	entries.append({"victim":victim, "loss":lost, "anchor":anchor, "ally":ally, "born":clock, "lane":lane})
	queue_redraw()
	set_process(true)

func clear() -> void:
	entries.clear()
	queue_redraw()
	set_process(false)

func _process(delta: float) -> void:
	clock += delta
	while not entries.is_empty() and clock - float(entries[0].born) >= LIFETIME:
		entries.pop_front()
	queue_redraw()
	if entries.is_empty():set_process(false)

func _draw() -> void:
	var font := ThemeDB.fallback_font
	for ev in entries:
		var age := clock - float(ev.born)
		var alpha := 1.0 - smoothstep(.30, LIFETIME, age)
		var caption := "−%d" % int(ev.loss)
		var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var lane := int(ev.lane)
		var dx := (20.0 + 6.0 * floori(float(lane)/2.0)) * (1.0 if lane%2==1 else -1.0) if lane>0 else 0.0
		var base: Vector2 = ev.anchor
		var at := base + Vector2(dx - width*.5, -3.0 - 31.0 * smoothstep(0.0, LIFETIME, age) - 7.0*lane)
		var fill := TeamPalette.duel_team_color(bool(ev.ally))
		fill.a = FILL_OPACITY * alpha
		var edge := OUTLINE
		edge.a = alpha
		draw_string_outline(font, at, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 5, edge)
		draw_string(font, at, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, fill)
