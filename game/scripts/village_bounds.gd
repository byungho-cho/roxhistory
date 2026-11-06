class_name VillageBounds
extends RefCounted
## Fixed 90% of the 16:9 minimum-zoom overview, independent of live zoom/device.
const WORLD_RECT:=Rect2(-728,-410,3856,2170)
const WORLD_SIZE:=Vector2(3856,2170)
# Freeze current framing independently of a future expanded world envelope.
const OVERVIEW_REFERENCE_SIZE:=Vector2(2400,1350)
const PLAYER_SAVE_MARGIN:=20.0
const RESOURCE_RELOCATION_RECT:=Rect2(-628,-310,3656,1970)
const NAV_CELL:=24
const PLAYABLE:=[Vector2(-728,-410),Vector2(3128,-410),Vector2(3128,1760),Vector2(-728,1760)]

static func navigation_cells()->Vector2i:
	# Cover negative coordinates through a fixed grid origin.
	return Vector2i(ceili(WORLD_SIZE.x/NAV_CELL),ceili(WORLD_SIZE.y/NAV_CELL))

static func valid_saved_position(point:Vector2)->bool:
	return point.is_finite() and WORLD_RECT.grow(-PLAYER_SAVE_MARGIN).has_point(point)

static func inset_reference_polygon(reference_world_polygon:PackedVector2Array,center:Vector2)->PackedVector2Array:
	# Planning helper only: input is a frozen approved minimum-zoom WORLD polygon.
	# No current zoom, camera or device dimensions enter the runtime movement boundary.
	var result:=PackedVector2Array()
	for point in reference_world_polygon:result.append(center+(point-center)*.9)
	return result

# HQ percentages apply linearly to the frozen overview width and height.
# The legacy rectangle already represents 90%; HQ4 preserves that maximum.
static func rect_for_level(level:int)->Rect2:
	var proportion:float=[.6,.7,.8,.9][clampi(level,1,4)-1]
	var size:=WORLD_SIZE*(proportion/.9)
	return Rect2(WORLD_RECT.get_center()-size*.5,size)

static func polygon_for_level(level:int)->PackedVector2Array:
	var rect:=rect_for_level(level)
	return PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
