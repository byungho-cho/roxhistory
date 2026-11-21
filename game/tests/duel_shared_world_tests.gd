extends SceneTree
var lab
var checks:=0
var failures:=0
var cases:=[]
func _initialize():call_deferred("run")
func check(ok:bool,why:String):
 checks+=1
 if not ok:failures+=1;push_error(why)
func settle():
 lab.reset_round();lab.advance(lab.APPROACH_END+.00001);lab.next_attack=[999.0,999.0]
func tap(button):
 for down in [true,false]:
  var e:=InputEventScreenTouch.new();e.index=0;e.pressed=down;e.position=button.get_global_rect().get_center();root.push_input(e,true);await process_frame
func snapshot()->Dictionary:
 var w=lab.shared_world
 return {"time":lab.rules.elapsed,"sp":lab.rules.sp,"hp":lab.rules.hp.duplicate(),"age":lab.age.duplicate(),"bodies":[w.bodies[0].position,w.bodies[1].position],"knockback":w.knockback.duplicate(),"contact_count":w.contacts.size(),"fx":lab.fx.duplicate(true),"timer":lab.timer.text}
func run():
 lab=load("res://scenes/hunt_duel_lab.tscn").instantiate();root.add_child(lab);lab.set_process(false);await process_frame
 var w=lab.shared_world
 check(lab.a.preview.skeleton.get_world_3d()==lab.b.preview.skeleton.get_world_3d(),"both native rigs share the same World3D")
 check(lab.a.preview.pivot.get_parent()==w.bodies[0] and lab.b.preview.pivot.get_parent()==w.bodies[1],"rendered rigs belong to their physical bodies")
 check(not lab.a.preview.display.visible and not lab.b.preview.display.visible and w.display.visible,"one composited viewport rather than two character billboards")
 check(w.bodies[0].collision_layer==1 and w.hurt[0].collision_layer==2,"body collision and attack hurt volumes are distinct")
 check(w.capsule_hit(Vector3(-10,1,0),Vector3(10,1,0),Vector3(0,.7,0),Vector3(0,1.3,0),.3)<.5,"fast segment entering and exiting capsule is detected")
 check(w.capsule_hit(Vector3(-10,5,0),Vector3(10,5,0),Vector3(0,.7,0),Vector3(0,1.3,0),.3)==INF,"clear 3D vertical miss stays a miss")
 for i in 60:
  lab.advance(1.0/60)
  check(lab.rules.hp==[100,100] and lab.rules.sp==1,"opening approach has no damage or SP progression")
 check(w.bodies[0].position.dot(w.direction)<w.bodies[1].position.dot(w.direction),"first run meets without crossing")
 for fps in [30,60]:
  for key in ["attack","skill","chain","enemy"]:
   settle();lab.rules.sp=3
   var side:=1 if key=="enemy" else 0
   var motion:String="attack" if key=="enemy" else key
   if motion=="attack":lab._act(side,motion)
   else:lab._try_player(motion)
   lab.next_attack=[999.0,999.0]
   var had_hit:=false
   for i in ceili((lab.a.duration+1)*fps):
    var old=lab.rules.hp.duplicate();lab.advance(1.0/fps)
    if old!=lab.rules.hp:
     check(not had_hit,"one damage event per committed attack")
     had_hit=true
     var event:Dictionary=w.contacts[-1]
     var h:Dictionary=event.hurt
     check(event.attack_age>=event.active_from-.000001 and event.attack_age<=event.active_to+.000001,"swept hit is strictly inside attack's valid interval")
     check(w.capsule_hit(event.weapon_from,event.weapon_to,h.a,h.b,h.radius+w.WEAPON_RADIUS)!=INF,"damage backed by an actual swept XYZ capsule contact")
     var axis:Vector3=h.b-h.a
     var near:Vector3=h.a+axis*clampf((event.point-h.a).dot(axis)/maxf(.0001,axis.length_squared()),0,1)
     check(absf(event.point.distance_to(near)-float(h.radius))<.0001,"FX contact is on the actual hurt surface")
     check(lab.fx.any(func(f):return f.name=="contact_"+motion),"D0070 impact effect fires on the contact frame")
   var target:=1-side
   var damage:int=13 if side==1 else 38 if key=="chain" else 27 if key=="skill" else 11
   check(had_hit and lab.rules.hp[target]==100-damage,"unchanged damage with contact timing at %dfps %s"%[fps,key])
   check(w.contacts.size()==1,"no duplicate contact across rendered frames")
   check(w.max_body_penetration<.0001,"no residual body capsule penetration")
   var cue:String="deer_basic" if side==1 else "han_basic" if key=="attack" else "han_"+key
   check(lab.cues.count(cue)==1,"one matching impact sound")
   cases.append({"fps":fps,"motion":key,"hp":lab.rules.hp.duplicate(),"contact_time":w.contacts[0].time if had_hit else -1,"contacts":w.contacts.size(),"maximum_penetration":w.max_body_penetration})
 # Timer/screen-distance hooks cannot manufacture damage in the shared path.
 settle();lab._land(0,"skill");check(lab.rules.hp==[100,100],"legacy timer-only land hook cannot damage")
 for key in ["attack","skill","chain"]:
  settle();w.bodies[1].position+=Vector3(12,0,-10);lab.rules.sp=3
  if key=="attack":lab._act(0,key)
  else:lab._try_player(key)
  lab.next_attack=[999.0,999.0]
  for i in 180:lab.advance(1.0/60)
  check(lab.rules.hp==[100,100] and w.contacts.is_empty(),"out-of-reach %s cannot cause timer damage"%key)
  check(not lab.fx.any(func(f):return String(f.name).begins_with("contact_")),"a miss has no phantom impact")
  var position:Vector3=w.bodies[0].position;lab.advance(.2)
  check(w.bodies[0].position.distance_to(position)<.001,"miss recovery does not teleport to an old anchor")
 # Simultaneous high-speed motion is resolved on the relative swept path.
 settle()
 for i in 10:
  var before0:Vector3=w.bodies[0].position;var before1:Vector3=w.bodies[1].position
  w.resolve_bodies([before1,before0])
  check((w.bodies[1].position-w.bodies[0].position).dot(w.direction)>0,"simultaneous bodies cannot exchange sides")
  check(w.max_body_penetration<.0001,"continuous close-range collision leaves no overlap")
 # The target approaches while Han is airborne; landing remains on its near side.
 settle();lab.motion.assign(["run","run"]);lab.a.play("run");lab.b.play("run")
 for i in 150:
  w.knockback=[w.direction*3,-w.direction*3];lab.advance(1.0/60)
  check((w.bodies[1].position-w.bodies[0].position).dot(w.direction)>0,"sustained opposing charges stop rather than sliding past")
 check(w.max_body_penetration<.0001,"sustained charge capsules remain separated")
 check(w.bodies[0].position.distance_to(w.bodies[1].position)>=w.BODY_RADII[0]+w.BODY_RADII[1]-.001,"hip/foreleg envelopes prevent visible root/leg stacking")
 # The target approaches while Han is airborne; landing remains on its near side.
 settle();lab.rules.sp=3;lab._try_player("chain");lab.next_attack=[999.0,999.0];lab.advance(.62)
 w.knockback[1]=-w.direction*3
 for i in 90:
  lab.advance(1.0/60)
  check((w.bodies[1].position-w.bodies[0].position).dot(w.direction)>0,"moving-target jump never lands beyond deer")
 check(w.max_body_penetration<.0001,"moving-target landing has no capsule overlap")
 # Retained UI costs, exclusive touch targets and full pause/resume/reset state.
 for sp in [2.0,3.0]:
  settle();lab.rules.sp=sp;lab._refresh();await tap(lab.skill_button)
  check(lab.motion[0]=="skill" and lab.rules.sp==sp-2,"portrait spends exactly2SP at2/3SP")
 settle();lab.rules.sp=3;lab._refresh();await tap(lab.chain_button)
 check(lab.motion[0]=="chain" and lab.rules.sp==0,"upper icon only spends3SP")
 lab.advance(.3);lab.toggle_pause();var frozen=snapshot();lab.advance(5)
 check(snapshot()==frozen,"pause freezes XYZ bodies/attacks/knockback/SP/timer/FX")
 lab.toggle_pause();lab.advance(.1);check(lab.rules.elapsed>frozen.time,"resume continues same state")
 settle();lab.rules.hp[1]=1;lab._act(0,"attack");lab.next_attack=[999.0,999.0]
 for i in 120:
  lab.advance(1.0/120)
  if not lab.rules.living():break
 check(lab.motion[1]=="death","real hit starts deer defeat sequence")
 lab.advance(.15);check(lab.b.preview.pivot.visible and lab.b.death_effect.age<0,"deer remains visible before reward")
 lab.toggle_pause();frozen=snapshot();lab.advance(3);check(snapshot()==frozen,"death reset wait pauses")
 lab.toggle_pause();lab.advance(.87)
 check(lab.rules.hp[1]==0 and not lab.approach_active,"round stays down during fade and post-fade wait")
 lab.advance(.39)
 check(lab.approach_active and lab.rules.hp==[100,100] and lab.rules.sp==1 and lab.timer.text=="00:00","death resets both bodies/HP/SP/timer together")
 lab.toggle_pause();lab.reset_round();check(lab.paused and lab.rules.sp==1,"manual reset preserves pause")
 lab.toggle_pause()
 lab._select("uram",false)
 check(lab.shared_world==null and not lab.a.preview.has_meta("duel_world"),"other matchups retain original controller and renderer")
 lab._select("hangyeol",false)
 check(lab.shared_world!=null and lab.a.preview.skeleton.get_world_3d()==lab.b.preview.skeleton.get_world_3d(),"return selection creates one valid common scene")
 print("D0071 shared world: ",checks," checks, ",failures," failures")
 DirAccess.make_dir_recursive_absolute("user://reports")
 var report:=FileAccess.open("user://reports/physics-verification.json",FileAccess.WRITE)
 if report: report.store_string(JSON.stringify({"checks":checks,"failures":failures,"cases":cases},"  "))
 lab.queue_free();await process_frame;await create_timer(.3).timeout;quit(1 if failures else 0)
