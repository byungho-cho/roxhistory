extends RefCounted
## Visual clocks only. Combat rules, root skill travel and global speed are not owned here.
static var enabled := true
const RUN_PERIOD := .4 # Measured approved Uram lab run; actual legacy hunt has no run clip.
const ALLY_RATES := {
	"hangyeol":{"idle":1.5,"walk":1.5,"hit_reaction":1.2,"jump_spear_auto_r03":2.0,"spear_guard":1.5,"parry_counter":1.5},
	"saebom":{"idle":1.5,"walk":1.5,"hit_reaction":2.0,"sling_heavy":3.0,"sling_cast":3.0,"parry_counter":1.5},
}
const CURVES := {
	"hangyeol":{
		"run":[Vector2(0,0),Vector2(.22,.26),Vector2(.50,.50),Vector2(.72,.76),Vector2(1,1)],
		"basic_attack":[Vector2(0,0),Vector2(.24,.17),Vector2(.50,.50),Vector2(.66,.77),Vector2(1,1)],
		"stone_spear_thrust":[Vector2(0,0),Vector2(.28,.20),Vector2(.50,.50),Vector2(.65,.77),Vector2(1,1)],
		"spear_guard":[Vector2(0,0),Vector2(.20,.20),Vector2(.45,.37),Vector2(.70,.77),Vector2(1,1)],
		"parry_counter":[Vector2(0,0),Vector2(.25,.18),Vector2(.50,.50),Vector2(.70,.80),Vector2(1,1)],
		"hit_reaction":[Vector2(0,0),Vector2(.20,.20),Vector2(.48,.38),Vector2(.72,.79),Vector2(1,1)],
	},
	"saebom":{
		"run":[Vector2(0,0),Vector2(.24,.28),Vector2(.50,.50),Vector2(.74,.78),Vector2(1,1)],
		"basic_attack":[Vector2(0,0),Vector2(.27,.20),Vector2(.50,.50),Vector2(.70,.80),Vector2(1,1)],
		"sling_cast":[Vector2(0,0),Vector2(.30,.24),Vector2(.50,.50),Vector2(.72,.82),Vector2(1,1)],
		# Keep the designed release at 3.566667/4.5 and total at 4.5s.
		"sling_heavy":[Vector2(0,0),Vector2(.26,.19),Vector2(.56,.60),Vector2(3.566667/4.5,3.566667/4.5),Vector2(.91,.95),Vector2(1,1)],
		"hit_reaction":[Vector2(0,0),Vector2(.20,.20),Vector2(.50,.40),Vector2(.76,.82),Vector2(1,1)],
		"parry_counter":[Vector2(0,0),Vector2(.24,.18),Vector2(.50,.50),Vector2(.72,.81),Vector2(1,1)],
	},
}
const LEGACY := [Vector2(0,0),Vector2(.26,.18),Vector2(.50,.50),Vector2(.72,.82),Vector2(1,1)]

static func duration(character:String,clip:String,native:float) -> float:
	return native/rate(character,clip)

static func rate(character:String,clip:String)->float:
	return float(ALLY_RATES.get(character,{}).get(clip,1.0)) if enabled else 1.0

# Keep authored gameplay events and action locks on their existing clocks.
# An accelerated visual starts later, reaches the same event, then recovers faster.
static func event_sample(character:String,clip:String,seconds:float,event_seconds:float,native:float)->float:
	var multiplier:=rate(character,clip)
	return clampf((seconds-event_seconds*(1.0-1.0/multiplier))*multiplier,0.0,native)

static func phase(points:Array,t:float,cyclic:=false) -> float:
	t=clampf(t,0,1)
	for i in points.size()-1:
		var a:Vector2=points[i]
		var b:Vector2=points[i+1]
		if t>b.x:continue
		var slope:float=(b.y-a.y)/(b.x-a.x)
		var left:=slope
		var right:=slope
		if i>0:
			var p:Vector2=points[i-1]
			var previous:float=(a.y-p.y)/(a.x-p.x)
			left=2.0*previous*slope/(previous+slope)
		if i+2<points.size():
			var n:Vector2=points[i+2]
			var following:float=(n.y-b.y)/(n.x-b.x)
			right=2.0*slope*following/(slope+following)
		if cyclic and i==0:left=1.0
		if cyclic and i+2==points.size():right=1.0
		var u:float=(t-a.x)/(b.x-a.x)
		var h:float=b.x-a.x
		return clampf((2*u*u*u-3*u*u+1)*a.y+(u*u*u-2*u*u+u)*h*left+(-2*u*u*u+3*u*u)*b.y+(u*u*u-u*u)*h*right,a.y,b.y)
	return 1.0

static func sample(character:String,clip:String,seconds:float,native:float) -> float:
	var length:=duration(character,clip,native)
	var t:=clampf(seconds/length,0,1)
	if enabled and clip!="run" and CURVES.get(character,{}).has(clip):t=phase(CURVES[character][clip],t)
	return t*native

static func combat_phase(t:float) -> float:
	return phase(LEGACY,t) if enabled else clampf(t,0,1)
