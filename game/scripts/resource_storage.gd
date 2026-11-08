class_name ResourceStorage
extends RefCounted
const STORE_KINDS:={"wood":"wood_store","stone":"stone_store"}
const LIMITS:=[300,500,1000,2000]
static func building(model:GameState,kind:String)->Dictionary:
	for item in model.facilities():
		if item.kind==STORE_KINDS.get(kind,""):return item
	return {}
static func capacity(model:GameState,kind:String)->int:
	if kind=="grain":
		var total:=100
		for home in model.homes():total+=100*clampi(int(home.get("level",1)),1,4)
		return total
	var store:=building(model,kind)
	return LIMITS[clampi(int(store.get("level",1)),1,4)-1] if not store.is_empty() else 100
static func room(model:GameState,kind:String)->int:
	return maxi(0,capacity(model,kind)-int(model.state.get(kind,0)))
static func receive(model:GameState,next:Dictionary,kind:String,amount:int)->int:
	# Only new gathering/delivery uses this. Existing balances and refunds are never clamped.
	var accepted:=mini(maxi(0,capacity(model,kind)-int(next.get(kind,0))),maxi(0,amount))
	next[kind]=int(next.get(kind,0))+accepted
	return accepted
static func destination(model:GameState,kind:String,from:Vector2)->Vector2:
	if kind=="grain":return model.nearest_home(from)
	var store:=building(model,kind)
	if not store.is_empty():return model.entry_position(store)
	return model.building_position("chief") if model.chief_level()>0 else Vector2.INF
static func destination_exists(model:GameState,kind:String,point:Vector2)->bool:
	if kind!="grain":return destination(model,kind,point)==point
	for home in model.homes():
		if model.entry_position(home)==point:return true
	return false

static func gather_reason(model:GameState,id:String)->String:
	for node in model.nodes():
		if node.id==id and room(model,node.kind)<=0:return "%s 저장 공간이 가득 찼어요"%("목재" if node.kind=="wood" else "석재")
	return "다른 채집자가 선택한 대상이에요"
