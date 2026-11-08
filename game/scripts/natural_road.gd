class_name NaturalRoad
extends Node2D
## Ground-cell geometry keeps the opaque core wider than one complete grid cell.
const WIDTH:=1.6
const MIN_WIDTH:=1.4
var cells:=PackedVector2Array()
func _init(path:PackedVector2Array)->void:
	cells=sample_path(path);name="NaturalRoad";set_meta("grid_width",WIDTH);set_meta("minimum_grid_width",MIN_WIDTH)
static func sample_path(path:PackedVector2Array)->PackedVector2Array:
	var result:=PackedVector2Array()
	for i in range(path.size()-1):
		var steps:=maxi(1,ceili(path[i].distance_to(path[i+1])/.6))
		for step in steps:result.append(path[i].lerp(path[i+1],float(step)/steps))
	if not path.is_empty():result.append(path[-1])
	return result
static func curved_path(a:Vector2,b:Vector2)->PackedVector2Array:
	var corner:=Vector2(b.x,a.y)
	if absf(a.x-b.x)<.05 or absf(a.y-b.y)<.05 or minf(a.distance_to(corner),b.distance_to(corner))<2:return PackedVector2Array([a,b])
	var radius:=minf(1.8,minf(a.distance_to(corner),b.distance_to(corner))*.45)
	var start:=corner-(corner-a).normalized()*radius;var finish:=corner+(b-corner).normalized()*radius
	var points:=PackedVector2Array([a,start])
	for i in range(1,13):
		var t:=float(i)/12;points.append(start*(1-t)*(1-t)+corner*2*(1-t)*t+finish*t*t)
	points.append(b);return points
func edges()->Dictionary:
	var left:=PackedVector2Array();var right:=PackedVector2Array();var outer_left:=PackedVector2Array();var outer_right:=PackedVector2Array()
	for i in cells.size():
		var along:Vector2=(cells[mini(i+1,cells.size()-1)]-cells[maxi(0,i-1)]).normalized()
		var across:=Vector2(-along.y,along.x)
		var wave:=sin(cells[i].x*2.1+cells[i].y*1.7)*.11
		var half_width:=WIDTH*.5+sin(cells[i].x*3.4-cells[i].y*2.7)*.08
		left.append(cells[i]+across*(half_width+wave));right.append(cells[i]-across*(half_width-wave))
		outer_left.append(cells[i]+across*(half_width+wave+.4+.08*sin(cells[i].x*4.1+cells[i].y*2.3)));outer_right.append(cells[i]-across*(half_width-wave+.4+.08*cos(cells[i].x*2.7-cells[i].y*3.9)))
	return {"left":left,"right":right,"outer_left":outer_left,"outer_right":outer_right}
func _ready()->void:
	if cells.size()<2:return
	var outline:=edges()
	strip(outline.outer_left,outline.left,0,.93,"SoftLeftEdge")
	strip(outline.right,outline.outer_right,.93,0,"SoftRightEdge")
	strip(outline.left,outline.right,.93,.93,"RoadSoil")
func strip(first:PackedVector2Array,second:PackedVector2Array,alpha_first:float,alpha_second:float,id:String)->void:
	var points:=PackedVector2Array();var colors:=PackedColorArray()
	for cell in first:points.append(VillageLayout.project(cell));colors.append(Color(1,1,1,alpha_first))
	for i in range(second.size()-1,-1,-1):points.append(VillageLayout.project(second[i]));colors.append(Color(1,1,1,alpha_second))
	var polygon:=Polygon2D.new();polygon.name=id;polygon.polygon=points;polygon.vertex_colors=colors;polygon.antialiased=true
	polygon.texture=AssetCatalog.texture("GROUND-ROAD")
	var material:=ShaderMaterial.new();material.shader=preload("res://shaders/natural_road.gdshader");polygon.material=material
	add_child(polygon)
