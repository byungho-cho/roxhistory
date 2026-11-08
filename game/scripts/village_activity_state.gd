class_name VillageActivityState
extends RefCounted
static func valid(s:Dictionary)->bool:
	for key in ["grain","copper"]:
		if s.has(key) and not BuildingRules.valid_number(s[key],0,BuildingRules.MAX_RESOURCE,true):return false
	var buildings:Dictionary={}
	for entry in s.get("facilities",[]):buildings[str(entry.kind)+":"+str(entry.uid)]=str(entry.kind)
	for entry in s.get("outposts",[]):buildings["outpost:"+str(entry.uid)]="outpost"
	var occupied:Array=[]
	for item in s.get("resident_jobs",{}).values():
		if item.job not in ["farmer","guard"]:continue
		var key:Variant=item.get("building")
		if not key is String or buildings.get(key,"")!=("farm" if item.job=="farmer" else "outpost") or key in occupied:return false
		occupied.append(key)
	if not s.get("farm_cycles",{}) is Dictionary:return false
	for key in s.get("farm_cycles",{}):
		if buildings.get(key,"")!="farm" or not FarmProduction.valid(s.farm_cycles[key]):return false
	if not s.get("notification_preferences",{}) is Dictionary:return false
	for key in s.get("notification_preferences",{}):
		if key not in VillageNotifications.EVENTS or not s.notification_preferences[key] is bool:return false
	if not s.get("held_cargo",[]) is Array:return false
	for cargo in s.get("held_cargo",[]):
		if not cargo is Dictionary or cargo.get("kind") not in ["wood","stone","grain"] or not BuildingRules.valid_number(cargo.get("amount"),1,BuildingRules.MAX_RESOURCE,true):return false
	return true
