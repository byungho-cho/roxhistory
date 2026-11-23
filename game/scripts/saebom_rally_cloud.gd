extends RefCounted
## One ground-level white-air front. Same radial motion and asymmetric
## breakup as the approved offline concept, at the native 960px field scale.
const SPAN := 0.94
const SOLO_BASE := 11
const SQUAD_BASE := 14
const ORDINARY_BASE := 1
const DENOMINATOR := 5
const PUFFS := 52
static var _cloud: Texture2D

static func accrue(previous_fifths: int, unbuffed_attack: int) -> Vector2i:
	var fifths := previous_fifths + maxi(0, unbuffed_attack)
	return Vector2i(floori(float(fifths) / DENOMINATOR), fifths % DENOMINATOR)

static func draw(layer: CanvasItem, feet: Vector2, age: float) -> void:
	if not feet.is_finite() or age <= 0.0 or age >= SPAN:
		return
	if _cloud == null:
		_cloud = _make_cloud()
	for i in PUFFS:
		var p := (age - .055 * (.5 + .5 * sin(float(i) * 17.11))) / SPAN
		if p <= 0.0 or p >= 1.0:
			continue
		var a := float(i) * 2.39996 + .085 * p
		var r := (13.0 + 480.0 * p) * (1.0 + .071 * sin(a * 3.1 + .72) + .033 * sin(a * 7.1 - p * 4.0)) - (6.0 + 15.0 * sin(float(i) * 11.123)) * (.48 + .78 * p)
		if r <= 0.0:
			continue
		var ground := feet + Vector2(cos(a), .45 * sin(a)) * r
		var width := (31.0 + 15.0 * sin(float(i) * 7.179)) * (.61 + .64 * p)
		var size := Vector2(width, width * (.34 + .10 * sin(3.0 * a)))
		var opacity := .67 * minf(1.0,p/.16) * pow(1.0-p,1.2) * minf(1.0,r/64.0)
		layer.draw_texture_rect(_cloud, Rect2(ground-size*.5,size),false,Color(1.0,.986,.949,opacity))

static func _make_cloud() -> Texture2D:
	var image := Image.create_empty(48,24,false,Image.FORMAT_RGBA8)
	for y in 24:
		for x in 48:
			var uv := Vector2((float(x)+.5)/24.0-1.0,(float(y)+.5)/12.0-1.0)
			var radius := uv.length()+.075*sin(uv.x*7.0+uv.y*5.0)
			var alpha := pow(maxf(0.0,1.0-radius*radius),2.5)
			image.set_pixel(x,y,Color(1,1,1,alpha))
	return ImageTexture.create_from_image(image)
