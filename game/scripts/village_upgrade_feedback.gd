extends Node2D

const DUST := preload("res://assets/ui/d0019/ground-dust-soft.png")
const CELEBRATION_TIME := 2.7
const CAPTION_EXTRA_TIME := 2.0
const ACHIEVEMENT_APPEAR := .72
const HERO_TRACE_LIFETIME := 1.11
const HERO_TRACE_STAGGER := .078
const HERO_TOP_LIFT := 265.2 # 1.2 times the approved 221 px upper travel.
const HERO_SPIRAL_FINISH := HERO_TRACE_LIFETIME + 2.0 * HERO_TRACE_STAGGER
const HERO_BURST_AT := .50
const HERO_BURST_LIFETIME := .43
const FIREWORK_COLORS := [Color("ff8678"),Color("7ce9d2"),Color("d2a0ff")]
var age := 0.0
var level: int
var glyphs: Array[Label] = []
var glyph_origins: Array[Vector2] = []
var level_glyph_count := 0
static var glow: GradientTexture2D
static var hero_bloom: GradientTexture2D
var play_completion: Callable
var aura_only: bool
var hero_burst_offset := Vector2(0.0, -444.0)

func _init(at: Vector2, target_level: int, on_completion := Callable(), ground_aura_only := false) -> void:
	position = at
	level = target_level
	play_completion = on_completion
	aura_only = ground_aura_only
	z_index = 10 if level == 0 else 5
	visibility_layer = 2

func _ready() -> void:
	if level <= 0: return
	if glow == null:
		glow = GradientTexture2D.new()
		glow.gradient = Gradient.new()
		glow.gradient.colors = PackedColorArray([Color(1,.93,.62,.83),Color(1,.67,.20,0)])
		glow.fill = GradientTexture2D.FILL_RADIAL
		glow.fill_from = Vector2(.5,.5)
		glow.fill_to = Vector2(1,.5)
	if aura_only:
		if hero_bloom == null:
			hero_bloom = GradientTexture2D.new()
			hero_bloom.width = 192
			hero_bloom.height = 128
			hero_bloom.gradient = Gradient.new()
			hero_bloom.gradient.offsets = PackedFloat32Array([0.0, .16, .36, .62, .82, 1.0])
			hero_bloom.gradient.colors = PackedColorArray([Color(1,.98,.82,.94), Color(1,.89,.60,.65), Color(1,.73,.34,.38), Color(.97,.57,.16,.17), Color(.92,.46,.08,.047), Color(.91,.4,.08,0)])
			hero_bloom.fill = GradientTexture2D.FILL_RADIAL
			hero_bloom.fill_from = Vector2(.5,.5)
			hero_bloom.fill_to = Vector2(1.0,.5)
		var additive := CanvasItemMaterial.new()
		additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = additive
		return
	var prefix := "Lv. %d " % level
	var caption := prefix+"달성!"
	level_glyph_count=prefix.length()
	var cursor := -FigmaArt.BODY.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,37).x*.5
	for i in caption.length():
		var character := caption.substr(i,1)
		var width := FigmaArt.BODY.get_string_size(character,HORIZONTAL_ALIGNMENT_LEFT,-1,37).x
		var ink: Color = Color("ffdb76") if character.is_valid_int() else FIREWORK_COLORS[i%FIREWORK_COLORS.size()]
		var glyph := FigmaArt.text(self,character,Rect2(cursor,-190,width,50),37,FigmaArt.BODY,ink)
		glyph.add_theme_constant_override("outline_size",7)
		glyph.add_theme_color_override("font_outline_color",Color("4a2921"))
		glyph.pivot_offset=glyph.size*.5
		glyph.modulate.a=0.0
		glyphs.append(glyph)
		glyph_origins.append(glyph.position)
		cursor+=width

