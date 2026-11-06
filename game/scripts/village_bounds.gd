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
