extends "res://tests/building_hold_v056_tests.gd"
func snap(name:String)->void:
 await frames(6);await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://reports/polish-"+name+".png")
func center_on(point:Vector2,zoom:float=1.3)->void:
 app.world.player.manual_camera=true;app.world.player.zoom_at(Vector2(app.w,app.h)*.5,zoom,point)
func move_bubble_to(button:Control,point:Vector2)->void:
 app.world.player.pan_camera(point-button.get_global_rect().get_center());app.world.player.camera.force_update_scroll()
func run()->void:
 root.size=Vector2i(1280,800)
 app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames()
 app.model=GameState.new(SaveStore.new("user://polish_ui_%d"%Time.get_ticks_usec()));app.model.start_new();app.model.changed.connect(app.update_hud)
 var s:Dictionary=app.model.state.duplicate(true);s.chief_level=4;s.resident_count=4;s.family_next_at=Time.get_unix_time_from_system()+10000;s.resident_guide_seen=true
 s.homes=[{"uid":"h1","style":1,"claimed":true,"position":[800,900],"level":1,"cost":{"wood":20,"stone":10}}];s.built=true;s.reward_claimed=true
 s.facilities=[]
 for spec in [{"id":"fire","kind":"hearth","level":4,"at":[1200,850]},{"id":"train","kind":"training","level":4,"at":[1650,1000]},{"id":"red","kind":"shrine","level":3,"at":[1100,1200]},{"id":"blue","kind":"shrine","level":4,"at":[1450,1200]}]:s.facilities.append({"uid":spec.id,"kind":spec.kind,"level":spec.level,"position":spec.at,"cost":{"wood":10,"stone":10}})
 check(app.model.commit(s),"Non-farm visual fixture accepted");app.enter_game();await frames(15)
 for actor in app.world.residents:actor.set_physics_process(false)
 var quest:Control=app.stage.get_node("QuestPanel");var bubble:Control=app.resident_panel.bubbles["chief"]
 center_on(app.model.building_position("chief"),1.2);await frames();await move_bubble_to(bubble,quest.get_global_rect().get_center());await frames()
 check(not bubble.visible and app.resident_panel.hud_occludes(bubble.get_global_rect()),"Quest overlap hides world bubble from paint and picking")
 var folded:bool=app.quest_detail.visible;var at:=quest.get_global_rect().get_center();touch(at,0,true);touch(at,0,false);await frames()
 check(app.quest_detail.visible!=folded and not app.modal,"Quest receives touch instead of covered assignment button");await snap("hud-quest")
 await move_bubble_to(bubble,app.safe+Vector2(100,30));await frames();check(not bubble.visible,"Portrait and health bar protect their region")
 await move_bubble_to(bubble,app.chrome.slot("wood").get_center());await frames();check(not bubble.visible,"Resource HUD protects its region")
 check(quest.z_index>app.resident_panel.z_index and app.chrome.z_index>app.resident_panel.z_index,"Fixed HUD paint order exceeds world bubbles")
 app.menu_expanded=false;app.apply_menu_state(false);await frames()
 check(not app.resident_panel.fixed_hud_at(app.action_row.global_position+Vector2(30,30)),"Collapsed action slots do not hide world buttons in empty space")
 app.menu_expanded=true;app.apply_menu_state(false)
 s=app.model.state.duplicate(true);s.homes[0].upgrade=BuildingRules.new_job("hut",1,Time.get_unix_time_from_system(),false);app.model.commit(s);await frames()
 var progress:ConstructionProgress=app.building_workflow.owned_progress["h1"]
 check(progress.z_index>app.resident_panel.z_index,"Work progress stays above assignment buttons")
 check(app.resident_panel.hud_occludes(progress.get_global_rect()),"Work progress also owns its input region")
 app.model.cancel_upgrade("h1")
 var jobs:=ResidentJobs.new(app.model);jobs.assign("resident-0","wood");jobs.assign("resident-1","wood")
 var target:Dictionary={}
 for candidate in app.model.nodes():
  if candidate.kind=="wood":target=candidate;break
 var worker:TrialResident=app.world.residents[0];worker.job_kind="wood";worker.job_target=target.id;worker.job_phase="harvest";worker.job_timer=1.2
 app.model.claim_gather(target.id,worker.resident_id)
 var other:TrialResident=app.world.residents[1];other.position=DemoConfig.point(target.position)+Vector2(80,80);other._job_tick(.016)
 check(other.job_target!=target.id,"Moving worker skips the tree reserved by another")
 app.gather_action(target.id);check(app.task.is_empty() and not app.model.gather_available(target.id,"hero"),"Hero cannot steal a worker's reserved gather target")
 for tick in 3:other._job_tick(.016)
 check(other.velocity.length()>0 and other.velocity.length()<=90.751,"Actual working actor velocity is limited to half speed")
 check(other.job_walk_factor()==.5 and ActorMovement.speed()==181.5,"Half-speed work uses unchanged shared hero base")
 jobs.assign("resident-0","idle");check(app.model.gather_available(target.id,"hero"),"Resident job cancellation releases target immediately")
 app.toast("",0);center_on(Vector2(1250,950),.7);await frames(15);await snap("roads")
 var fire:Sprite2D=app.world.building_sprite("hearth:fire");var life:BuildingLifeEffects=app.world.get_node("Facility_fire/BuildingLifeEffects")
 check(fire.material==null and life.fire.flames is CPUParticles2D and life.fire.flames.emitting,"Hearth uses independent particles and an undistorted base texture")
 center_on(app.model.building_position("hearth:fire"),1.5);await frames(45);await snap("fire")
 var training:BuildingLifeEffects=app.world.get_node("Facility_train/BuildingLifeEffects")
 check(training.hunters.size()==2 and training.hunters[0].visual.tool_3d.name=="TrainingSpear","Training has visible approved character meshes and practice spears")
 center_on(app.model.building_position("training:train"),1.5);await frames(12);await snap("training-a")
 var pose:Quaternion=training.hunters[0].visual.rig.get_bone_pose_rotation(training.hunters[0].visual.bones.armR);await frames(24)
 check(training.hunters[0].visual.rig.get_bone_pose_rotation(training.hunters[0].visual.bones.armR).angle_to(pose)>.01,"Training spear pose actually animates")
 await snap("training-b")
 center_on(Vector2(1275,1200),1.1);await frames();await snap("shrines")
 var idle:TrialResident=app.world.residents[3];center_on(idle.position,1.5);idle.visual.ambient_allowed=true;idle.visual.ambient_offset=0
 for gesture in [{"at":3.75,"name":"yawn"},{"at":12.0,"name":"stretch"},{"at":21.25,"name":"doze"}]:
  idle.visual.idle_elapsed=gesture.at;idle.visual.animate(.1,Vector2.ZERO,0,false,"",0,false);idle.visual.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
  check(idle.visual.ambient_action==gesture.name,"Idle mesh applies "+gesture.name);await snap(gesture.name)
 idle.visual.animate(.1,Vector2.RIGHT,0,true,"",0,false);check(idle.visual.ambient_action.is_empty(),"Walking cancels leisure pose")
 idle.visual.animate(.1,Vector2.ZERO,0,false,"wood",.3,false);check(idle.visual.ambient_action.is_empty(),"Work cancels leisure pose")
 print(JSON.stringify({"checks":checks,"failures":failures,"build":"not exported; waiting for farm assets"}));app.queue_free();await frames();quit(0 if failures.is_empty() else 1)

