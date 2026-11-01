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
	pan=(viewport-RegionCatalog.BASE*factor)*.5

func bounded(value:Vector2,magnification:float) -> Vector2:
	var extent:=RegionCatalog.BASE*factor*magnification
	for axis in 2:value[axis]=clampf(value[axis],viewport[axis]-extent[axis],0)
	return value

func pose(magnification:float,position_value:Vector2) -> void:
	zoom=clampf(magnification,1,2);pan=bounded(position_value,zoom)

func project(point:Vector2) -> Vector2:return pan+point*factor*zoom
