class_name FirstQuests
extends RefCounted
## Stable IDs are persisted separately from reward receipts and introduction hints.
const IDS := ["hero_wood","hero_stone","chief_built","first_home","first_resident","chief_upgrade","first_farm","first_farmer"]
const TITLES := ["나무 채집","석재 채집","촌장집 건설","첫 움집 짓기","주민 받아들이기","촌장집 업그레이드","첫 농장 짓기","농부 배정"]
const OBJECTIVES := [
	"주인공으로 나무를 한 번 직접 채집하세요.",
	"주인공으로 돌을 한 번 직접 채집하세요.",
	"촌장집을 지을 위치를 고르고 건설을 완료하세요.",
	"주민이 머물 움집 한 채를 지으세요.",
	"찾아온 주민을 마을로 맞이하세요.",
	"촌장집을 2단계로 업그레이드하세요.",
	"마을에 농장 한 채를 지으세요.",
	"주민 한 명을 농장에 농부로 배정하세요."
]
const INTRO_KINDS := ["wood","stone","grain"]
const INTRO_AMOUNT := 100
const INTRO_GUIDES := ["목재를 채집하세요","석재를 채집하세요","촌장집을 지어주세요"]
const INTRO_SUCCESSES := ["목재 채집 성공!","석재 채집 성공!","촌장집 건설 완료!"]
const INTRO_RESOURCES := ["목재","석재","곡식"]
const MANUAL_AMOUNT := 50

static func reconcile(next:Dictionary, legacy:bool)->void:
	var done:Array=next.get("quests_done",[])
	var claimed:Array=next.get("quests_claimed",[])
	var chief_level:=int(next.get("chief_level",0 if next.get("hq_can_be_absent",false) else 1))
	if legacy:
		# A legacy chief proves the village had already reached construction.
		# Earlier saves did not distinguish hero gathering from other resource credit.
		if chief_level>0:
			mark(done,"hero_wood")
			mark(done,"hero_stone")
		else:
			for node in DemoConfig.get_data().nodes:
				if int(next.depleted.get(node.id,0))>0:
					mark(done,"hero_wood" if node.kind=="wood" else "hero_stone")
	if chief_level>0:mark(done,"chief_built")
	if next.get("built",false) or not next.get("homes",[]).is_empty():mark(done,"first_home")
	if next.get("family_joined",false) or ResidentAdmission.count(next)>0:mark(done,"first_resident")
	if chief_level>=2:mark(done,"chief_upgrade")
	for farm in next.get("facilities",[]):
		if farm.kind=="farm":mark(done,"first_farm");break
	for job in next.get("resident_jobs",{}).values():
		if job.job=="farmer" and not str(job.get("building","")).is_empty():mark(done,"first_farmer");break
	next.quests_done=done
	next.quests_claimed=claimed
	if legacy:
		for i in INTRO_KINDS.size():
			if IDS[i] in done and IDS[i] not in claimed:grant_intro(next,i)

static func grant_intro(next:Dictionary,index:int)->void:
	var kind:String=INTRO_KINDS[index]
	next[kind]=int(next.get(kind,next.get("tokens",0) if kind=="grain" else 0))+INTRO_AMOUNT
	next.quests_claimed.append(IDS[index])

static func mark(list:Array,id:String)->void:
	if id not in list:list.append(id)

static func current(state:Dictionary)->int:
	for i in IDS.size():
		if IDS[i] not in state.get("quests_done",[]):return i
		if i<INTRO_KINDS.size() and IDS[i] not in state.get("quests_claimed",[]):return i
	return -1

static func intro_reward_ready(state:Dictionary,index:int)->bool:
	return index>=0 and index<INTRO_KINDS.size() and index==current(state) and IDS[index] in state.get("quests_done",[])

static func pending(state:Dictionary)->Array[int]:
	var result:Array[int]=[]
	for i in range(INTRO_KINDS.size(),IDS.size()):
		if IDS[i] in state.get("quests_done",[]) and IDS[i] not in state.get("quests_claimed",[]):result.append(i)
	return result

static func valid(state:Dictionary)->bool:
	for field in ["quests_done","quests_claimed","quests_guides"]:
		var list:Variant=state.get(field,[])
		if not list is Array or list.size()>IDS.size():return false
		var seen:Array=[]
		for id in list:
			if id not in IDS or id in seen:return false
			seen.append(id)
	for id in state.get("quests_claimed",[]):
		if id not in state.get("quests_done",[]):return false
	return true
