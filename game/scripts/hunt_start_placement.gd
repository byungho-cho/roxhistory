extends RefCounted
## Production formation geometry only. No encounter, clock, target or damage ownership.
const FRIEND_SPACING:=64.0
const MOTION_CLEARANCE:=50.0
const CONTACT_GAP:=60.0

static func plan(cells:Array,slots:Array,formation_center:Vector2,battle_center:Vector2,prey:Vector2)->Array[Vector2]:
	var forward:=battle_center.direction_to(prey)
	var lateral:=Vector2(-forward.y,forward.x)
	var front:=0
	for i in cells.size():
		if (cells[i]-formation_center).dot(forward)>(cells[front]-formation_center).dot(forward):front=i
	var front_offset:Vector2=cells[front]-formation_center
	# This production seat already calibrates the native spear/club sweeps.
	# Preserve its original endpoint instead of importing a lab contact distance.
	var front_point:=battle_center+front_offset*.62
	var anchor:=front_point-forward*front_offset.dot(forward)*.32-lateral*front_offset.dot(lateral)*.90
	var front_depth:float=(front_point-prey).dot(forward)
	var occupied:=slots.duplicate();occupied.sort()
	var points:Dictionary={}
	for slot in occupied:
		var offset:Vector2=cells[slot]-formation_center
		points[slot]=anchor+forward*offset.dot(forward)*.32+lateral*offset.dot(lateral)*.90
	# Resolve only occupied cells, in cell order: swapping residents cannot change
	# the formation or silently replace the chosen seats with a fixed squad.
	for iteration in 24:
		for i in occupied.size():
			for j in range(i+1,occupied.size()):
				var a:int=occupied[i];var b:int=occupied[j]
				var delta:Vector2=points[b]-points[a]
				if delta.length()<FRIEND_SPACING:
					var push:=delta.normalized()*(FRIEND_SPACING-delta.length())*.5
					if b==front:points[a]-=push*2.0
					elif a==front:points[b]+=push*2.0
					else:points[a]-=push;points[b]+=push
		for slot in occupied:
			var depth:float=(points[slot]-prey).dot(forward)
			if depth>front_depth:points[slot]-=forward*(depth-front_depth)
			var away:Vector2=points[slot]-prey
			if away.length()<MOTION_CLEARANCE:points[slot]=prey+away.normalized()*MOTION_CLEARANCE
	var result:Array[Vector2]=[]
	for slot in slots:result.append(points[slot])
	return result

static func ordinary_lunge(origin:Vector2,prey:Vector2,requested:float)->float:
	return minf(requested,maxf(0.0,origin.distance_to(prey)-CONTACT_GAP))

static func clear_motion(origin:Vector2,desired:Vector2,obstacles:Array,exclude:int=-1)->Vector2:
	# A short strike must not cross an intervening actor's centre and flip to
	# the opposite side of its clearance circle on the next frame.
	var travel:=desired-origin
	for i in obstacles.size():
		if i!=exclude:travel=travel.limit_length(maxf(0.0,origin.distance_to(obstacles[i])-.01))
	var point:=origin+travel
	for iteration in 48:
		for i in obstacles.size():
			if i==exclude:continue
			var delta:Vector2=point-obstacles[i]
			if delta.length()<MOTION_CLEARANCE:
				var direction:Vector2=delta.normalized() if delta.length_squared()>.001 else (origin-obstacles[i]).normalized()
				point=obstacles[i]+direction*MOTION_CLEARANCE
	return point
