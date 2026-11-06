class_name VillageEdgeClouds
extends Node2D
var player:DemoPlayer
const ROOT:="res://assets/village-edge-v001/"
func _ready()->void:
	name="VillageEdgeClouds";z_index=-18;visibility_layer=2
	# Anchored to world corners; full PNGs preserved, transparent margins accounted for.
	for entry in [["cloud-b-diagonal-down.png",Vector2(-950,-540)], ["cloud-a-diagonal-up.png",Vector2(3350,-540)], ["cloud-a-diagonal-up.png",Vector2(-950,1890)], ["cloud-b-diagonal-down.png",Vector2(3350,1890)]]:
		var cloud:=Sprite2D.new();cloud.texture=load(ROOT+str(entry[0]))
		var used:Rect2=cloud.texture.get_image().get_used_rect()
		cloud.centered=false;cloud.offset=-used.get_center()
		cloud.position=entry[1];cloud.scale=Vector2.ONE*600.0/used.size.x
		add_child(cloud)
func _process(_delta:float)->void:
	if not is_instance_valid(player):return
	modulate.a=.30*(1.0-smoothstep(.56,1.25,player.zoom_factor))
	visible=modulate.a>0.001
