class_name VillageNotifications
extends RefCounted
const EVENTS:=["construction","upgrade","arrival"]
static func setting(state:Dictionary,event:String)->Variant:
	return state.get("notification_preferences",{}).get(event,true)
static func set_enabled(model:GameState,event:String,enabled:bool)->bool:
	if model.busy or event not in EVENTS:return false
	var next:=model.state.duplicate(true)
	if not next.has("notification_preferences"):next.notification_preferences={}
	next.notification_preferences[event]=enabled
	model.busy=true
	var ok:=model.commit(next)
	model.busy=false
	return ok
static func dispatch(model:GameState,event:String,payload:Dictionary)->void:
	if setting(model.state,event)==true:model.notification_requested.emit(event,payload.duplicate(true))

static func key(state:Dictionary,event:String,id:String)->String:
	return "%s:%s:%s"%[state.get("notification_run","legacy"),event,id]

static func arrival_id(due:float)->String:
	return str(roundi(due*1000))

static func owned_id(collection:String,entry:Dictionary,index:int)->String:
	return "%s:%s:%s"%[collection,entry.get("uid",index),entry.upgrade.to]

static func message(event:String,kind:String)->Dictionary:
	if event=="arrival":return {"title":"새 주민이 찾아왔어요","body":"마을에 찾아온 주민을 만나 보세요."}
	var title:="건설 완료" if event=="construction" else "업그레이드 완료"
	return {"title":title,"body":"%s 공사가 완료됐어요."%BuildingWorkflow.building_name(kind)}

static func schedule(model:GameState)->Dictionary:
	var result:Dictionary={}
	if model.state.is_empty():return result
	if setting(model.state,"construction"):
		for job in model.construction_jobs():add_schedule(result,model.state,"construction",str(job.uid),job.kind,job.finishes_at)
	if setting(model.state,"upgrade"):
		if model.state.has("chief_upgrade"):
			var job:Dictionary=model.state.chief_upgrade
			add_schedule(result,model.state,"upgrade","chief:%s"%job.to,"chief",job.finishes_at)
		for collection in ["homes","outposts","facilities"]:
			var entries:Array=model.state.get(collection,[])
			for index in entries.size():
				var entry:Dictionary=entries[index]
				if entry.has("upgrade"):
					add_schedule(result,model.state,"upgrade",owned_id(collection,entry,index),entry.get("kind","hut"),entry.upgrade.finishes_at)
	var due:=float(model.state.get("family_next_at",0))
	if setting(model.state,"arrival") and due>0 and not model.family_available() and ResidentAdmission.count(model.state)<ResidentAdmission.MAX_RESIDENTS:
		add_schedule(result,model.state,"arrival",arrival_id(due),"",due)
	return result

static func add_schedule(result:Dictionary,state:Dictionary,event:String,id:String,kind:String,due:float)->void:
	var notice:=message(event,kind)
	notice.at=roundi(due*1000)
	result[key(state,event,id)]=notice
