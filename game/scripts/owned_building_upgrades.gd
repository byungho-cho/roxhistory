class_name OwnedBuildingUpgrades
extends RefCounted

static func lookup(model:GameState,key:String)->Dictionary:
	for i in model.built_count():
		if model.home_key(i)==key:
			return {"collection":"homes","index":i,"data":model.homes()[i],"position":model.home_position(i),"kind":"hut","key":key}
	var posts:=model.outposts()
	for i in posts.size():
		if "outpost:"+str(posts[i].uid)==key:
			return {"collection":"outposts","index":i,"data":posts[i],"position":model.outpost_position(i),"kind":"outpost","key":key}
	var facilities:=model.facilities()
	for i in facilities.size():
		var kind:=str(facilities[i].kind)
		if kind+":"+str(facilities[i].uid)==key:
			return {"collection":"facilities","index":i,"data":facilities[i],"position":model.entry_position(facilities[i]),"kind":kind,"key":key}
	return {}

static func keys(model:GameState)->Array[String]:
	var result:Array[String]=[]
	for i in model.built_count():result.append(model.home_key(i))
	for entry in model.outposts():result.append("outpost:"+str(entry.uid))
	for entry in model.facilities():result.append(str(entry.kind)+":"+str(entry.uid))
	return result

static func start(model:GameState,key:String,now:float=-1)->bool:
	if key=="chief":return model.upgrade_chief(now)
	var found:=lookup(model,key)
	if model.busy or found.is_empty() or not model.upgrade_requirement(key).is_empty():return false
	if now<0:now=Time.get_unix_time_from_system()
	if not is_finite(now):return false
	var next:=model.state.duplicate(true)
	if found.collection=="homes":next.homes=model.stable_homes()
	var level:=int(found.data.get("level",1))
	var job:=BuildingRules.new_job(found.kind,level,now,model.debug_fast_build)
	next.wood-=int(job.cost.wood);next.stone-=int(job.cost.stone)
	next[found.collection][found.index].upgrade=job
	model.busy=true
	var ok:=model.commit(next)
	model.busy=false
	return ok

static func finish(model:GameState,now:float=-1)->bool:
	if model.busy or model.state.is_empty():return false
	if now<0:now=Time.get_unix_time_from_system()
	if not is_finite(now):return false
	var next:=model.state.duplicate(true);var changed:=false
	for collection in ["homes","outposts","facilities"]:
		for entry in next.get(collection,[]):
			if entry.has("upgrade") and now>=float(entry.upgrade.finishes_at):
				entry.level=int(entry.upgrade.to);entry.erase("upgrade");changed=true
	if not changed:return false
	model.busy=true
	var ok:=model.commit(next)
	model.busy=false
	return ok

static func cancel(model:GameState,key:String)->bool:
	if key=="chief":return model.cancel_upgrade(key)
	var found:=lookup(model,key)
	if model.busy or found.is_empty() or not found.data.has("upgrade"):return false
	if Time.get_unix_time_from_system()>=float(found.data.upgrade.finishes_at):finish(model);return false
	var next:=model.state.duplicate(true)
	if found.collection=="homes":next.homes=model.stable_homes()
	var entry:Dictionary=next[found.collection][found.index]
	next.wood+=int(entry.upgrade.cost.wood);next.stone+=int(entry.upgrade.cost.stone)
	entry.erase("upgrade")
	model.busy=true
	var ok:=model.commit(next)
	model.busy=false
	return ok

static func valid(entry:Dictionary)->bool:
	var level:Variant=entry.get("level",1)
	if not BuildingRules.valid_number(level,1,4,true):return false
	if not entry.has("upgrade"):return true
	var job:Variant=entry.upgrade
	if not BuildingRules.valid_clock(job):return false
	if not BuildingRules.valid_number(job.get("from"),1,3,true) or not BuildingRules.valid_number(job.get("to"),2,4,true):return false
	# Historical saves retain their actual paid prices and completion times.
	return job.from==level and job.to==level+1
