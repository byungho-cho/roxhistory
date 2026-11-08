class_name ResidentJobs
extends RefCounted
## Persist only intent and paid-for cargo. Travel/work progress can safely restart.
var model: GameState
const MAX_RESIDENTS := 15
const JOBS := ["idle", "wood", "stone", "farmer", "guard"]
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
		if not id is String or not id in ResidentAdmission.ids(s):return false
		var item:Variant=s.resident_jobs[id]
		if not item is Dictionary or not item.get("job") in JOBS or not item.get("cargo") is Dictionary:return false
		var cargo:Dictionary=item.cargo
		if cargo.is_empty():continue
		if not cargo.get("kind") in ["wood","stone","grain"]:return false
		var amount:Variant=cargo.get("amount")
		if not (amount is int or amount is float) or not is_finite(float(amount)) or amount!=int(amount) or amount<1 or amount>10000:return false
	return true

func available(id:String)->bool:
	return not model.state.is_empty() and id in ResidentAdmission.ids(model.state)
func entry(id:String)->Dictionary:
	return model.state.get("resident_jobs",{}).get(id,{"job":"idle","cargo":{}}).duplicate(true)
func assign(id:String,job:String,building:String="")->bool:
	if model.busy or not available(id) or not job in JOBS:return false
	if job in ["farmer","guard"]:
		var found:=model.lookup_building(building)
		if found.is_empty() or found.kind!=("farm" if job=="farmer" else "outpost"):return false
		var occupant:=assigned_to(building)
		if not occupant.is_empty() and occupant!=id:return false
	var next:=model.state.duplicate(true)
	var item:=entry(id);item.job=job;item.building=building if job in ["farmer","guard"] else ""
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
	if item.job not in ["wood","stone"] or not item.cargo.is_empty():return false
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
	if model.busy or not available(id) or model.built_count()==0:return false
	var item:=entry(id)
	if item.cargo.is_empty():return false
	var kind:=str(item.cargo.kind);var amount:=int(item.cargo.amount)
	if int(model.state.get(kind,0))+amount>BuildingRules.MAX_RESOURCE:return false
	var next:=model.state.duplicate(true)
	next[kind]=int(next.get(kind,0))+amount;item.cargo={};next.resident_jobs[id]=item
	return _commit(next)

func assigned_to(building:String)->String:
	for id in ResidentAdmission.ids(model.state):
		var item:=entry(id)
		if item.job in ["farmer","guard"] and item.get("building","")==building:return id
	return ""

static func clear_building(next:Dictionary,key:String)->void:
	for item in next.get("resident_jobs",{}).values():
		if item.get("building","")==key:item.job="idle";item.building=""

static func remove_excess(next:Dictionary,count:int)->void:
	var roster:=ResidentAdmission.ids(next)
	var departed:Array=[]
	if not next.has("held_cargo"):next.held_cargo=[]
	for i in mini(count,roster.size()):
		var index:=randi_range(0,roster.size()-1);var id:String=roster[index]
		var item:Dictionary=next.get("resident_jobs",{}).get(id,{})
		if not item.get("cargo",{}).is_empty():
			var cargo:Dictionary=item.cargo.duplicate(true);cargo.reason="departed_resident";cargo.resident=id
			next.held_cargo.append(cargo)
		if next.has("resident_jobs"):next.resident_jobs.erase(id)
		departed.append(id);roster.remove_at(index)
	next.resident_roster=roster;next.resident_count=roster.size();next.last_departed=departed
