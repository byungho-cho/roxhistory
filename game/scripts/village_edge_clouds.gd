class_name VillageEdgeClouds
extends Node2D
var player:DemoPlayer
const ROOT:="res://assets/village-edge-v001/"
const EDGE_DEPTH:=20.0
func _ready()->void:
	name="VillageEdgeClouds";z_index=-18;visibility_layer=2
	# Camera-relative decoration, never an input to world geometry or collisions.
	for filename in ["cloud-b-diagonal-down.png","cloud-a-diagonal-up.png","cloud-a-diagonal-up.png","cloud-b-diagonal-down.png"]:
		var cloud:=Sprite2D.new();cloud.texture=load(ROOT+filename)
		var used:Rect2=cloud.texture.get_image().get_used_rect()
		cloud.centered=false;cloud.offset=-used.get_center()
		cloud.scale=Vector2.ONE*180.0/used.size.x
		cloud.set_meta("visible_height",used.size.y*cloud.scale.y)
		add_child(cloud)
func _process(_delta:float)->void:
	if not is_instance_valid(player):return
	# Cancel camera zoom/pan so every aspect ratio retains a subtle 20px edge.
	global_transform=get_viewport().get_canvas_transform().affine_inverse()
	var size:=get_viewport_rect().size
	for i in get_child_count():
		var cloud:Sprite2D=get_child(i)
		var half_height:=float(cloud.get_meta("visible_height"))*.5
		cloud.position=Vector2(0 if i%2==0 else size.x,-half_height+EDGE_DEPTH if i<2 else size.y+half_height-EDGE_DEPTH)
	modulate.a=.30*(1.0-smoothstep(.56,1.25,player.zoom_factor))
	visible=modulate.a>0.001
