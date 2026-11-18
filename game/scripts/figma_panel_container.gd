class_name FigmaPanelContainer
extends PanelContainer
var paper:Texture2D
var shared_shell: Texture2D
func _ready() -> void:
	paper=FigmaArt.texture("paper");texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var spacing:=StyleBoxEmpty.new();spacing.set_content_margin_all(SharedPopupArt.INSET)
	add_theme_stylebox_override("panel",spacing);resized.connect(queue_redraw)
func _draw() -> void:
	if shared_shell:
		draw_texture_rect(shared_shell,Rect2(Vector2.ZERO,size),false)
	elif paper:FigmaSlice.paint(self,paper,size,"paper",16)
