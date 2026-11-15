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
var move_grid := false
var relocated_road_delay := 0.0
var road_layer: Node2D
var completed_plot_count := 0
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
	name="VillageLayout";z_index=-15;model.changed.connect(rebuild_art);rebuild_art()
func set_move_grid(value: bool) -> void:
	if move_grid == value: return
	move_grid=value;queue_redraw()
func _draw()->void:
	if not move_grid:return
	# Clipped fine grid: square world cells project to the same 2:1 diamonds.
	for u in range(-30,31):
		for v in range(-30,31):
			var a:=project(Vector2(u,v));var b:=project(Vector2(u+1,v));var c:=project(Vector2(u,v+1))
			if ground_ok(a) and ground_ok(b):draw_line(a,b,Color(.94,.87,.55,.10),1,true)
			if ground_ok(a) and ground_ok(c):draw_line(a,c,Color(.94,.87,.55,.10),1,true)

func rebuild_art()->void:
	var chief:=model.building_position("chief")
	var signature:=str([model.chief_level(),chief,model.homes(),model.outposts(),model.facilities(),BrushRoadNetwork.enabled()])
	if signature==layout_signature:return
	layout_signature=signature
	var had_roads := is_instance_valid(road_layer)
	var old_roads := road_segments(road_layer)
	for child in get_children():remove_child(child);child.queue_free()
	road_layer=null
	var positions:Array=[];var levels:Array=[];var own_ground:Array[bool]=[]
	for i in model.built_count():positions.append(model.home_position(i));levels.append(int(model.homes()[i].get("level",1)));own_ground.append(false)
	for i in model.outposts().size():positions.append(model.outpost_position(i));levels.append(int(model.outposts()[i].get("level",1)));own_ground.append(false)
	for entry in model.facilities():
		positions.append(model.building_position(str(entry.kind)+":"+str(entry.uid)));levels.append(int(entry.get("level",1)));own_ground.append(BuildingVisuals.has_own_ground(str(entry.kind)))
	var added_plot := positions.size() > completed_plot_count
	completed_plot_count = positions.size()
	# Use actual saved building anchors, including free placement and moves.
	if model.chief_level()>0 and chief.is_finite():
		var roads := Node2D.new()
		road_layer=roads
		add_child(roads)
		var start:=unproject(chief-Vector2(0,24))
		var buildings:Array=[{"cell":start,"span":6}]
		for at in positions:buildings.append({"cell":unproject(at-Vector2(0,24)),"span":4})
		var use_tiles:=BrushRoadNetwork.enabled() and BrushRoadNetwork.assets_available()
		var grid_review:bool=OS.get_cmdline_user_args().has("--grid-roads")
		var planned:Dictionary=BrushRoadNetwork.plan(buildings) if use_tiles and grid_review else {"ok":false}
		if use_tiles and not grid_review:
			roads.add_child(OrganicRoadNetwork.new(buildings))
		elif bool(planned.ok):
			roads.add_child(BrushRoadNetwork.new(planned.masks))
		else:
			# Keep the complete legacy network if assets or safe routing are unavailable.
			# A nearest-connection tree avoids the previous parallel grid of spokes.
			var connected:Array[Vector2]=[start];var remaining:Array[Vector2]=[]
			for at in positions:remaining.append(unproject(at-Vector2(0,24)))
			while not remaining.is_empty():
				var best_from:=connected[0];var best_index:=0;var distance:=INF
				for from in connected:
					for i in remaining.size():
						var d:=from.distance_squared_to(remaining[i])
						if d<distance:best_from=from;best_index=i;distance=d
				var target:=remaining[best_index]
				if distance>.01:roads.add_child(NaturalRoad.new(NaturalRoad.organic_path(best_from,target)))
				connected.append(target);remaining.remove_at(best_index)
		if relocated_road_delay > 0.0 or (added_plot and had_roads):
			var new_roads := road_segments(roads)
			for key in new_roads:
				if old_roads.has(key): continue
				var segment: CanvasItem=new_roads[key]
				segment.modulate.a=0.0
				segment.create_tween().tween_property(segment,"modulate:a",1.0,.46).set_delay(relocated_road_delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		foundation(start,6,model.chief_level())
	for i in positions.size():
		if not own_ground[i]:foundation(unproject(positions[i]-Vector2(0,24)),4,levels[i])
	queue_redraw()
func road_segments(layer: Node2D) -> Dictionary:
	var result := {}
	if not is_instance_valid(layer): return result
	for child in layer.get_children():
		if child is NaturalRoad:
			result[str(child.cells)]=child
		elif child is OrganicRoadNetwork:
			for branch: NaturalRoad in child.get_children():
				result[str(branch.cells)]=branch
		elif child is BrushRoadNetwork:
			for tile: Sprite2D in child.get_children():
				result[[tile.position,tile.texture.resource_path]]=tile
	return result

static func foundation_rect(span: int) -> Rect2:
	var extent:=Vector2(float(span)*64.0,float(span)*64.0*676.0/1088.0*.81)
	return Rect2(Vector2(0,span*6-24)-extent*.5,extent)

static func draw_move_foundation(canvas: CanvasItem, at: Vector2, kind: String, level: int, opacity: float = 1.0) -> void:
	var bounds:=foundation_rect(6 if kind=="chief" else 4)
	bounds.position+=at
	var id:="GROUND-PAD-L%d"%clampi(level,1,4)
	var alpha: Array=AssetCatalog.entry(id).alpha_bounds
	var source:=Rect2(alpha[0],alpha[1],alpha[2],alpha[3])
	canvas.draw_texture_rect_region(AssetCatalog.texture(id),bounds,source,Color(1,1,1,opacity))

func foundation_at(at: Vector2) -> Sprite2D:
	var cell := unproject(at - Vector2(0,24))
	for child in get_children():
		if child.has_meta("foundation_cell") and cell.is_equal_approx(child.get_meta("foundation_cell")):
			return child as Sprite2D
	return null

func foundation(cell:Vector2,span:int,level:int=1)->void:
	var id:="GROUND-PAD-L%d"%clampi(level,1,4)
	var entry:=AssetCatalog.entry(id)
	var bounds:Array=entry.alpha_bounds
	var s:=Sprite2D.new();s.texture=AssetCatalog.texture(id)
	# Preserve the old visible ground extent and centre; source PNG padding stays intact.
	var visible_size:=foundation_rect(span).size
	s.scale=visible_size/Vector2(bounds[2],bounds[3])
	s.offset=s.texture.get_size()*.5-(Vector2(bounds[0],bounds[1])+Vector2(bounds[2],bounds[3])*.5)
	s.position=project(cell)+Vector2(0,span*6)
	s.set_meta("foundation_level",clampi(level,1,4));s.set_meta("foundation_cell",cell);s.set_meta("foundation_span",span)
	s.z_index=1;s.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(s)
func road(a:Vector2,b:Vector2)->void:
	if a!=b:add_child(NaturalRoad.new(NaturalRoad.curved_path(a,b)))
