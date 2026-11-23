extends RefCounted
## Approved Orange + Dust artwork, only for ordinary (non-parry) shield casts.
const FRAME_COUNT := 59
const FRAME_RATE := 30.0
const SECONDS := FRAME_COUNT / FRAME_RATE
const SCALE := 5.0
const SHIELD_ANCHOR := Vector2(89.0, 112.6)
const SOURCE_SIZE := Vector2(192.0, 192.0)
const PATH := "res://assets/effects/uram-3sp-combined/uram_3sp_orange_dust_%02d.png"

var frames: Array[Texture2D] = []

func prepare() -> bool:
	if frames.size() == FRAME_COUNT:
		return true
	frames.clear()
	for i in FRAME_COUNT:
		var path := PATH % i
		var frame := load(path) as Texture2D if ResourceLoader.exists(path) else null
		if not frame or frame.get_size() != SOURCE_SIZE:
			frames.clear()
			return false
		frames.append(frame)
	return true

func index_at(age: float) -> int:
	if age < 0.0 or age >= SECONDS:
		return -1
	return mini(floori(age * FRAME_RATE + 0.00001), FRAME_COUNT - 1)

func draw(layer: CanvasItem, shield: Vector2, direction: Vector2, age: float) -> void:
	var index := index_at(age)
	if index < 0 or frames.size() != FRAME_COUNT:
		return
	# Mirror toward the target without rotating vertical screen perspective.
	layer.draw_set_transform(shield, 0.0, Vector2(-1.0 if direction.x < 0.0 else 1.0, 1.0))
	layer.draw_texture_rect(frames[index], Rect2(-SHIELD_ANCHOR * SCALE, SOURCE_SIZE * SCALE), false)
	layer.draw_set_transform(Vector2.ZERO)