func _process(delta: float) -> void:
	age += delta
	if aura_only:
		if age >= maxf(HERO_SPIRAL_FINISH, HERO_BURST_AT + HERO_BURST_LIFETIME): queue_free()
		else: queue_redraw()
		return
	if level > 0:
		if age>=ACHIEVEMENT_APPEAR and play_completion.is_valid():
			var completion := play_completion
			play_completion = Callable()
			completion.call()
		var zoom := get_global_transform_with_canvas().get_scale().x / scale.x
		scale = Vector2.ONE*clampf(.48/maxf(zoom,.01),1.0,1.8)
		for i in glyphs.size():
			var appear := .34 if i<level_glyph_count else ACHIEVEMENT_APPEAR
			var leave := 1.53+i*.055+CAPTION_EXTRA_TIME
			var fly := clampf((age-leave)/.52,0,1)
			var glyph := glyphs[i]
			glyph.position=glyph_origins[i]-Vector2(0,80.0*fly*fly)
			glyph.scale=Vector2.ONE*lerpf(.66,1.0,smoothstep(appear,appear+.18,age))
			glyph.rotation=sin(i*2.7)*.35*fly
			glyph.modulate.a=smoothstep(appear,appear+.12,age)*(1.0-smoothstep(.18,1.0,fly))
	if age >= (2.6 if level == 0 else CELEBRATION_TIME+CAPTION_EXTRA_TIME):
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	if aura_only:
		draw_hero_aura()
		return
	if level == 0:
		var alpha := 1.0-smoothstep(.12,2.6,age)
		for side in [-1,1]:
			var span := Vector2(145,68)*(1.0+age*.2)
			var center := Vector2(side*(70+age*35),-12-age*9)
			draw_texture_rect(DUST,Rect2(center-span*.5,span),false,Color(1,1,1,alpha))
			var burst := span*.84
			draw_texture_rect(DUST,Rect2(center-Vector2(0,11)-burst*.5,burst),false,Color(1.0,.96,.87,alpha*(1.0-smoothstep(.12,.68,age))))
		return
	var alpha := 1.0-smoothstep(.30,1.16,age)
	draw_texture_rect(glow,Rect2(-104,-61,208,108),false,Color(1,1,1,alpha))
	for i in 2:
		var wave := clampf((age-i*.13)/.78,0,1)
		var radius := lerpf(34,152,wave)
		draw_set_transform(Vector2(0,3),0,Vector2(1,.43))
		draw_arc(Vector2.ZERO,radius,0,TAU,36,Color(1,.92,.57,(1-wave)*alpha),2.8,true)
	draw_set_transform(Vector2.ZERO)
	for i in 15:
		var at := Vector2(sin(i*2.4)*(34+age*43),-24-age*(24+i*3))
		var size := 2.0+2.0*absf(sin(i*2.4+age*11.0))
		var color := Color(1,.89,.53,.90*alpha)
		draw_line(at-Vector2(size,0),at+Vector2(size,0),color,1.4,true)
		draw_line(at-Vector2(0,size*1.45),at+Vector2(0,size*1.45),color,1.4,true)
	draw_firework(Vector2(-115,-133),.72,0)
	draw_firework(Vector2(119,-148),.95,1)
	draw_firework(Vector2(37,-224),1.14,2)

# Wide open golden helix from the approved S40700 success concept.
# Hero-only effect. The legacy village equalizer and fireworks are unaffected.
func draw_hero_aura() -> void:
	var power := smoothstep(0.0, .12, age) * (1.0 - smoothstep(.49, 1.29, age))
	var fast := smoothstep(0.0, .065, age) * (1.0 - smoothstep(.13, .43, age))
	if power > 0.001:
		draw_texture_rect(hero_bloom, Rect2(-304, -119, 608, 201), false, Color(1.0, .83, .64, power * .39))
		draw_texture_rect(hero_bloom, Rect2(-187, -88, 374, 149), false, Color(1.0, .93, .69, power * .53 + fast * .13))
		draw_texture_rect(hero_bloom, Rect2(-101, -53, 202, 101), false, Color(1.0, .99, .82, power * .35 + fast * .38))
		var rise := smoothstep(.055, .40, age)
		for i in 6:
			var sway := sin(float(i) * 2.17)
			var width := 34.0 + float(i % 4) * 13.0
			var height := (92.0 + float(i % 3) * 33.0) * lerpf(.65, 1.28, rise)
			var beam := Rect2(sway * 104.0 - width * .5, -height - 9.0, width, height)
			draw_texture_rect(hero_bloom, beam, false, Color(1.0, .81, .51, power * (.31 + float(i % 3) * .053)))
	# Long, open tracers instead of stacked closed rings or a bright vertical pillar.
	var throw := lerpf(.58, 1.0, 1.0 - exp(-age * 9.8))
	var height := lerpf(.61, 1.0, smoothstep(.045, .46, age))
	for i in 3:
		var since := age - float(i) * HERO_TRACE_STAGGER
		if since <= 0.0 or since >= HERO_TRACE_LIFETIME: continue
		var alpha := smoothstep(0.0, .1, since) * (1.0 - smoothstep(.47, HERO_TRACE_LIFETIME, since))
		var reach := lerpf(.46, 1.0, smoothstep(0.0, .29, since))
		var points := PackedVector2Array()
		for j in 92:
			var t := float(j) / 91.0 * reach
			var angle := t * TAU * (1.54 - float(i) * .13) + .58 + age * (1.55 + float(i) * .64) - float(i) * 1.47
			var taper := lerpf(1.0, .70, smoothstep(.17, 1.0, t))
			var radius := (242.0 - t * 50.0 - float(i) * 16.0) * throw * taper
			var lifted := pow(t, 1.28) * (HERO_TOP_LIFT - float(i) * 43.2) * height
			var y := sin(angle) * radius * .24 - lifted + 5.0
			points.append(Vector2(cos(angle) * radius, y))
		# Layering small energy increments over progressively narrower widths
		# creates a feathered additive light with a crisp warm-white core.
		var shine := alpha * (.82 + .24 * fast)
		draw_aura_trail(points, 94.0, Color(1.0, .50, .15, shine * .009))
		draw_aura_trail(points, 76.0, Color(1.0, .54, .18, shine * .016))
		draw_aura_trail(points, 62.0, Color(1.0, .57, .20, shine * .027))
		draw_aura_trail(points, 48.0, Color(1.0, .63, .26, shine * .039))
		draw_aura_trail(points, 36.0, Color(1.0, .68, .29, shine * .052))
		draw_aura_trail(points, 25.0, Color(1.0, .72, .36, shine * .055))
		draw_aura_trail(points, 17.0, Color(1.0, .72, .34, shine * .075))
		draw_aura_trail(points, 11.0, Color(1.0, .78, .42, shine * .115))
		draw_aura_trail(points, 6.3, Color(1.0, .82, .54, shine * .172))
		draw_aura_trail(points, 3.2, Color(1.0, .90, .65, shine * .31))
		draw_aura_trail(points, 1.45, Color(1.0, .98, .87, shine * .51))
	draw_hero_endpoint_burst()
	# Bright warm sparks rise quickly and dissipate well below the hero's face.
	for i in 34:
		var since := age - float((i * 11) % 9) * .033
		var life := .64 + float(i % 6) * .082
		if since <= 0.0 or since >= life: continue
		var t := since / life
		var rise := 1.0 - pow(1.0 - t, 1.42)
		var spread := sin(float(i) * 2.39)
		var start := spread * (41.0 + float(i % 5) * 19.0)
		var ceiling := lerpf(62.0, 221.0, float((i * 17) % 34) / 33.0)
		var at := Vector2(start + spread * 39.0 * t + sin(age * 7.0 + float(i)) * 8.0, 3.0 - ceiling * rise)
		var twinkle := smoothstep(0.0, .11, t) * (1.0 - smoothstep(.44, 1.0, t))
		var length := 2.1 + float(i % 5) * 1.03
		var streak := Vector2(-spread * length * .65, length * 2.9)
		draw_line(at + streak, at, Color(1.0, .59, .23, twinkle * .62), 2.3, true)
		draw_line(at + streak * .23, at, Color(1.0, .94, .59, twinkle), 1.6, true)
		if i % 4 == 0:
			draw_texture_rect(hero_bloom, Rect2(at.x-13.0, at.y-13.0, 26, 26), false, Color(1.0, .93, .62, twinkle * .60))

