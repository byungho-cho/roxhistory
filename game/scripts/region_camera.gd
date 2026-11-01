class_name RegionCamera
extends RefCounted

var viewport:=Vector2(960,540)
var factor:=.6
var zoom:=1.0
var pan:=Vector2.ZERO

func configure(dimensions:Vector2) -> void:
	viewport=dimensions
	# Cover the display at the minimum scale: no fabricated ocean or empty rim.
	factor=maxf(viewport.x/1600.0,viewport.y/900.0)
	pan=overview_pan()

func overview_pan() -> Vector2:
	var result:Vector2=(viewport-RegionCatalog.BASE*factor)*.5
	# Wide cover displays crop the map vertically. Retain all three anchored
	# artifacts in the initial/reset view without shifting the markers themselves.
	var ui_scale:=minf(viewport.x/1600.0,viewport.y/900.0)
	var first_top:=138*factor-RegionMarkers.BASE_EXTENT*RegionMarkers.SELECTED_SCALE*ui_scale
	var last_bottom:=633*factor+39*ui_scale
	var low:=14*ui_scale-first_top
	var high:=viewport.y-8*ui_scale-last_bottom
	if low<=high:result.y=clampf(result.y,low,high)
	return bounded(result,1)

func bounded(value:Vector2,magnification:float) -> Vector2:
	var extent:=RegionCatalog.BASE*factor*magnification
	for axis in 2:value[axis]=clampf(value[axis],viewport[axis]-extent[axis],0)
	return value

func pose(magnification:float,position_value:Vector2) -> void:
	zoom=clampf(magnification,1,2);pan=bounded(position_value,zoom)

func project(point:Vector2) -> Vector2:return pan+point*factor*zoom
