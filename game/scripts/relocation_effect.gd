class_name RelocationEffect
extends Node2D
## Relocation is one saved move, with two visual phases and no economy change.
const PHASE:=1.5
var clock:=0.0
var app:Node
var key:String
var source:Sprite2D
var destination:Sprite2D
var destination_color:=Color.WHITE
var old_position:Vector2
var new_position:Vector2
var hammer:=preload("res://assets/effects/construction-hammer.png")
func _init(owner_app:Node,id:String,old_image:Sprite2D,from:Vector2,to:Vector2)->void:
	app=owner_app;key=id;source=old_image;old_position=from;new_position=to
	name="RelocationEffect";visibility_layer=2;z_index=2
func _ready()->void:
	add_child(source)
	destination=app.world.building_sprite(key)
	if is_instance_valid(destination):
		destination_color=destination.self_modulate
		destination.self_modulate.a=0
func _process(delta:float)->void:
	clock+=delta
	source.modulate.a=1.0-smoothstep(.9,PHASE,clock)
	if is_instance_valid(destination):destination.self_modulate.a=destination_color.a*smoothstep(PHASE,PHASE*2,clock)
	if clock>=PHASE*2:queue_free();return
	queue_redraw()
func _draw()->void:
	var rebuilding:=clock>=PHASE
	var at:=new_position if rebuilding else old_position
	var t:=fmod(clock,PHASE)/PHASE
	var envelope:=sin(t*PI)
	for i in 18:
		var u:=fmod(t+i*.071,1.0)
		var p:=at+Vector2(cos(i*2.4)*(25+u*55),sin(i*2.4)*12-u*22)
		for layer in [3,2,1]:draw_circle(p,(3+u*8)*layer*.5,Color(.68,.55,.34,envelope*(1-u)*.05))
	for side in [-1,1]:
		var swing:=sin(clock*TAU*2.7+(PI if side==1 else 0))
		draw_set_transform(at+Vector2(side*55,-32),side*(.5+swing*.55),Vector2(side,1))
		draw_texture_rect(hammer,Rect2(-17,-32,34,40),false,Color(1,1,1,envelope))
	draw_set_transform(Vector2.ZERO)
	if rebuilding:
		for i in 8:
			var u:=fmod(t+i*.125,1.0)
			draw_circle(at+Vector2(sin(i*2.1)*65,-u*65),1.5,Color(1,.85,.35,envelope*(1-u)*.6))
func _exit_tree()->void:
	if is_instance_valid(destination):destination.self_modulate=destination_color
	if is_instance_valid(app):app.relocating_key=""
