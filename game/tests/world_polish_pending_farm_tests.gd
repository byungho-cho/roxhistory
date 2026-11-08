extends SceneTree
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var model:=GameState.new(SaveStore.new("user://polish_claims_%d"%Time.get_ticks_usec()));model.start_new()
 var s:=model.state.duplicate(true);s.chief_level=4;s.wood=20;s.stone=20;s.resident_count=3;s.homes=[{"uid":"home","style":1,"claimed":true,"level":4,"position":[1300,900],"cost":{"wood":20,"stone":10}}];s.built=true;s.reward_claimed=true;model.commit(s)
 var jobs:=ResidentJobs.new(model);jobs.assign("resident-0","wood");jobs.assign("resident-1","wood");jobs.assign("resident-2","stone")
 var wood:Array=[];var stone:Dictionary={}
 for node in model.nodes():
  if node.kind=="wood":wood.append(node)
  elif stone.is_empty():stone=node
 check(model.claim_gather(wood[0].id,"resident-0"),"Worker reserves chosen tree before travel")
 check(not model.claim_gather(wood[0].id,"resident-1") and not model.claim_gather(wood[0].id,"hero"),"Neither another worker nor hero can choose reserved tree")
 var before:=model.state.duplicate(true)
 check(not jobs.harvest("resident-1",wood[0].id) and not model.gather(wood[0].id) and model.state==before,"Reserved node cannot be stolen or credited remotely")
 check(model.claim_gather(wood[1].id,"resident-1"),"Second worker takes another tree")
 model.store.blocked=true
 check(not jobs.assign("resident-0","idle") and model.owns_gather(wood[0].id,"resident-0"),"Failed job save preserves reservation")
 model.store.blocked=false
 check(jobs.assign("resident-0","idle") and model.gather_available(wood[0].id,"hero"),"Job reassignment immediately releases old target")
 check(model.claim_gather(wood[0].id,"hero") and model.claim_gather(wood[0].id,"hero-pending"),"Hero active and queued work may refer to same source")
 model.release_gather("hero")
 check(not model.gather_available(wood[0].id,"resident-0"),"Completing active action preserves queued ownership")
 check(model.claim_gather(stone.id,"hero-pending") and model.gather_available(wood[0].id,"resident-0"),"Replacing queued target releases previous queue target")
 check(not model.claim_gather(stone.id,"resident-2"),"Stone uses same exclusive reservation rule")
 model.release_gather("hero-pending")
 check(model.claim_gather(stone.id,"resident-2"),"Cancelled hero queue frees stone")
 check(jobs.harvest("resident-2",stone.id) and not model.owns_gather(stone.id,"resident-2"),"Successful harvest releases claim when cargo is created")
 jobs.deposit("resident-2")
 s=model.state.duplicate(true);s.depleted[wood[1].id]=int(wood[1].charges);model.commit(s)
 check(not model.gather_claims.has("resident-1"),"Exhaustion prunes stale claim")
 jobs.assign("resident-0","wood");model.claim_gather(wood[0].id,"resident-0")
 check(model.demolish("home") and model.gather_claims.is_empty(),"Population departure releases every worker claim")
 check(GameState.new(model.store).gather_claims.is_empty() and not model.state.has("gather_claims"),"Claims never pollute saves or survive session reload")
 check(not model.claim_gather("missing","hero"),"Invalid source cannot be reserved")
 check(is_equal_approx(ActorMovement.speed()*.5,90.75) and TrialResident.WORK_WALK_FACTOR==.5,"Work walking speed is half without changing hero base")
 check(ActorMovement.direction_to(Vector2.ZERO,Vector2(1,0),1,.5).x*ActorMovement.speed()*.5<=1.001,"Half-speed step limiting cannot overshoot target")
 for gesture in [{"at":3.75,"name":"yawn"},{"at":12.0,"name":"stretch"},{"at":21.25,"name":"doze"}]:check(HybridCharacter.idle_gesture(gesture.at,0).kind==gesture.name,"Idle gesture "+gesture.name)
 check(HybridCharacter.idle_gesture(3.75,0).kind!=HybridCharacter.idle_gesture(3.75,7).kind,"Residents have staggered idle schedules")
 var road:=NaturalRoad.new(NaturalRoad.curved_path(Vector2.ZERO,Vector2(8,6)));var edge:=road.edges()
 check(road.cells.size()>20,"Curved road is sampled for continuous soil geometry")
 for i in road.cells.size():check(edge.left[i].distance_to(edge.right[i])>=NaturalRoad.MIN_WIDTH,"Road opaque core at least one cell: %d"%i)
 road.free()
 print(JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
