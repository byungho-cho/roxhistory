class_name OrganicRoadNetwork
extends Node2D
## A visual tree branches from existing streets, avoiding perimeter-like L detours.
## No collision, placement or saved-building data is changed.
var buildings:Array
var paths:Array[PackedVector2Array]=[]
func _init(entries:Array)->void:buildings=entries;name="OrganicRoadNetwork"
func _ready()->void:
 if buildings.size()<2:return
 var connected:=PackedVector2Array([Vector2(buildings[0].cell)])
 var remaining:Array[Vector2]=[]
 for i in range(1,buildings.size()):remaining.append(Vector2(buildings[i].cell))
 while not remaining.is_empty():
  var distance:=INF;var chosen:=0;var origin:=connected[0]
  for i in remaining.size():
   for at in connected:
    var d:=at.distance_squared_to(remaining[i])
    if d<distance:distance=d;chosen=i;origin=at
  var target:Vector2=remaining[chosen];remaining.remove_at(chosen)
  if distance<.01:continue
  var path:=NaturalRoad.organic_path(origin,target);paths.append(path)
  var road:=NaturalRoad.new(path);road.brush_paint=true;add_child(road)
  for point in path:connected.append(point)
 set_meta("connected_buildings",buildings.size())
