class_name VillageEdgeClouds
extends Node2D
var player:DemoPlayer
func _ready()->void:
	name="VillageEdgeClouds";z_index=-18;visibility_layer=2
	var texture=preload("res://assets/terrain-review-v001/fog-cloud.png")
	# World anchored decoration outside the unchanged playable polygon.
	for entry in [[Vector2(-850,-450),Vector2(1100,600)], [Vector2(3200,-450),Vector2(1100,600)], [Vector2(-850,1950),Vector2(1100,600)], [Vector2(3200,1950),Vector2(1100,600)]]:
		var cloud:=Sprite2D.new();cloud.texture=texture;cloud.position=entry[0];cloud.scale=entry[1]/texture.get_size();add_child(cloud)
func _process(_delta:float)->void:
	if not is_instance_valid(player):return
	modulate.a=.24*(1.0-smoothstep(.56,1.25,player.zoom_factor))
	visible=modulate.a>0.001
