extends SceneTree
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures.append(message);push_error(message)
func _initialize()->void:call_deferred("run")
func run()->void:
 var model:=GameState.new(SaveStore.new("user://storage_%d"%Time.get_ticks_usec()));model.start_new()
 var s:Dictionary=model.state.duplicate(true);s.chief_level=4;s.resident_count=3;s.wood=1000;s.stone=1000;s.grain=1000
 s.homes=[{"uid":"h1","style":1,"claimed":true,"level":1,"position":[900,900],"cost":{"wood":20,"stone":10}}];s.built=true;s.reward_claimed=true;s.facilities=[]
 check(model.commit(s),"Old-shaped save without storage fields loads")
 check(ResourceStorage.capacity(model,"wood")==100 and model.state.wood==1000,"Existing excess preserved at basic wood cap")
 check(ResourceStorage.capacity(model,"grain")==200,"Grain base plus L1 hut")
 s=model.state.duplicate(true);s.homes.append({"uid":"h2","style":1,"claimed":true,"level":3,"position":[1300,900],"cost":{"wood":20,"stone":10}});model.commit(s)
 check(ResourceStorage.capacity(model,"grain")==500,"Mixed L1 L3 grain capacity sums")
 check(model.building_requirement("stone_store").contains("농장"),"Store requires completed farm")
 s=model.state.duplicate(true);s.facilities=[{"uid":"f1","kind":"farm","level":1,"position":[1500,1100],"cost":{"wood":10,"stone":5}}];model.commit(s)
 check(model.building_requirement("stone_store").is_empty(),"Confirmed common timing enables new store construction")
 var snapshot:Dictionary=model.state.duplicate(true)
 model.set_debug_fast_build(false)
 var placement:=Vector2.INF
 for y in range(500,1900,250):
  for x in range(500,1900,250):
   if model.placement_requirement("stone_store",Vector2(x,y)).is_empty():placement=Vector2(x,y);break
  if placement.is_finite():break
 var now:=Time.get_unix_time_from_system()
 check(placement.is_finite() and model.begin_construction("stone_store",placement,now),"New store starts through existing construction workflow")
 var pending:Dictionary=model.construction_jobs()[0]
 check(is_equal_approx(float(pending.finishes_at)-float(pending.started_at),60),"Storage L1 uses common one minute")
 check(model.finish_constructions(now+61),"Storage construction finishes normally")
 var key:="stone_store:"+str(pending.uid)
 check(OwnedBuildingUpgrades.start(model,key,now+62),"Storage upgrade starts through existing workflow")
 var upgrade:Dictionary=model.lookup_building(key).data.upgrade
 check(is_equal_approx(float(upgrade.finishes_at)-float(upgrade.started_at),600),"Storage L2 uses common ten minutes")
 model.commit(snapshot)
 check(BuildingRules.cost("stone_store",1)=={"wood":20,"stone":20},"Stone store L1 cost")
 check(BuildingRules.cost("wood_store",4)=={"wood":100,"stone":100},"Wood store L4 cost")
 for level in range(1,5):
  s=model.state.duplicate(true);s.facilities=[{"uid":"f1","kind":"farm","level":1,"position":[1500,1100],"cost":{"wood":10,"stone":5}},{"uid":"ws","kind":"wood_store","level":level,"position":[1750,1200],"cost":{"wood":20,"stone":20}}];check(model.commit(s),"Store tier save accepted")
  check(ResourceStorage.capacity(model,"wood")==[300,500,1000,2000][level-1],"Store replaces basic cap")
  check(ResourceStorage.capacity(model,"stone")==100,"Other resource cap stays basic")
 check(not model.building_requirement("wood_store").is_empty(),"One storage building even in development unlimited mode")
 var jobs:=ResidentJobs.new(model)
 check(jobs.assign("resident-0","wood","wood_store:ws") and jobs.assign("resident-1","wood","wood_store:ws"),"Storage accepts multiple workers")
 check(jobs.assigned_ids("wood_store:ws").size()==2,"Shared assignment data exposes both workers")
 check(ResourceStorage.destination(model,"wood",Vector2.ZERO)==Vector2(1750,1200),"Wood delivered to sawmill")
 check(ResourceStorage.destination(model,"stone",Vector2.ZERO)==model.building_position("chief"),"Stone fallback depot is chief")
 check(ResourceStorage.destination(model,"grain",Vector2(910,910))==Vector2(900,900),"Grain chooses nearest hut")
 var node:Dictionary={}
 for candidate in model.nodes():
  if candidate.kind=="stone":node=candidate;break
 check(not model.gather_available(node.id,"hero"),"Excess inventory stops new gather")
 var old_depleted:Dictionary=model.state.depleted.duplicate(true)
 check(not model.gather(node.id) and model.state.depleted==old_depleted,"Full gather consumes no node charge")
 s=model.state.duplicate(true);s.stone=97
 # This fixture measures gather credit after the one-time quest reward.
 FirstQuests.mark(s.quests_done,"hero_stone");FirstQuests.mark(s.quests_claimed,"hero_stone");model.commit(s)
 check(model.gather(node.id) and model.state.stone==100,"Hero receives available three units only")
 s=model.state.duplicate(true);s.wood=1997;s.resident_jobs["resident-0"].cargo={"kind":"wood","amount":10};s.resident_jobs["resident-1"].cargo={"kind":"wood","amount":10};model.commit(s)
 model.store.blocked=true
 check(not jobs.deposit("resident-0") and model.state.wood==1997 and jobs.entry("resident-0").cargo.amount==10,"Failed delivery save preserves inventory and full cargo")
 model.store.blocked=false
 check(jobs.deposit("resident-0") and model.state.wood==2000 and jobs.entry("resident-0").cargo.is_empty(),"First arrival stores three and clears full ten-unit load")
 check(jobs.deposit("resident-1") and model.state.wood==2000 and jobs.entry("resident-1").cargo.is_empty(),"Second arrival cannot reuse capacity")
 check(model.demolish("wood_store:ws"),"Storage demolition uses existing refund transaction")
 check(jobs.entry("resident-0").job=="wood" and jobs.entry("resident-1").job=="wood","Removing storage keeps gatherer roles for chief fallback")
 check(model.state.wood>=2000 and ResourceStorage.capacity(model,"wood")==100,"Store removal never truncates existing stock")
 check(ResourceStorage.destination(model,"wood",Vector2.ZERO)==model.building_position("chief"),"Removing depot reroutes wood to chief")
 s=model.state.duplicate(true);var job:=BuildingRules.new_job("hut",0,Time.get_unix_time_from_system(),false);job.uid="refund";job.position=[1700,1500];job.style=1;s.construction_jobs=[job];s.wood=100;s.stone=100;model.commit(s)
 check(model.cancel_construction("refund") and model.state.wood==120 and model.state.stone==110,"Cancellation refunds exceed cap without discard")
 jobs.assign("resident-2","farmer","farm:f1")
 s=model.state.duplicate(true);s.grain=ResourceStorage.capacity(model,"grain");s.farm_cycles={"farm:f1":{"phase":"ready","elapsed":600.0,"cycle_level":1,"cuts":0,"stock":0}};model.commit(s)
 var before_cycle:=FarmProduction.entry(model,"farm:f1")
 check(not FarmProduction.harvest(model,"resident-2","farm:f1") and FarmProduction.entry(model,"farm:f1")==before_cycle,"Full grain storage pauses new cuts without changing crop state")
 var reloaded:=GameState.new(model.store)
 check(reloaded.state.wood==120 and reloaded.state.stone==110,"Reload preserves over-cap refund")
 print(JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
