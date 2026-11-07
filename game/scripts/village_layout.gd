class_name VillageLayout
extends Node2D
# One isometric ground coordinate system for plots, roads and occupancy.
const ORIGIN := Vector2(1130,720)
const AXIS_X := Vector2(32,16)
const AXIS_Y := Vector2(-32,16)
const CHIEF := Vector2(-5,-4)
const PLOTS := [Vector2(2,-4),Vector2(-5,3),Vector2(2,3),Vector2(9,3),Vector2(2,10),Vector2(9,10)]
const PLAYABLE := VillageBounds.PLAYABLE
var model:GameState
var layout_signature:=""
static func project(cell:Vector2)->Vector2:return ORIGIN+AXIS_X*cell.x+AXIS_Y*cell.y
static func anchor(cell:Vector2)->Vector2:return project(cell)+Vector2(0,24)
static func unproject(point:Vector2)->Vector2:
	var offset:=point-ORIGIN
	return Vector2(offset.x/64.0+offset.y/32.0,offset.y/32.0-offset.x/64.0)
static func polygon(cell:Vector2,span:int)->PackedVector2Array:
	var h:=span*.5
	return PackedVector2Array([project(cell+Vector2(-h,-h)),project(cell+Vector2(h,-h)),project(cell+Vector2(h,h)),project(cell+Vector2(-h,h))])
static func ground_ok(point:Vector2)->bool:return Geometry2D.is_point_in_polygon(point,PackedVector2Array(PLAYABLE))
static func plot_polygon(id:int)->PackedVector2Array:return polygon(PLOTS[id],4)
func _init(state:GameState)->void:model=state
func _ready()->void:
	z_index=-15;model.changed.connect(rebuild_art);rebuild_art()
func _draw()->void:
	# Clipped fine grid: square world cells project to the same 2:1 diamonds.
	for u in range(-30,31):
		for v in range(-30,31):
			var a:=project(Vector2(u,v));var b:=project(Vector2(u+1,v));var c:=project(Vector2(u,v+1))
			if ground_ok(a) and ground_ok(b):draw_line(a,b,Color(.94,.87,.55,.10),1,true)
			if ground_ok(a) and ground_ok(c):draw_line(a,c,Color(.94,.87,.55,.10),1,true)

func rebuild_art()->void:
	var chief:=model.building_position("chief")
	var signature:=str([model.chief_level(),chief,model.homes(),model.outposts(),model.facilities()])
	if signature==layout_signature:return
	layout_signature=signature
	for child in get_children():remove_child(child);child.queue_free()
	var positions:Array=[];var levels:Array=[]
	for i in model.built_count():positions.append(model.home_position(i));levels.append(int(model.homes()[i].get("level",1)))
	for i in model.outposts().size():positions.append(model.outpost_position(i));levels.append(int(model.outposts()[i].get("level",1)))
	for entry in model.facilities():
		positions.append(model.building_position(str(entry.kind)+":"+str(entry.uid)));levels.append(int(entry.get("level",1)))
	# Use actual saved building anchors, including free placement and moves.
	if model.chief_level()>0 and chief.is_finite():
		var start:=unproject(chief-Vector2(0,24))
		for at in positions:
			var target:=unproject(at-Vector2(0,24));var elbow:=Vector2(target.x,start.y)
			road(start,elbow);road(elbow,target)
		foundation(start,6,model.chief_level())
	for i in positions.size():foundation(unproject(positions[i]-Vector2(0,24)),4,levels[i])
	queue_redraw()
func foundation(cell:Vector2,span:int,level:int=1)->void:
	var id:="GROUND-PAD-L%d"%clampi(level,1,4)
	var entry:=AssetCatalog.entry(id)
	var bounds:Array=entry.alpha_bounds
	var s:=Sprite2D.new();s.texture=AssetCatalog.texture(id)
	# Preserve the old visible ground extent and centre; source PNG padding stays intact.
	var visible_size:=Vector2(float(span)*64.0,float(span)*64.0*676.0/1088.0*.81)
	s.scale=visible_size/Vector2(bounds[2],bounds[3])
	s.offset=s.texture.get_size()*.5-(Vector2(bounds[0],bounds[1])+Vector2(bounds[2],bounds[3])*.5)
	s.position=project(cell)+Vector2(0,span*6)
	s.set_meta("foundation_level",clampi(level,1,4));s.set_meta("foundation_cell",cell);s.set_meta("foundation_span",span)
	s.z_index=1;s.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(s)
func road(a:Vector2,b:Vector2)->void:
	if a==b:return
	var delta:=b-a
	# Continuous one-cell-wide ribbon in the same isometric grid as the floor.
	# Old diamond stamps narrowed to a point where neighbouring tiles met.
	var along:=delta.normalized();var across:=Vector2(-along.y,along.x)*.5
	var polygon:=Polygon2D.new();polygon.name="RoadCellRibbon"
	polygon.polygon=PackedVector2Array([project(a-along*.5-across),project(b+along*.5-across),project(b+along*.5+across),project(a-along*.5+across)])
	polygon.texture=AssetCatalog.texture("GROUND-ROAD")
	var tex_size:=polygon.texture.get_size()
	polygon.uv=PackedVector2Array([Vector2.ZERO,Vector2(tex_size.x,0),tex_size,Vector2(0,tex_size.y)])
	var material:=ShaderMaterial.new();material.shader=load("res://assets/ui/v0158/road_ribbon.gdshader");polygon.material=material
	polygon.antialiased=true;polygon.z_index=1;polygon.set_meta("grid_width",1.0);add_child(polygon)
