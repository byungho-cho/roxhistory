extends Node2D

const DUST := preload("res://assets/ui/d0019/ground-dust-soft.png")
var age := 0.0
var level: int
var label: Label

func _init(at: Vector2, target_level: int) -> void:
	position = at
	level = target_level
	z_index = 10 if level == 0 else 5
	visibility_layer = 2

func _ready() -> void:
	if level <= 0: return
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
	draw_set_transform(Vector2.ZERO,0,Vector2(1,.30))
	draw_circle(Vector2.ZERO,62,Color(1,.73,.25,alpha*.24))
	draw_set_transform(Vector2.ZERO)
	for i in 9:
		var at := Vector2(sin(i*2.4)*56,-age*(42+i*9))
		draw_circle(at,2.4,Color(1,.84,.45,.85*alpha))
	for side in [-1,1]:
		var t := age-(.14 if side==1 else 0.0)
		if t < 0 or t > .48: continue
		var center := Vector2(side*75,-118)
		for i in 5:
			var direction := Vector2.from_angle(i*TAU/5)
			draw_line(center+direction*t*42,center+direction*(t*42+7),Color(1,.79,.36,1.0-t/.48),2,true)
