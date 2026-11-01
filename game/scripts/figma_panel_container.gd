class_name FigmaPanelContainer
extends PanelContainer
var paper:Texture2D
func _ready() -> void:
	paper=FigmaArt.texture("paper");texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var spacing:=StyleBoxEmpty.new();spacing.set_content_margin_all(18)
	add_theme_stylebox_override("panel",spacing);resized.connect(queue_redraw)
func _draw() -> void:
	if paper:FigmaSlice.paint(self,paper,size,"paper",16)
