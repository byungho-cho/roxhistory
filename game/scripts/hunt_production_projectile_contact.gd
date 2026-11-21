extends RefCounted
## Scene-free authoritative single-stone flight. Caller samples real rig
## markers and is the only owner of HP, cooldowns, visuals and team logic.
## Each valid capsule has Vector3 "a"/"b" endpoints and float "radius".
## Supply snapshots bracketing delta. Empty current snapshot removes the target.
## Read position/active for art; step returns exactly one hit/expiry, or {}.
const STEP := 1.0 / 120.0
var active := false
var position := Vector3.ZERO
var _velocity := Vector3.ZERO
var _acceleration := Vector3.ZERO
var _age := 0.0
var _travel := 0.0
var _max_age := 0.0
var _max_range := 0.0
var _skin := 0.0
var _payload := {}

func launch(origin:Vector3, aim:Vector3, speed:float, max_range:float, payload:Dictionary={}, lifetime:=.50, gravity:=3.8, stone_radius:=.06)->bool:
	if active or not origin.is_finite() or not aim.is_finite():
		return false
	if not is_finite(speed) or not is_finite(max_range) or not is_finite(lifetime) or not is_finite(gravity) or not is_finite(stone_radius):
		return false
	if speed<=0 or max_range<=0 or lifetime<=0 or gravity<0 or stone_radius<0 or origin.is_equal_approx(aim):
		return false
	var heading:=aim-origin
	var planar:=Vector3(heading.x,0,heading.z)
	var flight_time:=clampf(planar.length()/speed,.075,.45)
	_velocity=planar.limit_length(speed*flight_time)/flight_time+Vector3.UP*(heading.y/flight_time+.5*gravity*flight_time)
	_acceleration=Vector3.DOWN*gravity
	position=origin
	_age=0.0
	_travel=0.0
	_max_age=lifetime
	_max_range=max_range
	_skin=stone_radius
	_payload=payload.duplicate(true)
	active=true
	return true

func cancel()->void:
	active=false
	_payload={}

func step(delta:float, previous:Dictionary={}, current:Dictionary={})->Dictionary:
	if not active or delta<=0 or not is_finite(delta):
		return {}
	var has_target:=_valid_capsule(current)
	if has_target and not _valid_capsule(previous):
		previous=current
	var elapsed:=0.0
	while elapsed<delta and _age<_max_age:
		var dt:=minf(STEP,minf(delta-elapsed,_max_age-_age))
		var old:=position
		var next:=old+_velocity*dt+_acceleration*.5*dt*dt
		var length:=old.distance_to(next)
		var stop_at:=1.0
		var reason:=""
		if length>0.0 and _travel+length>=_max_range:
			stop_at=clampf((_max_range-_travel)/length,0.0,1.0)
			reason="range"
		if old.y<0.0 or (next.y<=0.0 and next.y<old.y):
			var floor_at:=0.0 if old.y<0.0 else old.y/(old.y-next.y)
			if floor_at<=stop_at:
				stop_at=floor_at
				reason="ground"
		if has_target:
			var q0:=elapsed/delta
			var q1:=(elapsed+dt)/delta
			var a0:Vector3=previous.a.lerp(current.a,q0)
			var b0:Vector3=previous.b.lerp(current.b,q0)
			var a1:Vector3=previous.a.lerp(current.a,q1)
			var b1:Vector3=previous.b.lerp(current.b,q1)
			var shift:=(a1+b1-a0-b0)*.5
			var radius:=lerpf(float(previous.radius),float(current.radius),(q0+q1)*.5)
			# Relative motion is exact for a translating capsule. Rotation is
			# approximated by the midpoint axis each short substep.
			var mid_a:=(a0+a1+shift)*.5
			var mid_b:=(b0+b1+shift)*.5
			var contact:=capsule_hit(old+shift,next,mid_a,mid_b,radius+_skin)
			if contact<=stop_at:
				position=old.lerp(next,contact)
				_age+=dt*contact
				var a:=a0.lerp(a1,contact)
				var b:=b0.lerp(b1,contact)
				var axis:=b-a
				var nearest:=a+axis*clampf((position-a).dot(axis)/maxf(axis.length_squared(),.000001),0,1)
				var normal:=nearest.direction_to(position)
				if normal.is_zero_approx():
					normal=-_velocity.normalized()
				return _finish("hit",{"point":nearest+normal*radius,"normal":normal})
		position=old.lerp(next,stop_at)
		_age+=dt*stop_at
		_travel+=length*stop_at
		if not reason.is_empty():
			return _finish("expired",{"reason":reason})
		_velocity+=_acceleration*dt
		elapsed+=dt
	if _age>=_max_age:
		return _finish("expired",{"reason":"lifetime"})
	return {}

func _finish(kind:String,data:Dictionary)->Dictionary:
	data.merge({"kind":kind,"position":position,"age":_age,"payload":_payload})
	cancel()
	return data

static func _valid_capsule(value:Dictionary)->bool:
	var a=value.get("a")
	var b=value.get("b")
	var radius=value.get("radius")
	return a is Vector3 and b is Vector3 and a.is_finite() and b.is_finite() and (radius is float or radius is int) and is_finite(float(radius)) and radius>=0

static func capsule_hit(from:Vector3,to:Vector3,a:Vector3,b:Vector3,radius:float)->float:
	# Continuous segment vs capsule: finite cylinder plus its two end spheres.
	# This also catches fast tips that enter AND leave between rendered frames.
	var axis:=b-a;var offset:=from-a;var travel:=to-from
	var aa:=axis.length_squared()
	var closest:=a+axis*clampf(offset.dot(axis)/maxf(aa,.000001),0,1)
	if from.distance_squared_to(closest)<=radius*radius:return 0.0
	var best:=INF
	var v:=travel.length_squared()
	if v<.000000001:return best
	for center in [a,b]:
		var oc:Vector3=from-center;var q:=travel.dot(oc);var discriminant:=q*q-v*(oc.length_squared()-radius*radius)
		if discriminant>=0:
			var t:=(-q-sqrt(discriminant))/v
			if t>=0 and t<=1:best=minf(best,t)
	if aa>.000001:
		var ad:=axis.dot(travel);var ao:=axis.dot(offset)
		var qa:=aa*v-ad*ad;var qb:=aa*travel.dot(offset)-ao*ad
		var qc:=aa*offset.length_squared()-ao*ao-radius*radius*aa
		var discriminant:=qb*qb-qa*qc
		if absf(qa)>.00000001 and discriminant>=0:
			var t:=(-qb-sqrt(discriminant))/qa
			var axial:=ao+t*ad
			if t>=0 and t<=1 and axial>=0 and axial<=aa:best=minf(best,t)
	return best
