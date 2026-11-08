extends "res://tests/building_hold_v056_tests.gd"
func run()->void:
 root.size=Vector2i(1280,800)
 app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames()
 app.model=GameState.new(SaveStore.new("user://memo_%d"%Time.get_ticks_usec()));app.model.start_new();app.model.changed.connect(app.update_hud)
 var s:Dictionary=app.model.state.duplicate(true);s.chief_level=4;s.resident_count=3;s.resident_guide_seen=true;s.family_next_at=Time.get_unix_time_from_system()+10000
 s.homes=[{"uid":"h1","style":1,"claimed":true,"level":4,"position":[900,900],"cost":{"wood":20,"stone":10}}];s.built=true;s.reward_claimed=true
 s.facilities=[{"uid":"f1","kind":"farm","level":4,"position":[1300,1000],"cost":{"wood":10,"stone":5}}];s.outposts=[{"uid":"p1","level":1,"position":[1600,800],"cost":{"wood":10,"stone":10}}]
 check(app.model.commit(s),"Memo fixture accepted");app.enter_game();await frames(12)
 var jobs:=ResidentJobs.new(app.model)
 check(jobs.assign("resident-0","wood"),"Wood worker assigned")
 check(jobs.assign("resident-1","farmer","farm:f1"),"Farmer assigned")
 check(jobs.assign("resident-2","guard","outpost:p1"),"Guard assigned")
 var worker:TrialResident=app.world.residents[0];var farmer:TrialResident=app.world.residents[1];var guard:TrialResident=app.world.residents[2]
 for actor in app.world.residents:actor.set_physics_process(false)
 check(TrialResident.GATHER_SECONDS==10 and TrialResident.WORK_WALK_FACTOR==.5,"Only resident gather duration changes; travel stays half speed")
 var target:Dictionary={}
 for n in app.model.nodes():
  if n.kind=="wood":target=n;break
 worker.position=DemoConfig.point(target.position)+Vector2(0,65);worker.job_kind="wood";worker.job_target=target.id;worker.job_phase="harvest";worker.job_timer=10;app.model.claim_gather(target.id,worker.resident_id)
 worker._job_tick(9)
 check(jobs.entry(worker.resident_id).cargo.is_empty() and worker.job_timer>0,"Nine seconds does not award gather cargo")
 worker._job_tick(1.01)
 check(not jobs.entry(worker.resident_id).cargo.is_empty(),"Ten second gather awards one load")
 var next:Dictionary=app.model.state.duplicate(true);next.farm_cycles={"farm:f1":{"phase":"grow","elapsed":30.0,"cycle_level":4,"cuts":0,"stock":0}};app.model.commit(next)
 farmer.position=app.model.building_position("farm:f1")+Vector2(0,90);farmer._job_tick(.1)
 check(farmer.job_phase=="farm_wait","Growing farm retains tending phase")
 farmer.set_physics_process(true);guard.set_physics_process(true)
 var before:=farmer.duty_clock;var growth:float=FarmProduction.entry(app.model,"farm:f1").elapsed
 app.resident_panel.show_summary();await frames(90)
 check(app.modal and not app.world.simulation_paused and farmer.duty_clock>before,"Residents keep acting behind popup")
 check(FarmProduction.entry(app.model,"farm:f1").elapsed>growth,"Farm growth continues behind popup")
 check(guard.visual.guard_weapon!=null and guard.visual.guard_weapon.visible,"Guard carries spear")
 app.close_modal()
 app.world.player.manual_camera=true;app.world.player.zoom_at(Vector2(app.w,app.h)*.5,1.1,Vector2(1300,1000));await frames()
 app.building_workflow.show_upgrade_confirmation("farm:f1",{"wood":10,"stone":5},func():pass);await frames()
 var at:=Vector2(250,300);var zoom:float=app.world.player.zoom_factor
 mouse(at,MOUSE_BUTTON_WHEEL_UP,true);await frames()
 check(app.modal and app.world.player.zoom_factor>zoom,"Upgrade wheel zoom preserves confirmation")
 mouse(at,MOUSE_BUTTON_LEFT,true);motion(at+Vector2(70,20));mouse(at+Vector2(70,20),MOUSE_BUTTON_LEFT,false);await frames()
 check(app.modal,"Upgrade background drag does not dismiss")
 touch(at,0,true);touch(at+Vector2(80,0),1,true);drag_touch(at+Vector2(-30,0),0);drag_touch(at+Vector2(110,0),1);touch(at+Vector2(-30,0),0,false);touch(at+Vector2(110,0),1,false);await frames()
 check(app.modal,"Upgrade pinch does not dismiss")
 mouse(at,MOUSE_BUTTON_LEFT,true);mouse(at,MOUSE_BUTTON_LEFT,false);await frames()
 check(not app.modal,"Upgrade short background tap dismisses")
 var rect:=BuildingVisuals.display_rect("farm",4);var dimensions:=BuildingVisuals.display_size("farm",4)
 check(is_equal_approx(rect.get_center().y,-230*.2+3+dimensions.y*.3),"Farm artwork lowers by 30 percent without changing footprint")
 check(is_equal_approx(app.objective.position.y,14.8) and is_equal_approx(app.quest_wood.position.y,40.4),"Quest title lowered and resource row raised")
 await frames(6);await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://reports/memo-0164-world.png")
 var party:Dictionary=app.model.state.duplicate(true);party.family_joined=false;party.pending_family_count=1;party.family_next_at=0;app.model.commit(party);app.model.ensure_family_visit();await frames()
 if app.model.family_available():
  var count:int=app.model.resident_count();var hero:Vector2=app.world.player.position
  app.family.request()
  check(app.model.resident_count()>count and app.world.player.position==hero and app.task!="family","Resident acceptance is immediate without hero travel")
 else:check(false,"Visitor fixture must be available")
 print(JSON.stringify({"checks":checks,"failures":failures}));app.queue_free();await frames();quit(0 if failures.is_empty() else 1)
