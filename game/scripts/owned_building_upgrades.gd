class_name OwnedBuildingUpgrades
extends RefCounted

static func lookup(model:GameState,key:String)->Dictionary:
	for i in model.built_count():
		if model.home_key(i)==key:return {"collection":"homes","index":i,"data":model.homes()[i],"position":model.home_position(i)}
	for i in model.outposts().size():
		if "outpost:"+str(model.outposts()[i].uid)==key:return {"collection":"outposts","index":i,"data":model.outposts()[i],"position":model.outpost_position(i)}
	return {}

static func keys(model:GameState)->Array[String]:
	var result:Array[String]=[]
	for i in model.built_count():result.append(model.home_key(i))
	for entry in model.outposts():result.append("outpost:"+str(entry.uid))
	return result

static func start(model:GameState,key:String,now:float=-1)->bool:
	var found:=lookup(model,key)
	if model.busy or found.is_empty():return false
	var entry:Dictionary=found.data
	var level:=int(entry.get("level",1))
	if level>=4 or entry.has("upgrade") or model.state.wood<20 or model.state.stone<20:return false
	if now<0:now=Time.get_unix_time_from_system()
	if not is_finite(now):return false
	var next:=model.state.duplicate(true)
	if found.collection=="homes":next.homes=model.stable_homes()
	next.wood-=20;next.stone-=20
	next[found.collection][found.index].upgrade={"from":level,"to":level+1,"started_at":now,"finishes_at":now+model.chief_upgrade_duration(level+1),"cost":{"wood":20,"stone":20}}
	model.busy=true
	var ok:=model.commit(next)
	model.busy=false
	return ok

static func finish(model:GameState,now:float=-1)->bool:
	if model.busy or model.state.is_empty():return false
	if now<0:now=Time.get_unix_time_from_system()
	if not is_finite(now):return false
	var next:=model.state.duplicate(true);var changed:=false
	for collection in ["homes","outposts"]:
		for entry in next.get(collection,[]):
			if entry.has("upgrade") and now>=float(entry.upgrade.finishes_at):
				entry.level=int(entry.upgrade.to);entry.erase("upgrade");changed=true
	if not changed:return false
	model.busy=true
	var ok:=model.commit(next)
	model.busy=false
	return ok

static func valid(entry:Dictionary)->bool:
	var level:Variant=entry.get("level",1)
	if not (level is int or level is float) or not is_finite(float(level)) or level!=int(level) or level<1 or level>4:return false
	if not entry.has("upgrade"):return true
	var job:Variant=entry.upgrade
	if not job is Dictionary:return false
	for key in ["from","to","started_at","finishes_at"]:
		var value:Variant=job.get(key)
		if not (value is int or value is float) or not is_finite(float(value)):return false
	if job.from!=level or job.to!=level+1 or job.to>4 or job.started_at<0 or job.finishes_at<=job.started_at:return false
	if not job.get("cost") is Dictionary:return false
	return job.cost.get("wood")==20 and job.cost.get("stone")==20
