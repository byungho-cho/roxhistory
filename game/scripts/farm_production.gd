class_name FarmProduction
extends RefCounted
## Active simulation time only. No offline catch-up or implicit transport policy.
const PREPARATION:=60.0
const GROWTH:=600.0
const YIELDS:=[5,10,24,40]
const CUTS:=[1,2,3,4]
static func fresh()->Dictionary:
	return {"phase":"prepare","elapsed":0.0,"cuts":0,"stock":0,"cycle_level":1}
static func valid(value:Variant)->bool:
	if not value is Dictionary:return false
	return value.get("phase") in ["prepare","grow","ready","harvest"] and BuildingRules.valid_number(value.get("elapsed"),0,GROWTH) and BuildingRules.valid_number(value.get("cuts"),0,4,true) and BuildingRules.valid_number(value.get("stock"),0,BuildingRules.MAX_RESOURCE,true) and BuildingRules.valid_number(value.get("cycle_level"),1,4,true)
static func entry(model:GameState,key:String)->Dictionary:
	var result:Dictionary=model.state.get("farm_cycles",{}).get(key,fresh()).duplicate(true)
	for field in ["cuts","stock","cycle_level"]:result[field]=int(result[field])
	result.elapsed=float(result.elapsed)
	return result
static func tick(model:GameState,seconds:float)->bool:
	if model.busy or model.state.is_empty() or not is_finite(seconds) or seconds<=0:return false
	var next:=model.state.duplicate(true);var changed:=false
	if not next.has("farm_cycles"):next.farm_cycles={}
	for farm in model.facilities():
		if farm.kind!="farm" or farm.has("upgrade"):continue
		var key:="farm:"+str(farm.uid)
		var cycle:=entry(model,key)
		# A farmer is needed for preparation; established crops grow unattended.
		if cycle.phase=="prepare" and ResidentJobs.new(model).assigned_to(key).is_empty():continue
		if cycle.phase not in ["prepare","grow"]:continue
		cycle.elapsed=minf(float(cycle.elapsed)+seconds,PREPARATION if cycle.phase=="prepare" else GROWTH)
		if cycle.phase=="prepare" and cycle.elapsed>=PREPARATION:
			cycle.phase="grow";cycle.elapsed=0.0;cycle.cycle_level=int(farm.get("level",1));cycle.cuts=0
		elif cycle.phase=="grow" and cycle.elapsed>=GROWTH:cycle.phase="ready"
		next.farm_cycles[key]=cycle;changed=true
	return _commit(model,next) if changed else false
static func harvest(model:GameState,id:String,key:String)->bool:
	var jobs:=ResidentJobs.new(model);var worker:=jobs.entry(id)
	var found:=model.lookup_building(key)
	if model.busy or not jobs.available(id) or worker.job!="farmer" or worker.get("building","")!=key or not worker.cargo.is_empty() or model.built_count()==0 or found.is_empty() or found.data.has("upgrade"):return false
	var cycle:=entry(model,key)
	if cycle.phase not in ["ready","harvest"] or ResourceStorage.room(model,"grain")<=0:return false
	var level:=clampi(int(cycle.cycle_level),1,4)-1
	var amount:int=YIELDS[level]/CUTS[level]
	# Each cut becomes exactly one load; the next cut waits for actual delivery
	# and the farmer's walk back to the field. No remote inventory credit.
	worker.cargo={"kind":"grain","amount":amount}
	cycle.cuts+=1;cycle.phase="harvest"
	if int(cycle.cuts)>=CUTS[level]:cycle.phase="prepare";cycle.elapsed=0.0;cycle.cuts=0
	var next:=model.state.duplicate(true)
	if not next.has("farm_cycles"):next.farm_cycles={}
	next.farm_cycles[key]=cycle;next.resident_jobs[id]=worker
	return _commit(model,next)

## Recovery for stock recorded by earlier local development saves. Normal
## production now creates one carried load atomically for every cut.
static func collect_stock(model:GameState,id:String,key:String,amount:int)->bool:
	var jobs:=ResidentJobs.new(model);var item:=jobs.entry(id)
	if model.busy or not jobs.available(id) or item.job!="farmer" or item.get("building","")!=key or not item.cargo.is_empty() or amount<=0 or amount>10000:return false
	var cycle:=entry(model,key)
	if int(cycle.stock)<amount or model.built_count()==0:return false
	cycle.stock-=amount;item.cargo={"kind":"grain","amount":amount}
	var next:=model.state.duplicate(true);next.farm_cycles[key]=cycle;next.resident_jobs[id]=item
	return _commit(model,next)

static func _commit(model:GameState,next:Dictionary)->bool:
	model.busy=true
	var ok:=model.commit(next)
	model.busy=false
	return ok
