class_name BrushRoadNetwork
extends Node2D
## A single shared graph means intersections never stack translucent road sprites.
## Coordinates are two VillageLayout cells, as specified by the v002 asset contract.
const DIRECTIONS := [Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1)]
const ASSET_PATH := "res://assets/roads/brush-v002/road-%02d.png"
const LIMIT := 20
var masks:Dictionary = {}

static func enabled()->bool:
	return bool(ProjectSettings.get_setting("roxhistory/visuals/brush_roads",true)) and not OS.get_cmdline_user_args().has("--legacy-roads")

static func tile_cell(at:Vector2i)->Vector2:
	return Vector2(at)*2.0

static func walkable(at:Vector2i, buildings:Array)->bool:
	if absi(at.x)>LIMIT or absi(at.y)>LIMIT:return false
	var center:=tile_cell(at)
	# Whole tile must remain on terrain; road surface clears occupied footprints.
	for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
		if not VillageLayout.ground_ok(VillageLayout.project(center+corner)):return false
	for building in buildings:
		var delta:Vector2=(center-Vector2(building.cell)).abs()
		var clearance:float=float(building.span)*.5+1.0
		if delta.x<clearance and delta.y<clearance:return false
	return true

static func portals(building:Dictionary,buildings:Array)->Array[Vector2i]:
	var result:Array[Vector2i]=[]
	var center:Vector2=building.cell
	var radius:float=float(building.span)*.5+2.5
	for x in range(floori((center.x-radius)/2),ceili((center.x+radius)/2)+1):
		for y in range(floori((center.y-radius)/2),ceili((center.y+radius)/2)+1):
			var at:=Vector2i(x,y)
			var delta:Vector2=(tile_cell(at)-center).abs()
			# Only side entrances, not remote diagonal corners.
			if minf(delta.x,delta.y)<=1.0 and maxf(delta.x,delta.y)<=radius and walkable(at,buildings):
				result.append(at)
	return result

static func connect_to_network(starts:Array[Vector2i],network:Dictionary,buildings:Array)->Array[Vector2i]:
	var queue:Array[Vector2i]=starts.duplicate()
	var previous:Dictionary={}
	for start in starts:previous[start]=start
	var head:=0
	while head<queue.size():
		var at:=queue[head];head+=1
		if network.has(at):
			var path:Array[Vector2i]=[at]
			while previous[at]!=at:
				at=previous[at];path.append(at)
			return path
		for direction in DIRECTIONS:
			var next:Vector2i=at+direction
			if not previous.has(next) and walkable(next,buildings):
				previous[next]=at;queue.append(next)
	return []

static func neighbor_masks(network:Dictionary)->Dictionary:
	var result:Dictionary={}
	for at in network:
		var mask:=0
		for i in DIRECTIONS.size():
			if network.has(at+DIRECTIONS[i]):mask|=1<<i
		result[at]=mask
	return result

static func plan(buildings:Array)->Dictionary:
	if buildings.size()<2:return {"ok":true,"masks":{}}
	var first:=portals(buildings[0],buildings)
	if first.is_empty():return {"ok":false,"masks":{}}
	var nearest:=first[0]
	for candidate in first:
		if tile_cell(candidate).distance_squared_to(buildings[1].cell)<tile_cell(nearest).distance_squared_to(buildings[1].cell):nearest=candidate
	var network:Dictionary={nearest:true}
	# Ordered buildings are stable across rebuilds; routing is deterministic.
	for i in range(1,buildings.size()):
		var path:=connect_to_network(portals(buildings[i],buildings),network,buildings)
		if path.is_empty():return {"ok":false,"masks":{}}
		for at in path:network[at]=true
	return {"ok":true,"masks":neighbor_masks(network)}

static func assets_available()->bool:
	for i in 16:
		if not ResourceLoader.exists(ASSET_PATH%i):return false
	return true

func _init(tile_masks:Dictionary)->void:
	name="BrushRoadNetwork"
	masks=tile_masks
	set_meta("grid_width",1.0)

func _ready()->void:
	for at in masks:
		var sprite:=Sprite2D.new()
		sprite.name="Road_%s_%s"%[at.x,at.y]
		sprite.texture=load(ASSET_PATH%int(masks[at]))
		sprite.position=VillageLayout.project(tile_cell(at))
		sprite.scale=Vector2(.25,.25)
		sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(sprite)
