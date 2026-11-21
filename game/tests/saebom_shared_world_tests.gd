extends SceneTree

var lab
var assertions:=0
var failures:=0
var capture:=false
const ForestHP:=100
const AuthoredHeavyRelease:=3.566667/3.0

func _initialize()->void:
 capture="--render-verify" in OS.get_cmdline_user_args()
 call_deferred("run")

func check(ok:bool, requirement:String)->void:
 assertions+=1
 if not ok:
  failures+=1
  push_error(requirement)

func round_ready()->void:
 lab.reset_round()
 for i in 135:
  lab.next_attack=[999.0,999.0]
  lab.advance(1.0/120.0)
 lab.next_attack=[999.0,999.0]

func shot(name:String)->void:
 if not capture:return
 await process_frame
 await RenderingServer.frame_post_draw
 var pixels:=root.get_texture().get_image()
 check(not pixels.is_empty() and pixels.save_png("res://reports/"+name+".png")==OK,"GPU rendered "+name)

func contacts_for(world, action:String)->Array:
 return world.contacts.filter(func(event):return event.get("motion") == action and event.get("side") == 0)

func observe(action:String, fps:int, miss:=false, art:=false)->Dictionary:
 round_ready()
 var world=lab.shared_world
 var start:float=lab.rules.elapsed
 var shown:=false
 if action=="attack":
  lab._act(0,action)
 else:
  lab.rules.sp=3 if action=="chain" else 2
  lab._refresh()
  if action=="chain":lab.chain_button.pressed.emit()
  else:lab.skill_button.pressed.emit()
  shown=lab.cast_notice.get("key","")==action and lab.rules.sp<.001
 var moved:=false
 var initial_pos:=Vector3.INF
 var translated:=false
 var premature:=false
 var impact:=-1.0
 var launch_seen:=false
 var windup_seen:=false
 var support_seen:=false
 for i in range(ceili(fps*4.5)):
  lab.next_attack=[999.0,999.0]
  lab.advance(1.0/float(fps))
  if world.projectile_releases.is_empty() and lab.rules.hp[1]!=ForestHP:premature=true
  if art and action=="skill" and not windup_seen and lab.age[0]>=.9:
   windup_seen=true
   await shot("saebom-2sp-windup")
  if art and action=="chain" and not support_seen and lab.age[0]>=.55:
   support_seen=true
   await shot("saebom-3sp-support")
  if not world.projectile.is_empty():
   var position:Vector3=world.projectile.position
   if initial_pos==Vector3.INF:initial_pos=position
   elif initial_pos.distance_to(position)>.025:translated=true
   if miss and not moved:
    moved=true
    var line:Vector3=world.direction
    world.bodies[1].position+=Vector3(-line.z,0,line.x)*4
    world.render_poses(lab,0)
   if art and action=="skill" and not launch_seen and float(world.projectile.flight_age)>=.055:
    launch_seen=true
    await shot("saebom-2sp-flight")
  if impact<0 and lab.rules.hp[1]!=ForestHP:
   impact=lab.rules.elapsed-start
   if art:
    lab.advance(.04)
    await shot("saebom-2sp-contact")
 var contact:=contacts_for(world,action)
 return {"bad":premature,"shown":shown,"launches":world.projectile_releases.duplicate(true),"contacts":contact,"hp":lab.rules.hp[1],"translated":translated,"moved":moved,"impact":impact,"cues":lab.cues.duplicate(),"active":not world.projectile.is_empty()}

func run()->void:
 if capture:DirAccess.make_dir_recursive_absolute("res://reports")
 lab=load("res://scenes/hunt_duel_lab.tscn").instantiate()
 root.add_child(lab)
 lab.set_process(false)
 await process_frame
 lab._select("saebom",false)
 lab._select("forest",true)
 check(is_instance_valid(lab.shared_world),"Saebom/forest uses shared world")
 if not is_instance_valid(lab.shared_world):quit(1);return
 check(lab.a.preview.skeleton.get_world_3d()==lab.b.preview.skeleton.get_world_3d(),"both animated rigs share the 3D world")
 for fps in [30,60,120]:
  var good:Dictionary=await observe("skill",fps,false,capture and fps==120)
  print("2 SP ",fps," FPS launches=",good.launches," hit=",good.impact," hp=",good.hp," cues=",good.cues)
  check(good.shown,"valid input announces and spends 2 SP")
  check(not good.bad and good.launches.size()==1 and good.contacts.size()==1,"one release then one real projectile contact at "+str(fps))
  check(good.hp==73 and good.translated,"flight travels before exactly 27 damage")
  if good.launches.size()==1 and good.contacts.size()==1:
   var release:Dictionary=good.launches[0]
   var hit:Dictionary=good.contacts[0]
   check(absf(float(release.attack_age)-AuthoredHeavyRelease)<.018,"release matches the authored animation marker")
   check(hit.get("kind","")=="projectile" and float(hit.time)>float(release.time),"damage waits for stone collision")
 var miss:Dictionary=await observe("skill",120,true)
 check(miss.launches.size()==1 and miss.moved and miss.translated and miss.contacts.is_empty() and miss.hp==100,"target can dodge after launch: no damage")
 check(not miss.active and not miss.cues.has("deer_hit"),"missed projectile expires without impact cue")
 var basic:Dictionary=await observe("attack",120)
 check(not basic.bad and basic.launches.size()==1 and basic.contacts.size()==1 and basic.hp==89,"ordinary sling uses one real shot and normal damage")
 var support:Dictionary=await observe("chain",120,false,capture)
 check(support.shown and support.launches.is_empty() and support.contacts.is_empty() and support.hp==100,"3 SP support casts without a projectile or damage")
 round_ready()
 lab.rules.sp=1
 lab._refresh()
 lab.skill_button.pressed.emit()
 check(lab.cast_notice.is_empty() and lab.shared_world.projectile_releases.is_empty() and lab.rules.sp==1,"rejected cast neither spends nor launches")
 lab.rules.sp=2
 lab._refresh()
 lab.skill_button.pressed.emit()
 for i in 155:
  lab.next_attack=[999.0,999.0]
  lab.advance(1.0/120)
  if not lab.shared_world.projectile.is_empty():break
 check(not lab.shared_world.projectile.is_empty(),"projectile is active during a real flight")
 if not lab.shared_world.projectile.is_empty():
  var before:Vector3=lab.shared_world.projectile.position
  lab.toggle_pause()
  lab.advance(2.0)
  check(lab.shared_world.projectile.position==before and lab.rules.hp[1]==100,"pause freezes the in-flight stone and does not damage")
  lab.toggle_pause()
 lab.reset_round()
 check(lab.shared_world.projectile.is_empty() and lab.shared_world.projectile_releases.is_empty() and lab.cast_notice.is_empty(),"reset clears an in-flight stone and cast")
 lab.reset_round()
 for i in 120*13:lab.advance(1.0/120)
 var organic: Array=lab.shared_world.contacts
 check(organic.any(func(e):return e.side==0) and organic.any(func(e):return e.side==1),"organic exchange allows both Saebom and deer to land physical hits")
 print("Saebom shared world: ",assertions," checks, ",failures," failures")
 lab.queue_free()
 await process_frame
 await create_timer(.15).timeout
 quit(1 if failures else 0)
