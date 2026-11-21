extends RefCounted
const SIZE:=Vector2(70,24)
static var offsets:Array[Vector2]=[]
static func create(parent:Node,name:String,ally:bool)->Dictionary:
	var panel:=Panel.new();panel.size=SIZE;panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.z_index=30
	var style:=StyleBoxFlat.new();style.bg_color=Color(.125,.102,.071,.91);style.border_color=Color("be9b66");style.set_border_width_all(1);style.set_corner_radius_all(5);panel.add_theme_stylebox_override("panel",style);parent.add_child(panel)
	var label:=Label.new();label.text=name;label.position=Vector2(3,1);label.size=Vector2(64,13);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.mouse_filter=Control.MOUSE_FILTER_IGNORE;label.add_theme_font_size_override("font_size",10);label.add_theme_color_override("font_color",Color("fff0ca"));panel.add_child(label)
	var bar:=TextureProgressBar.new();bar.position=Vector2(6,17);bar.size=Vector2(58,4);bar.step=0;bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var track:=GradientTexture2D.new();track.width=58;track.height=4;track.gradient=Gradient.new();track.gradient.colors=PackedColorArray([Color("3b2b21"),Color("3b2b21")]);bar.texture_under=track
	var fill:=GradientTexture2D.new();fill.width=58;fill.height=4;fill.gradient=Gradient.new();var color:=Color("a5da59") if ally else Color("f57856");fill.gradient.colors=PackedColorArray([color,color]);bar.texture_progress=fill;panel.add_child(bar)
	return {"panel":panel,"label":label,"bar":bar}
static func layout(headers:Array,points:Array,bounds:Rect2)->void:
	if offsets.is_empty():
		for row in range(-4,5):
			for column in range(-4,5):offsets.append(Vector2(column*74,row*28))
		offsets.sort_custom(func(a:Vector2,b:Vector2):return a.length_squared()<b.length_squared())
	var occupied:Array[Rect2]=[]
	for i in headers.size():
		var base:Vector2=(points[i]-Vector2(SIZE.x*.5,SIZE.y+8)).clamp(bounds.position,bounds.end-SIZE)
		var chosen:=Rect2(base,SIZE)
		for offset in offsets:
			var rect:=Rect2((base+offset).clamp(bounds.position,bounds.end-SIZE),SIZE);chosen=rect
			if not occupied.any(func(other):return other.grow(2).intersects(rect)):break
		headers[i].panel.position=chosen.position;occupied.append(chosen)
