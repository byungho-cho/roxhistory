extends Node2D

const DUST := preload("res://assets/ui/d0019/ground-dust-soft.png")
const CELEBRATION_TIME := 2.7
const FIREWORK_COLORS := [Color("ff8678"),Color("7ce9d2"),Color("d2a0ff")]
var age := 0.0
var level: int
var glyphs: Array[Label] = []
var glyph_origins: Array[Vector2] = []
var level_glyph_count := 0
static var glow: GradientTexture2D

func _init(at: Vector2, target_level: int) -> void:
	position = at
	level = target_level
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
	if level > 0:
		var zoom := get_global_transform_with_canvas().get_scale().x / scale.x
		scale = Vector2.ONE*clampf(.48/maxf(zoom,.01),1.0,1.8)
		for i in glyphs.size():
			var appear := .34 if i<level_glyph_count else .72
			var leave := 1.53+i*.055
			var fly := clampf((age-leave)/.52,0,1)
			var glyph := glyphs[i]
			glyph.position=glyph_origins[i]-Vector2(0,80.0*fly*fly)
			glyph.scale=Vector2.ONE*lerpf(.66,1.0,smoothstep(appear,appear+.18,age))
			glyph.rotation=sin(i*2.7)*.35*fly
			glyph.modulate.a=smoothstep(appear,appear+.12,age)*(1.0-smoothstep(.18,1.0,fly))
	if age >= (2.6 if level == 0 else CELEBRATION_TIME):
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
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