func draw_hero_endpoint_burst() -> void:
	var elapsed := age - HERO_BURST_AT
	if elapsed < 0.0 or elapsed > HERO_BURST_LIFETIME: return
	var tip := hero_burst_offset
	var spread := 1.0 - exp(-elapsed * 12.0)
	var strength := smoothstep(0.0, .027, elapsed) * (1.0 - smoothstep(.12, .43, elapsed))
	draw_texture_rect(hero_bloom, Rect2(tip - Vector2(29, 29), Vector2(58, 58)), false, Color(1.0, .96, .70, strength * (1.0 - spread * .69) * .78))
	for i in 13:
		var phase := float(i) / 13.0 * TAU + .23
		var direction := Vector2.from_angle(phase)
		var distance := (20.0 + float((i * 7) % 9) * 2.4) * spread
		var at := tip + direction * distance + Vector2(0, elapsed * elapsed * 31.0)
		var tail := at - direction * minf(distance, 5.0 + 7.0 * strength)
		draw_line(tail, at, Color(1.0, .65, .25, strength * .51), 3.7, true)
		draw_line(tail.lerp(at, .21), at, Color(1.0, .94, .66, strength * .94), 1.35, true)
		draw_circle(at, 1.0 + strength * .55, Color(1.0, .96, .73, strength), true, -1.0, true)

func draw_aura_trail(points: PackedVector2Array, width: float, color: Color) -> void:
	var colors := PackedColorArray()
	for i in points.size():
		var t := float(i) / float(points.size() - 1)
		var fade := smoothstep(0.0, .095, t) * (1.0 - smoothstep(.87, 1.0, t))
		colors.append(Color(color, color.a * fade))
	draw_polyline_colors(points, colors, width, true)

func draw_firework(center: Vector2, delay: float, palette_offset: int) -> void:
	var time := age-delay
	if time<0.0 or time>.86:return
	var fade := 1.0-smoothstep(.16,.86,time)
	var reach := 1.0-exp(-time*4.5)
	if time < .16:
		draw_texture_rect(glow,Rect2(center-Vector2.ONE*36,Vector2.ONE*72),false,Color(1,1,1,1.0-time/.16))
	for i in 19:
		var direction := Vector2.from_angle(i*TAU/19.0+palette_offset*.15)
		var distance := (39.0+float((i*7)%8)*6.0)*reach
		var tip := center+direction*distance+Vector2(0,47.0*time*time)
		var color: Color = FIREWORK_COLORS[palette_offset].lerp(Color("fff5c6"),float(i%4)*.18)
		color.a = fade
		draw_line(tip-direction*minf(distance,5.0+8.0*fade),tip,color,2.0,true)
		draw_circle(tip,1.5+fade,color)
