class_name VillageEdgeClouds
extends Node2D
var player:DemoPlayer
const ROOT:="res://assets/village-edge-v001/"
const EDGE_DEPTH:=20.0
# Source pixels with alpha >= 8/255. get_used_rect() also includes scattered,
# nearly transparent pixels far outside the cloud, hiding the entire 20px edge.
# Keep the approved source art intact and exclude only that empty fringe.
const CLOUD_REGIONS:={
	"cloud-a-diagonal-up.png":Rect2(131,275,1259,543),
	"cloud-b-diagonal-down.png":Rect2(366,356,756,293),
}
func _ready()->void:
	name="VillageEdgeClouds";z_index=-18;visibility_layer=2
	# Camera-relative decoration, never an input to world geometry or collisions.
	for filename in ["cloud-b-diagonal-down.png","cloud-a-diagonal-up.png","cloud-a-diagonal-up.png","cloud-b-diagonal-down.png"]:
		var texture:=AtlasTexture.new();texture.atlas=load(ROOT+filename)
		texture.region=CLOUD_REGIONS[filename];texture.filter_clip=true
		var cloud:=Sprite2D.new();cloud.texture=texture
		cloud.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		cloud.scale=Vector2.ONE*180.0/texture.region.size.x
		cloud.set_meta("visible_height",texture.region.size.y*cloud.scale.y)
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
	# The normal starting view must be readable, not already faded to 9%.
	# Fade only when zooming in, and retain the maximum-zoom exclusion.
	modulate.a=.30*(1.0-smoothstep(1.0,DemoPlayer.MAX_ZOOM,player.zoom_factor))
	visible=modulate.a>0.001
