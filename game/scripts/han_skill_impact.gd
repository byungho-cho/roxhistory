extends RefCounted

const SKILL_FRAME_COUNT := 11
const CHAIN_FRAME_COUNT := 21
const FRAME_RATE := 30.0
const SKILL_SECONDS := SKILL_FRAME_COUNT / FRAME_RATE
const CHAIN_SECONDS := CHAIN_FRAME_COUNT / FRAME_RATE

static func load_skill() -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	for index in SKILL_FRAME_COUNT:
		var path := "res://assets/effects/duel-2sp-authored/han_2sp_impact_%02d.png" % index
		var frame := load(path) as Texture2D if ResourceLoader.exists(path) else null
		if not frame or frame.get_size() != Vector2(192, 192):
			push_warning("Missing or invalid Han 2 SP effect frame: " + path)
			return []
		frames.append(frame)
	return frames

static func load_chain(asset_size: int) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	for index in CHAIN_FRAME_COUNT:
		var standard := "res://assets/effects/d0071-chain/han_chain_impact_%02d.png" % index
		var compact := "res://assets/effects/duel-3sp-authored/hangyeol/192/han_chain_impact_%02d.png" % index
		var path := compact if asset_size == 192 and ResourceLoader.exists(compact) else standard
		var frame := load(path) as Texture2D if ResourceLoader.exists(path) else null
		if not frame:
			push_warning("Missing Han 3 SP effect frame: " + path)
			return []
		frames.append(frame)
	return frames

static func draw_skill(layer: CanvasItem, frames: Array[Texture2D], point: Vector2, angle: float, elapsed: float, scale_factor := 1.0) -> void:
	if frames.is_empty():
		return
	var frame := clampi(floori(elapsed * FRAME_RATE), 0, frames.size() - 1)
	layer.draw_set_transform(point, angle, Vector2.ONE * scale_factor)
	layer.draw_texture_rect(frames[frame], Rect2(-Vector2(90, 117) * 1.5, Vector2.ONE * 288.0), false)
	layer.draw_set_transform(Vector2.ZERO)

static func draw_chain(layer: CanvasItem, frames: Array[Texture2D], point: Vector2, elapsed: float, scale_factor := 1.0) -> void:
	if frames.is_empty():
		return
	var frame := clampi(floori(elapsed * FRAME_RATE), 0, frames.size() - 1)
	layer.draw_texture_rect(frames[frame], Rect2(point - Vector2(96, 121.5) * scale_factor, Vector2(192, 192) * scale_factor), false)

static func make_contact_glow() -> GradientTexture2D:
	var glow := GradientTexture2D.new()
	glow.width = 64
	glow.height = 64
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(.5, .5)
	glow.fill_to = Vector2(1, .5)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0, .18, .48, 1])
	gradient.colors = PackedColorArray([Color(1,1,1,.95), Color(1,1,1,.65), Color(1,1,1,.18), Color(1,1,1,0)])
	glow.gradient = gradient
	return glow

static func draw_chain_flash(layer: CanvasItem, glow: Texture2D, point: Vector2, elapsed: float, scale_factor := 1.0) -> void:
	var peak := 1.0 - smoothstep(.025, .155, elapsed)
	if peak <= 0.0:
		return
	var spread := Vector2(93, 70) * scale_factor
	var core := Vector2(28, 24) * scale_factor
	layer.draw_texture_rect(glow, Rect2(point - spread * .5, spread), false, Color("36afff", peak * .85))
	layer.draw_texture_rect(glow, Rect2(point - core * .5, core), false, Color("f2fcff", peak))
