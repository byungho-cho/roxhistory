class_name ResourcePlacement
extends RefCounted
## Seeded placement independent of the renderer, with reserved future build sites.
static func clear(at:Vector2,level:int,occupied:Array=[],reserved:Array=[])->bool:
	if not VillageBounds.rect_for_level(level).grow(-130).has_point(at):return false
	for home in reserved:
		if at.distance_to(home+Vector2(0,-40))<240:return false
	for point in occupied:
		if at.distance_to(point)<165:return false
	# Reserve the legacy river and its north bank, even on ground-only artwork.
	if at.x<470 and at.y<440:return false
	return true

static func generate(seed_value:int,level:int,count:int,occupied:Array=[],reserved:Array=[])->Array[Vector2]:
	var rng:=RandomNumberGenerator.new();rng.seed=seed_value
	var rect:=VillageBounds.rect_for_level(level).grow(-130)
	var taken:=occupied.duplicate();var result:Array[Vector2]=[]
	for attempt in 10000:
		if result.size()>=count:break
		var at:=Vector2(rng.randf_range(rect.position.x,rect.end.x),rng.randf_range(rect.position.y,rect.end.y))
		if not clear(at,level,taken,reserved):continue
		result.append(at);taken.append(at)
	return result
