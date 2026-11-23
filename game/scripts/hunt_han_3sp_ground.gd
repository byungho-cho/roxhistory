extends RefCounted
## Exact approved straight-alpha dome + ground layer; the spear contact remains separate.
const DURATION := 1.30
const FRAME_COUNT := 39
const ORIGIN := Vector2(96.0, 108.5)
const SOURCE_TO_FIELD := 4.92
const FRAME_PATH := "res://assets/effects/han-3sp-dome-floor/han-dome-floor-%02d.png"
var frames: Array[Texture2D] = []

func prepare() -> bool:
	if frames.size() == FRAME_COUNT:
		return true
	frames.clear()
	for index in FRAME_COUNT:
		var texture := load(FRAME_PATH % index) as Texture2D
		if texture == null or texture.get_size() != Vector2(192, 192):
			frames.clear()
			return false
		frames.append(texture)
	return true

func draw(layer: CanvasItem, anchor: Vector2, age: float, scale0 := 1.0) -> void:
	if age < 0.0 or age >= DURATION or frames.size() != FRAME_COUNT:
		return
	var scale1 := SOURCE_TO_FIELD * scale0
	var index := clampi(floori(age * 30.0 + 0.00001), 0, FRAME_COUNT - 1)
	layer.draw_texture_rect(frames[index], Rect2(anchor - ORIGIN * scale1, Vector2(192, 192) * scale1), false)
