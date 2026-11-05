class_name VillageLayout
extends Node2D
# One isometric ground coordinate system for plots, roads and occupancy.
const ORIGIN := Vector2(1130,720)
const AXIS_X := Vector2(32,16)
const AXIS_Y := Vector2(-32,16)
const CHIEF := Vector2(-5,-4)
const PLOTS := [Vector2(2,-4),Vector2(-5,3),Vector2(2,3),Vector2(9,3),Vector2(2,10),Vector2(9,10)]
const PLAYABLE := [Vector2(440,180),Vector2(1790,180),Vector2(2250,370),Vector2(2250,1080),Vector2(1840,1210),Vector2(440,1210),Vector2(160,1000),Vector2(160,400)]
var model:GameState
static func project(cell:Vector2)->Vector2:return ORIGIN+AXIS_X*cell.x+AXIS_Y*cell.y
static func anchor(cell:Vector2)->Vector2:return project(cell)+Vector2(0,24)
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
	for child in get_children():remove_child(child);child.queue_free()
	# Roads exist only between completed homes and the chief; sprites never own physics.
	for home_data in model.homes():
		var target:Vector2=PLOTS[int(home_data.get("site",0))]
		var elbow:=Vector2(target.x,CHIEF.y)
		road(CHIEF,elbow);road(elbow,target)
	foundation(CHIEF,6)
	for home_data in model.homes():foundation(PLOTS[int(home_data.get("site",0))],4)
	queue_redraw()
func foundation(cell:Vector2,span:int)->void:
	var s:=Sprite2D.new();s.texture=AssetCatalog.texture("GROUND-PAD");s.scale=Vector2.ONE*(span*64.0/1088.0)
	s.position=project(cell)+Vector2(0,span*6);s.scale.y*=.81
	var material:=ShaderMaterial.new();material.shader=preload("res://shaders/pad_edge.gdshader");s.material=material;s.z_index=1;s.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(s)
func road(a:Vector2,b:Vector2)->void:
	if a==b:return
	var delta:=b-a
	var steps:=int(maxf(absf(delta.x),absf(delta.y)))
	for i in steps:
		var c:=a+delta*(float(i)+.5)/steps
		var s:=Sprite2D.new();s.texture=AssetCatalog.texture("GROUND-ROAD");s.position=project(c)
		# Extract the central connecting section in the shader; consistent 1-cell width.
		var material:=ShaderMaterial.new();material.shader=preload("res://shaders/road_tile.gdshader");s.material=material;s.z_index=1;s.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		s.scale=Vector2(64.0/s.texture.get_width(),32.0/s.texture.get_height());s.flip_h=delta.x!=0
		add_child(s)
