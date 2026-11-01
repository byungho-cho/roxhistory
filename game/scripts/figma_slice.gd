class_name FigmaSlice
extends Control

var kind:="paper"
var corner:=24.0
var source:Texture2D
func _init(asset:String="paper",corner_size:float=24) -> void:
	kind=asset;corner=corner_size;mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
func _ready() -> void:
	source=FigmaArt.texture(kind);resized.connect(queue_redraw);queue_redraw()
func _process(_delta:float) -> void:
	var button:=get_parent() as Button
	if button:
		modulate=Color(.82,.78,.7,.62) if button.disabled else Color(.9,.85,.72,1) if button.is_pressed() else Color.WHITE
func _draw() -> void:
	if not source:return
	paint(self,source,size,kind,corner)

static func paint(target:CanvasItem,source:Texture2D,size:Vector2,kind:String,corner:float) -> void:
	var source_size:=source.get_size()
	var source_x:PackedFloat32Array
	var source_y:PackedFloat32Array
	var dest_x:PackedFloat32Array
	var dest_y:PackedFloat32Array
	if kind=="gold":
		# Three source slices retain both end ornaments at every button width.
		source_x=PackedFloat32Array([0,225,source_size.x-228,source_size.x]);source_y=PackedFloat32Array([0,source_size.y])
		var cap:=minf(corner,size.x*.33);dest_x=PackedFloat32Array([0,cap,size.x-cap,size.x]);dest_y=PackedFloat32Array([0,size.y])
	else:
		source_x=PackedFloat32Array([0,90,source_size.x-90,source_size.x]);source_y=PackedFloat32Array([0,90,source_size.y-90,source_size.y])
		var cap:=minf(corner,minf(size.x,size.y)*.4)
		dest_x=PackedFloat32Array([0,cap,size.x-cap,size.x]);dest_y=PackedFloat32Array([0,cap,size.y-cap,size.y])
	for y in source_y.size()-1:
		for x in source_x.size()-1:
			var src:=Rect2(source_x[x],source_y[y],source_x[x+1]-source_x[x],source_y[y+1]-source_y[y])
			var dst:=Rect2(dest_x[x],dest_y[y],dest_x[x+1]-dest_x[x],dest_y[y+1]-dest_y[y])
			target.draw_texture_rect_region(source,dst,src)
