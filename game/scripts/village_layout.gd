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
	z_index=-15;model.changed.connect(queue_redraw)
func _draw()->void:
	# Clipped fine grid: square world cells project to the same 2:1 diamonds.
	for u in range(-30,31):
		for v in range(-30,31):
			var a:=project(Vector2(u,v));var b:=project(Vector2(u+1,v));var c:=project(Vector2(u,v+1))
			if ground_ok(a) and ground_ok(b):draw_line(a,b,Color(.94,.87,.55,.10),1,true)
			if ground_ok(a) and ground_ok(c):draw_line(a,c,Color(.94,.87,.55,.10),1,true)
	# Roads follow grid axes, and stay outside the square foundations.
	for segment in [[Vector2(-8,-.5),Vector2(12,-.5)],[Vector2(-8,6.5),Vector2(12,6.5)],[Vector2(-1.5,-7),Vector2(-1.5,13)],[Vector2(5.5,-7),Vector2(5.5,13)]]:
		draw_line(project(segment[0]),project(segment[1]),Color(.46,.32,.13,.20),23,true)
		draw_line(project(segment[0]),project(segment[1]),Color(.79,.62,.32,.78),17,true)
	foundation(CHIEF,6)
	for i in model.built_count():
		var id:=int(model.homes()[i].get("site",i))
		foundation(PLOTS[id],4)
func foundation(cell:Vector2,span:int)->void:
	var p:=polygon(cell,span);draw_colored_polygon(p,Color(.70,.49,.23,.80))
	var inset:=polygon(cell,span-1);draw_colored_polygon(inset,Color(.85,.66,.36,.88))
	p.append(p[0]);draw_polyline(p,Color(.95,.79,.44,.60),3,true)
