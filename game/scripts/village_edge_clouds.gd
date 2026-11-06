class_name VillageEdgeClouds
extends Node2D
var player:DemoPlayer
func _ready()->void:
	name="VillageEdgeClouds";z_index=-18;visibility_layer=2
	var texture=preload("res://assets/terrain-review-v001/fog-cloud.png")
	# World anchored decoration outside the unchanged playable polygon.
	for entry in [[Vector2(-620,0),Vector2(1500,850)], [Vector2(2900,100),Vector2(1400,800)], [Vector2(300,-620),Vector2(1600,850)], [Vector2(1900,-650),Vector2(1500,850)], [Vector2(200,1850),Vector2(1700,850)], [Vector2(2200,1850),Vector2(1600,850)]]:
		var cloud:=Sprite2D.new();cloud.texture=texture;cloud.position=entry[0];cloud.scale=entry[1]/texture.get_size();add_child(cloud)
func _process(_delta:float)->void:
	if not is_instance_valid(player):return
	modulate.a=.38*(1.0-smoothstep(.56,1.25,player.zoom_factor))
	visible=modulate.a>0.001
