extends Node2D

const DUST := preload("res://assets/ui/d0019/ground-dust-soft.png")
const CELEBRATION_TIME := 2.05
const FIREWORK_COLORS := [Color("ffce52"),Color("ff816e"),Color("7ce9d2"),Color("fff0a9")]
var age := 0.0
var level: int
var label: Label
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
	label = FigmaArt.text(self,"Lv. %d 달성!" % level,Rect2(-90,-174,180,36),24,FigmaArt.BODY,Color("ffe29d"))
	label.add_theme_constant_override("outline_size",4)
	label.add_theme_color_override("font_outline_color",Color("503016"))
	label.pivot_offset = label.size*.5
	label.scale = Vector2.ONE*.48
	label.modulate.a = 0.0

func _process(delta: float) -> void:
	age += delta
	if level > 0:
		var zoom := get_global_transform_with_canvas().get_scale().x / scale.x
		scale = Vector2.ONE*clampf(.48/maxf(zoom,.01),1.0,1.8)
		label.position.y = -174-age*16
		var entrance := 1.0-pow(1.0-clampf(age/.30,0,1),3)
		label.scale = Vector2.ONE*(lerpf(.48,1.08,entrance)+.34*smoothstep(.76,1.94,age))
		label.modulate.a = smoothstep(0,.13,age)*(1.0-smoothstep(1.05,1.94,age))
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
	var alpha := 1.0-smoothstep(.4,1.45,age)
	var flash := (1.0-smoothstep(.11,.85,age))*smoothstep(0.0,.09,age)
	draw_texture_rect(glow,Rect2(-128,-178,256,206),false,Color(1,1,1,flash))
	for i in 7:
		var x := (i-3)*23.0
		var height := (90.0+sin(i*2.4)*38.0)*smoothstep(0.0,.30,age)
		var tip := Vector2(x*1.28,-35-height)
		var base := Vector2(x,-14)
		draw_colored_polygon(PackedVector2Array([base+Vector2(-6,0),base+Vector2(6,0),tip]),Color(1,.81,.36,flash*.40))
	draw_set_transform(Vector2.ZERO,0,Vector2(1,.30))
	draw_circle(Vector2.ZERO,62,Color(1,.73,.25,alpha*.24))
	draw_set_transform(Vector2.ZERO)
	for i in 15:
		var at := Vector2(sin(i*2.4)*(34+age*43),-24-age*(42+i*6))
		var size := 2.0+2.0*absf(sin(i*2.4+age*11.0))
		var color := Color(1,.89,.53,.90*alpha)
		draw_line(at-Vector2(size,0),at+Vector2(size,0),color,1.4,true)
		draw_line(at-Vector2(0,size*1.45),at+Vector2(0,size*1.45),color,1.4,true)
	draw_firework(Vector2(-26,-18),Vector2(-112,-137),.03,0)
	draw_firework(Vector2(26,-18),Vector2(113,-151),.19,2)
	draw_firework(Vector2(0,-25),Vector2(0,-229),.47,1)

func draw_firework(start: Vector2, center: Vector2, delay: float, palette_offset: int) -> void:
	const ASCENT := .24
	var elapsed := age-delay
	if elapsed < 0.0 or elapsed > ASCENT+.86: return
	if elapsed < ASCENT:
		var progress := elapsed/ASCENT
		var tip := start.lerp(center,progress)
		draw_line(start.lerp(center,maxf(0.0,progress-.23)),tip,Color(1,.78,.34,.83),2.0,true)
		draw_circle(tip,3.0,Color("fff7ca"))
		return
	var time := elapsed-ASCENT
	var fade := 1.0-smoothstep(.16,.86,time)
	var reach := 1.0-exp(-time*4.5)
	if time < .16:
		draw_texture_rect(glow,Rect2(center-Vector2.ONE*36,Vector2.ONE*72),false,Color(1,1,1,1.0-time/.16))
	for i in 19:
		var direction := Vector2.from_angle(i*TAU/19.0+palette_offset*.15)
		var distance := (39.0+float((i*7)%8)*6.0)*reach
		var tip := center+direction*distance+Vector2(0,47.0*time*time)
		var color: Color = FIREWORK_COLORS[(i+palette_offset)%FIREWORK_COLORS.size()]
		color.a = fade
		draw_line(tip-direction*minf(distance,5.0+8.0*fade),tip,color,2.0,true)
		draw_circle(tip,1.5+fade,color)
