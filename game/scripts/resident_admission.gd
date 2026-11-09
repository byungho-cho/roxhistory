class_name ResidentAdmission
extends RefCounted
## One persisted visiting party at a time. Capacity never creates residents.
const MAX_RESIDENTS := 15
# Test-build tuning, kept in one place until production pacing is approved.
const VISIT_INTERVAL_SECONDS := 60.0

static func count(state:Dictionary)->int:
	return clampi(int(state.get("resident_count",2 if state.get("family_joined",false) else 0)),0,MAX_RESIDENTS)

static func ids(state:Dictionary)->Array:
	if state.has("resident_roster"):return state.resident_roster.duplicate()
	var result:Array=[]
	for i in count(state):result.append("resident-%d"%i)
	return result

static func visitor_count(state:Dictionary)->int:
	return clampi(int(state.get("pending_family_count",0)),0,3)

static func available(model:GameState)->bool:
	return not model.state.is_empty() and visitor_count(model.state)>0

static func valid_saved_population(state:Dictionary)->bool:
	if state.has("resident_roster"):
		if not state.resident_roster is Array or state.resident_roster.size()!=count(state):return false
		var seen:Array=[]
		for id in state.resident_roster:
			if not id is String or not ResidentJobs.valid_id(id) or id in seen:return false
			seen.append(id)
	for key in ["resident_count","pending_family_count"]:
		if not state.has(key):continue
		var value:Variant=state[key]
		var limit:=MAX_RESIDENTS if key=="resident_count" else 3
		if not (value is int or value is float) or not is_finite(float(value)) or value!=int(value) or value<0 or value>limit:return false
	if state.has("family_next_at"):
		var value:Variant=state.family_next_at
		if not (value is int or value is float) or not is_finite(float(value)) or value<0:return false
	return true

static func prepare_visit(model:GameState,now:float=-1.0)->bool:
	if model.busy or model.state.is_empty() or available(model) or count(model.state)>=MAX_RESIDENTS:return false
	if now<0:now=Time.get_unix_time_from_system()
	if not is_finite(now) or now<0:return false
	var next:=model.state.duplicate(true)
	var first:bool="first_resident" not in model.state.get("quests_done",[]) and not model.state.get("family_joined",false)
	if first:
		if model.built_count()==0:return false
		next.pending_family_count=1
		next.family_next_at=0.0
		return _arrive(model,next)
	var due:=float(next.get("family_next_at",0.0))
	if due<=0:
		next.family_next_at=now+VISIT_INTERVAL_SECONDS
	elif now>=due:
		# Near the absolute population ceiling, do not strand an oversized party.
		next.pending_family_count=randi_range(1,mini(2,MAX_RESIDENTS-count(next)))
		next.family_next_at=0.0
		return _arrive(model,next)
	else:return false
	return _commit(model,next)

static func join(model:GameState,now:float=-1.0)->bool:
	if model.busy or not available(model):return false
	var party:=visitor_count(model.state)
	var admitted:=count(model.state)
	# The whole party is admitted or nobody is. Failed saves change neither party.
	if admitted+party>mini(MAX_RESIDENTS,model.resident_capacity()):return false
	if now<0:now=Time.get_unix_time_from_system()
	if not is_finite(now) or now<0:return false
	var next:=model.state.duplicate(true)
	next.resident_count=admitted+party
	var roster:=ids(model.state)
	for i in MAX_RESIDENTS:
		var id:="resident-%d"%i
		if not id in roster and roster.size()<admitted+party:roster.append(id)
	next.resident_roster=roster
	next.family_joined=true
	next.family_unlocked=true
	next.pending_family_count=0
	next.family_next_at=now+VISIT_INTERVAL_SECONDS
	return _commit(model,next)

static func _arrive(model:GameState,next:Dictionary)->bool:
	var id:=VillageNotifications.arrival_id(float(model.state.get("family_next_at",0)))
	var ok:=_commit(model,next)
	if ok:VillageNotifications.dispatch(model,"arrival",{"count":next.pending_family_count,"id":id})
	return ok

static func _commit(model:GameState,next:Dictionary)->bool:
	model.busy=true
	var ok:=model.commit(next)
	model.busy=false
	return ok
