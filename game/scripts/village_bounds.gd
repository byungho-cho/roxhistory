class_name VillageBounds
extends RefCounted
## Single world-coordinate contract. Expansion awaits approved terrain/reference view.
const WORLD_SIZE:=Vector2(2400,1350)
# Freeze current framing independently of a future expanded world envelope.
const OVERVIEW_REFERENCE_SIZE:=Vector2(2400,1350)
const PLAYER_SAVE_MARGIN:=20.0
const RESOURCE_RELOCATION_RECT:=Rect2(100,100,2200,1150)
const NAV_CELL:=24
const PLAYABLE:=[Vector2(440,180),Vector2(1790,180),Vector2(2250,370),Vector2(2250,1080),Vector2(1840,1210),Vector2(440,1210),Vector2(160,1000),Vector2(160,400)]

static func navigation_cells()->Vector2i:
	# Keep the current 100x56 grid exactly until the expanded envelope is approved.
	return Vector2i(floori(WORLD_SIZE.x/NAV_CELL),floori(WORLD_SIZE.y/NAV_CELL))

static func valid_saved_position(point:Vector2)->bool:
	return point.x>=PLAYER_SAVE_MARGIN and point.y>=PLAYER_SAVE_MARGIN and point.x<=WORLD_SIZE.x-PLAYER_SAVE_MARGIN and point.y<=WORLD_SIZE.y-PLAYER_SAVE_MARGIN

static func inset_reference_polygon(reference_world_polygon:PackedVector2Array,center:Vector2)->PackedVector2Array:
	# Planning helper only: input is a frozen approved minimum-zoom WORLD polygon.
	# No current zoom, camera or device dimensions enter the runtime movement boundary.
	var result:=PackedVector2Array()
	for point in reference_world_polygon:result.append(center+(point-center)*.9)
	return result
