class_name ResidentJobs
extends RefCounted
## Persist only intent and paid-for cargo. Travel/work progress can safely restart.
var model: GameState
const MAX_RESIDENTS := 15
const JOBS := ["idle", "wood", "stone"]
func _init(game:GameState)->void:model=game

static func valid_id(id:String,count:int=MAX_RESIDENTS)->bool:
	if not id.begins_with("resident-"):return false
	var suffix:=id.trim_prefix("resident-")
	if not suffix.is_valid_int():return false
	var index:=int(suffix)
	return suffix==str(index) and index>=0 and index<mini(count,MAX_RESIDENTS)

static func valid_saved_jobs(s:Dictionary)->bool:
	if not s.has("resident_jobs"):return true
	if not s.resident_jobs is Dictionary:return false
	for id in s.resident_jobs:
		if not id is String or not valid_id(id,ResidentAdmission.count(s)):return false
		var item:Variant=s.resident_jobs[id]
		if not item is Dictionary or not item.get("job") in JOBS or not item.get("cargo") is Dictionary:return false
		var cargo:Dictionary=item.cargo
		if cargo.is_empty():continue
		if not cargo.get("kind") in ["wood","stone"]:return false
		var amount:Variant=cargo.get("amount")
		if not (amount is int or amount is float) or not is_finite(float(amount)) or amount!=int(amount) or amount<1 or amount>10000:return false
	return true

func available(id:String)->bool:
	return not model.state.is_empty() and valid_id(id,model.resident_count())
func entry(id:String)->Dictionary:
	return model.state.get("resident_jobs",{}).get(id,{"job":"idle","cargo":{}}).duplicate(true)
func assign(id:String,job:String)->bool:
	if model.busy or not available(id) or not job in JOBS:return false
	var next:=model.state.duplicate(true)
	var item:=entry(id);item.job=job
	if not next.has("resident_jobs"):next.resident_jobs={}
	next.resident_jobs[id]=item
	return _commit(next)
func _commit(next:Dictionary)->bool:
	model.busy=true
	var ok:=model.commit(next)
	model.busy=false
	return ok
func harvest(id:String,node_id:String,now:float=-1.0)->bool:
	if model.busy or not available(id) or model.chief_level()<=0:return false
	var item:=entry(id)
	if item.job=="idle" or not item.cargo.is_empty():return false
	if now<0:now=Time.get_unix_time_from_system()
	if not is_finite(now):return false
	for node in model.nodes():
		if node.id!=node_id or node.kind!=item.job:continue
		var count:=int(model.state.depleted.get(node_id,0))
		if count>=int(node.charges):return false
		var amount:=int(DemoConfig.get_data().gather_yield)
		if amount<=0 or amount>10000:return false
		var next:=model.state.duplicate(true)
		next.depleted[node_id]=count+1
		if count+1>=int(node.charges):
			if not next.has("respawn_due"):next.respawn_due={}
			next.respawn_due[node_id]=now+randf_range(GameState.RESPAWN_MIN_SECONDS,GameState.RESPAWN_MAX_SECONDS)
		item.cargo={"kind":node.kind,"amount":amount}
		if not next.has("resident_jobs"):next.resident_jobs={}
		next.resident_jobs[id]=item
		return _commit(next)
	return false

# Called only after actor arrival. Full storage retains cargo without truncation.
func deposit(id:String)->bool:
	if model.busy or not available(id) or model.chief_level()<=0:return false
	var item:=entry(id)
	if item.cargo.is_empty():return false
	var kind:=str(item.cargo.kind);var amount:=int(item.cargo.amount)
	if int(model.state[kind])+amount>BuildingRules.MAX_RESOURCE:return false
	var next:=model.state.duplicate(true)
	next[kind]+=amount;item.cargo={};next.resident_jobs[id]=item
	return _commit(next)
