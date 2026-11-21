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

const COMPACT_SIZE:=Vector2(58,4)
const COMPACT_OUTER:=COMPACT_SIZE+Vector2(2,2)
const COMPACT_CLEARANCE:=26.0

static func duel_team_color(ally:bool)->Color:
	return Color("46b6ff") if ally else Color("ff454e")

static func create_compact(parent:Node,ally:bool)->Dictionary:
	var entry:=create(parent,"",ally)
	var outline:=StyleBoxFlat.new()
	outline.draw_center=true
	outline.bg_color=Color("090b10",.83)
	outline.border_color=Color("343d4c",.90)
	outline.set_border_width_all(1)
	outline.set_corner_radius_all(2)
	entry.panel.add_theme_stylebox_override("panel",outline)
	entry.panel.size=COMPACT_OUTER
	entry.label.hide()
	entry.bar.texture_under=null
	var fill:GradientTexture2D=entry.bar.texture_progress
	fill.width=int(COMPACT_SIZE.x);fill.height=int(COMPACT_SIZE.y)
	var team:=duel_team_color(ally)
	fill.gradient.colors=PackedColorArray([team,team])
	entry.bar.position=Vector2.ONE;entry.bar.size=COMPACT_SIZE
	entry.bar.modulate.a=.90
	return entry

static func layout_compact(headers:Array,points:Array,bounds:Rect2)->void:
	var occupied:Array[Rect2]=[]
	for i in headers.size():
		var clearance:=COMPACT_CLEARANCE if i==0 else 13.0
		var base:Vector2=(points[i]-Vector2(COMPACT_OUTER.x*.5,COMPACT_OUTER.y+clearance)).clamp(bounds.position,bounds.end-COMPACT_OUTER)
		var chosen:=Rect2(base,COMPACT_OUTER)
		for offset in [Vector2.ZERO,Vector2(0,-9),Vector2(-64,0),Vector2(64,0)]:
			chosen=Rect2((base+offset).clamp(bounds.position,bounds.end-COMPACT_OUTER),COMPACT_OUTER)
			if not occupied.any(func(other):return other.grow(2).intersects(chosen)):break
		headers[i].panel.position=chosen.position
		occupied.append(chosen)