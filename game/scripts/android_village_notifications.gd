class_name AndroidVillageNotifications
extends RefCounted

var model: GameState
var bridge: Object
var activity: Object
var last_schedule := ""
var notifications_enabled := true

func _init(game: GameState, enable_notifications:=true) -> void:
	notifications_enabled=enable_notifications
	model = game
	if not OS.has_feature("android") or not Engine.has_singleton("AndroidRuntime"): return
	var wrapper := Engine.get_singleton("JavaClassWrapper")
	if wrapper == null: return
	bridge = wrapper.wrap("com.roxhistory.notifications.VillageAlarm")
	if bridge == null: return
	activity = Engine.get_singleton("AndroidRuntime").getActivity()
	if activity == null:return
	if not notifications_enabled:return
	bridge.observeActivity(activity)
	model.changed.connect(sync)
	model.notification_requested.connect(completed)
	sync()

func request_permission() -> void:
	if notifications_enabled and bridge != null and activity != null:bridge.requestPermission(activity)

func diagnostic_sample() -> Dictionary:
	if bridge == null or activity == null:return {}
	var sample:Variant=JSON.parse_string(bridge.diagnosticSample(activity))
	return sample if sample is Dictionary else {}

func save_diagnostic_zip(path:String,filename:String)->bool:
	if not ProjectSettings.get_setting("roxhistory/native/diagnostic_zip",false) or bridge==null or activity==null:return false
	return bridge.saveDiagnosticZip(activity,path,filename)

func sync() -> void:
	if not notifications_enabled:return
	if bridge == null or activity == null:return
	var encoded := JSON.stringify(VillageNotifications.schedule(model))
	if encoded == last_schedule:return
	last_schedule = encoded
	bridge.synchronize(activity,encoded)

func completed(event: String,payload: Dictionary) -> void:
	if bridge == null or activity == null:return
	var notice := VillageNotifications.message(event,payload.get("kind",""))
	bridge.completed(activity,VillageNotifications.key(model.state,event,payload.id),notice.title,notice.body)
