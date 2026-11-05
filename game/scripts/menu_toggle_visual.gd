class_name MenuToggleVisual
extends Control
## Original Figma 861:50 sources and crops live in AssetCatalog.
var expanded:=false
func _ready()->void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 size=Vector2(56,56)
func _draw()->void:
 draw_texture_rect(AssetCatalog.texture("UI-MENU-COLLAPSE" if expanded else "UI-MENU-EXPAND"),Rect2(1,1,54,54),false)
