class_name VillageNotifications
extends RefCounted
## No OS transport/default/repetition policy is chosen here.
const EVENTS:=["construction","upgrade","arrival"]
static func setting(state:Dictionary,event:String)->Variant:
	return state.get("notification_preferences",{}).get(event,null)
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
