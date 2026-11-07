class_name DemolitionEffect
extends Node2D
## The model commits once; this retained sprite finishes the visual transition.
const DURATION:=1.5
var clock:=0.0
var ghost:Sprite2D
var hammer:=preload("res://assets/effects/construction-hammer.png")
func _init(image:Sprite2D)->void:ghost=image;name="DemolitionEffect";visibility_layer=2;z_index=2
func _process(delta:float)->void:
	clock+=delta
	if is_instance_valid(ghost):
		ghost.modulate.a=1.0-smoothstep(1.05,DURATION,clock)
	if clock>=DURATION:queue_free();return
	queue_redraw()
func _draw()->void:
	var envelope:=sin(clampf(clock/DURATION,0,1)*PI)
	for i in 14:
		var t:=fmod(clock*.9+i*.071,1.0)
		var p:=Vector2(cos(i*2.4)*(25+t*50),sin(i*2.4)*13-t*19)
		for layer in [3,2,1]:draw_circle(p,(3+t*8)*layer*.5,Color(.66,.53,.35,envelope*(1-t)*.04))
	for side in [-1,1]:
		var swing:=sin(clock*TAU*2.7+(PI if side==1 else 0))
		draw_set_transform(Vector2(side*55,-35),side*(.5+swing*.55),Vector2(side,1))
		draw_texture_rect(hammer,Rect2(-17,-32,34,40),false,Color(1,1,1,minf(1,(DURATION-clock)*4)))
	draw_set_transform(Vector2.ZERO)
