extends SceneTree
const NativeBoar=preload("res://scripts/hunt_production_boar_actor.gd")
const Rules=preload("res://scripts/deer_hunt_rules.gd")
const Profile=preload("res://scripts/hunt_production_prey_profile.gd")
var failures:=0
var app
func _initialize():call_deferred("run")
func check(label:String, passed:bool):
 print(label, ": ",passed)
 if not passed:failures+=1
func prepare(stage:int, cleared:int):
 app.model.state.hunt_cleared=cleared
 app.hunt_stage=stage
 app.show_screen("hunt_select")
 await app.prepare_selected_hunt()
 await process_frame
func run():
 check("fresh resolver keeps stage5 deer",Profile.encounter_species(5,0,true)=="forest")
 check("feature rollback keeps stage5 deer",Profile.encounter_species(5,5,false)=="forest")
 app=load("res://scenes/main.tscn").instantiate()
 root.add_child(app)
 await process_frame
 check("fresh save starts in isolated fixture",app.model.start_new({},true))
 await prepare(5,0)
 check("locked stage5 cannot enter or switch prey",app.screen=="hunt_select" and app.hunt_prey_id=="forest")
 await prepare(4,5)
 check("stage4 still ordinary deer",app.screen=="hunt" and app.hunt_prey_id=="forest")
 var base_hp:int=app.hunt.rules.deer_max_hp
 app.close_hunt()
 await prepare(5,5)
 check("unlocked stage5 ordinary route selects adult",app.screen=="hunt" and app.hunt_prey_id=="adult")
 check("stage5 runtime owns adult rig",app.hunt.deer is NativeBoar and app.hunt.deer.is_native_ready())
 check("stage5 preserves encounter HP",app.hunt.rules.deer_max_hp==base_hp)
 var stage5:Control=app.hunt
 stage5.set_process(false)
 stage5.arrival_finished=true
 stage5.transition_elapsed=0.0
 stage5.advance_transition(stage5.TRANSITION_SECONDS)
 stage5.update_actors(.04)
 var actor:NativeBoar=stage5.deer
 var settled:Vector2=actor.position
 var w:Dictionary=stage5._deer_stone_capsule()
 check("adult stroke uses actual trunk/head body capsule",not w.is_empty() and w.a.distance_to(w.b)>.05)
 var before_hp:int=stage5.rules.party_hp[Rules.SAEBOM]
 stage5.rules.hunter_turn=false
 stage5.rules.next_target=Rules.SAEBOM
 stage5.rules.exchange_clock=Rules.AUTO_INTERVAL
 stage5._process(.04)
 stage5._process(.18)
 check("real scheduled charge samples native windup",stage5.pose=="counter" and actor.native_phase=="charge" and actor.native_elapsed>0.0)
 stage5._process(.17)
 check("charge hits existing 2 HP and advances native release",stage5.rules.party_hp[Rules.SAEBOM]==before_hp-2 and actor.native_elapsed>=stage5.adult_markers.charge_release and actor.position.distance_to(settled)>1.0 and not stage5.bom_prey_pocket.is_finite())
 for frame in range(15): stage5._process(1.0/60.0)
 var before_stone:int=stage5.rules.deer_hp
 stage5.rules.charges[Rules.SAEBOM]=3.0
 stage5._on_party_skill_requested("skill",Rules.SAEBOM)
 for frame in range(80):
  stage5._process(1.0/60.0)
  if stage5.stone_last_result in ["hit","miss"]:break
 check("Saebom real 2SP body contact still applies existing 58",stage5.stone_last_result=="hit" and stage5.rules.deer_hp==before_stone-58)
 var before_money:=[app.model.state.wood,app.model.state.stone,app.model.state.tokens,app.model.state.get("diamonds",0)]
 app.retry_hunt()
 await process_frame
 check("retry preserves selected stage and native adult",app.hunt_stage==5 and app.hunt_prey_id=="adult" and app.hunt.deer is NativeBoar and app.hunt.deer.is_native_ready())
 print("Pre-win save valid=",app.model.store.valid(app.model.state)," blocked=",app.model.store.blocked," dir=",app.model.store.directory)
 app.record_hunt_win()
 check("existing win increments only once, no resource mutation",app.model.state.hunt_cleared==6 and [app.model.state.wood,app.model.state.stone,app.model.state.tokens,app.model.state.get("diamonds",0)]==before_money)
 app.record_hunt_win()
 check("replayed stage cannot increment again",app.model.state.hunt_cleared==6)
 app.close_hunt()
 if app.modal:app.close_modal()
 await prepare(11,11)
 check("stage11 still ordinary deer",app.screen=="hunt" and app.hunt_prey_id=="forest")
 print("Stage5 route failures=",failures)
 quit(1 if failures else 0)
