class_name RoundAsset
extends Control
func _ready() -> void:
	clip_children=CanvasItem.CLIP_CHILDREN_ONLY
	mouse_filter=Control.MOUSE_FILTER_IGNORE
func _draw() -> void:draw_circle(size*.5,minf(size.x,size.y)*.5,Color.WHITE,true,-1,true)
