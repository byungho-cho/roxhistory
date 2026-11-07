class_name BuildingRules
extends RefCounted

const KINDS := ["chief", "hut", "outpost", "hearth", "training", "shrine"]
const FACILITY_KINDS := ["hearth", "training", "shrine"]
const REQUIRED_HQ := {"chief":0,"hut":1,"hearth":2,"training":2,"shrine":3,"outpost":3}
const DURATIONS := [60.0,600.0,1800.0,10800.0]
const COSTS := {
	"chief":[[20,20],[50,50],[100,100],[300,300]],
	"hut":[[20,10],[30,20],[50,30],[100,50]],
	"shrine":[[10,20],[20,30],[30,50],[50,100]],
	"hearth":[[10,10],[30,30],[50,50],[100,100]],
	"outpost":[[10,10],[30,30],[50,50],[100,100]],
	"training":[[10,10],[20,20],[30,30],[50,50]]
}
# Well below the exact JSON integer limit, but leaves ample room above test stock.
const MAX_RESOURCE := 9000000000000
const MAX_ENTRIES := 256

static func canonical(kind:String)->String:
	return "hut" if kind=="home" else kind

static func cost(kind:String,target:int)->Dictionary:
	kind=canonical(kind)
	if not COSTS.has(kind) or target<1 or target>4:return {}
	var amounts:Array=COSTS[kind][target-1]
	return {"wood":int(amounts[0]),"stone":int(amounts[1])}

static func duration(target:int)->float:
	return DURATIONS[target-1] if target>=1 and target<=4 else 0.0

static func valid_number(value:Variant,minimum:float=0.0,maximum:float=MAX_RESOURCE,integer:bool=false)->bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=minimum and value<=maximum and (not integer or value==int(value))

static func valid_position(value:Variant)->bool:
	if not value is Array or value.size()!=2:return false
	for coordinate in value:
		if not valid_number(coordinate,-MAX_RESOURCE,MAX_RESOURCE):return false
	return VillageBounds.valid_saved_position(DemoConfig.point(value))

static func valid_cost(value:Variant)->bool:
	if not value is Dictionary:return false
	return valid_number(value.get("wood"),0,MAX_RESOURCE,true) and valid_number(value.get("stone"),0,MAX_RESOURCE,true)

static func valid_clock(job:Variant)->bool:
	if not job is Dictionary:return false
	if not valid_number(job.get("started_at")) or not valid_number(job.get("finishes_at")):return false
	if job.has("clock_duration") and not valid_number(job.clock_duration,0.000001):return false
	return job.finishes_at>job.started_at and valid_cost(job.get("cost"))

static func new_job(kind:String,from_level:int,now:float,fast:bool=false)->Dictionary:
	var full_duration:=5.0 if fast else duration(from_level+1)
	return {"kind":canonical(kind),"from":from_level,"to":from_level+1,"started_at":now,
		"finishes_at":now+full_duration,"clock_duration":full_duration,"cost":cost(kind,from_level+1)}

static func rescale_clock(job:Dictionary,now:float,old_speed:float,new_speed:float)->void:
	# Only unelapsed work is rescaled. Completed work never becomes pending again,
	# and a backwards system-clock jump never grants progress.
	if float(job.finishes_at)<=now:return
	var anchor:=maxf(now,float(job.started_at))
	job.clock_duration=float(job.get("clock_duration",float(job.finishes_at)-float(job.started_at)))*old_speed/new_speed
	job.finishes_at=anchor+(float(job.finishes_at)-anchor)*old_speed/new_speed

static func progress(job:Dictionary,now:float=-1.0)->float:
	if job.is_empty():return 0.0
	if now<0:now=Time.get_unix_time_from_system()
	var full_duration:=float(job.get("clock_duration",float(job.finishes_at)-float(job.started_at)))
	return clampf(1.0-maxf(0.0,float(job.finishes_at)-now)/maxf(0.000001,full_duration),0.0,1.0)

static func set_clock_mode(job:Dictionary,now:float,fast:bool)->void:
	if float(job.finishes_at)<=now:return
	var remaining:=maxf(0.0,float(job.finishes_at)-maxf(now,float(job.started_at)))
	var old_duration:=float(job.get("clock_duration",float(job.finishes_at)-float(job.started_at)))
	var duration:float=5.0 if fast else BuildingRules.duration(int(job.get("to",1)))
	var next_remaining:=minf(5.0,remaining) if fast else duration*clampf(remaining/maxf(.001,old_duration),0,1)
	job.clock_duration=duration
	job.started_at=now-(duration-next_remaining)
	job.finishes_at=now+next_remaining
