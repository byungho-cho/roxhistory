extends Node2D

const DUST := preload("res://assets/ui/d0019/ground-dust-soft.png")
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

func _process(delta: float) -> void:
	age += delta
	if level > 0:
		label.position.y = -174-age*12
		label.modulate.a = 1.0-smoothstep(.95,1.65,age)
	if age >= (2.6 if level == 0 else 1.65):
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
	for side in [-1,1]:
		var t := age-(.14 if side==1 else 0.0)
		if t < 0 or t > .48: continue
		var center := Vector2(side*75,-118)
		for i in 5:
			var direction := Vector2.from_angle(i*TAU/5)
			draw_line(center+direction*t*42,center+direction*(t*42+7),Color(1,.79,.36,1.0-t/.48),2,true)
