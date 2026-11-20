extends Node2D
# Model-test presentation only: sampled from the lab clock, with no timers,
# input nodes, colliders, reward calls or connections to live hunting.
const ANGEL=preload("res://assets/ui/death-preview/ally-angel-common.png")
const TOMBSTONE=preload("res://assets/ui/death-preview/ally-tombstone.png")
const MEAT=preload("res://assets/figma-latest/meat.png")
const DUST=preload("res://assets/ui/d0019/ground-dust-soft.png")
const HIDE_BEGIN:=.10
const HIDE_END:=.18
var ally:=true
var age:=-1.0

func _init(is_ally:=true)->void:
	ally=is_ally
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	visible=false

func clear()->void:
	if age<0:return
	age=-1.0;hide();queue_redraw()

func sample(seconds:float)->void:
	age=maxf(0,seconds);visible=age>=.08;queue_redraw()

static func model_alpha(seconds:float)->float:
	return 1.0-smoothstep(HIDE_BEGIN,HIDE_END,seconds)

func _draw()->void:
	if age<.08:return
	if ally:draw_ally()
	else:draw_monster()

func ellipse(center:Vector2,radii:Vector2,color:Color)->void:
	var points:=PackedVector2Array()
	for i in 32:
		var angle:=TAU*i/32.0
		points.append(center+Vector2(cos(angle),sin(angle))*radii)
	draw_colored_polygon(points,color)

func draw_ally()->void:
	var grave_alpha:=smoothstep(.10,.24,age)
	ellipse(Vector2(0,1),Vector2(15,3),Color(0,0,0,.18*grave_alpha))
	draw_texture_rect(TOMBSTONE,Rect2(-23,-43,46,46),false,Color(1,1,1,grave_alpha))
	var soul_alpha:=smoothstep(.08,.20,age)*(1.0-smoothstep(1.10,1.75,age))
	if soul_alpha<=0:return
	var rise:=clampf((age-.10)/1.50,0,1)
	var center:=Vector2(sin(rise*PI)*2.5,-40-75*rise)
	draw_texture_rect(DUST,Rect2(center-Vector2(36,36),Vector2(72,72)),false,Color(1,.87,.52,.12*soul_alpha))
	draw_texture_rect(ANGEL,Rect2(center-Vector2(38,38),Vector2(76,76)),false,Color(1,1,1,soul_alpha))
	for i in 7:
		var progress:=fposmod(rise+float(i)*.137,1.0)
		var at:=Vector2(sin(i*2.7)*18,-8-progress*85)
		var alpha:=soul_alpha*sin(progress*PI)*.75
		var radius:=1.2+float(i%2)*.7
		draw_line(at-Vector2(radius,0),at+Vector2(radius,0),Color(1,.88,.45,alpha),.8,true)
		draw_line(at-Vector2(0,radius),at+Vector2(0,radius),Color(1,.88,.45,alpha),.8,true)

func draw_monster()->void:
	var progress:=clampf((age-.06)/.70,0,1)
	var dust_alpha:=1.0-smoothstep(.20,.78,age)
	if dust_alpha>0:
		var radius:=18+50*(1-pow(1-progress,2))
		draw_texture_rect(DUST,Rect2(-radius,-radius*.27,radius*2,radius*.54),false,Color(.75,.57,.34,.66*dust_alpha))
		draw_texture_rect(DUST,Rect2(-radius*.80,-radius*.24-3,radius*1.60,radius*.48),false,Color(.82,.65,.43,.85*dust_alpha))
		var ring:=PackedVector2Array()
		for i in 49:
			var angle:=TAU*i/48.0
			ring.append(Vector2(cos(angle)*radius,sin(angle)*radius*.20))
		draw_polyline(ring,Color(1,.90,.65,.70*dust_alpha),1.0,true)
		for i in 11:
			var angle:=TAU*float(i)/11.0
			var at:=Vector2(cos(angle)*(10+43*progress),sin(angle)*11*progress-sin(progress*PI)*(10+i%3*4))
			var points:=PackedVector2Array()
			for corner in [Vector2(-2,-1),Vector2(1,-2),Vector2(2,1),Vector2(-1,2)]:
				points.append(at+corner.rotated(angle+progress*2)*(1+float(i%3)*.2))
			draw_colored_polygon(points,Color(.52+float(i%2)*.1,.39,.24,dust_alpha))
	if age>=.16:
		var flight:=clampf((age-.16)/.50,0,1)
		var bounce:=-30*4*flight*(1-flight)
		if age>.66 and age<.86:bounce=-5*sin((age-.66)/.20*PI)
		var alpha:=smoothstep(.16,.24,age)
		draw_meat_shadow(alpha)
		var size:=Vector2(29,29*float(MEAT.get_height())/MEAT.get_width())
		draw_texture_rect(MEAT,Rect2(Vector2(-size.x*.5,-size.y-3+bounce),size),false,Color(1,1,1,alpha))

func draw_meat_shadow(alpha:float)->void:
	ellipse(Vector2(0,0),Vector2(10,2.4),Color(0,0,0,.18*alpha))
