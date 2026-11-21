extends SceneTree

var lab
var fails:=0
var checks:=0
var capture:=false

func _initialize():
 capture="--render-verify" in OS.get_cmdline_user_args()
 call_deferred("run")

func check(ok:bool, label:String):
 checks+=1
 if not ok:
  fails+=1
  push_error(label)

func init_round():
 lab.reset_round()
 lab.next_attack=[999.0,999.0]
 for i in 130: lab.advance(1.0/120)
 lab.next_attack=[999.0,999.0]

func simulate(move:String,tap_at:float,fps:int,miss:=false,shots:=false)->Dictionary:
 init_round()
 var world=lab.shared_world
 if miss:
  world.bodies[1].position+=Vector3(12,0,-10)
  world.render_poses(lab,0)
 if tap_at>=0:lab.rules.sp=3
 if move=="foe":
  lab._act(1,"skill")
 else:
  lab._act(0,move)
 var base:float=lab.visual_clock
 var init_hp:Array=lab.rules.hp.duplicate()
 var sent:=false
 var saw_icon:=false
 var took_shot:=false
 var counter_shot:=false
 for i in range(ceili(fps*4.1)):
  if not sent and tap_at>=0 and lab.visual_clock-base>=tap_at:
   sent=true
   lab.chain_button.pressed.emit()
   saw_icon=lab.cast_notice.get("key","")=="chain" and lab.cast_notice.get("icon")==lab.skill_hud.chain_art.texture
  lab.next_attack=[999.0,999.0]
  lab.advance(1.0/fps)
  if shots and not took_shot and lab.cues.has("uram_parry"):
   took_shot=true
   lab.advance(.05)
   await process_frame
   await RenderingServer.frame_post_draw
   var shot:=root.get_texture().get_image()
   check(not shot.is_empty() and shot.save_png("res://reports/uram-parry-qa.png")==OK,"real rendered shield contact")
  if shots and not counter_shot and lab.rules.hp[1]<init_hp[1]:
   counter_shot=true
   lab.advance(.035)
   await process_frame
   await RenderingServer.frame_post_draw
   var image:=root.get_texture().get_image()
   check(not image.is_empty() and image.save_png("res://reports/uram-counter-qa.png")==OK,"real rendered counter contact")

 var contacts:Array=world.contacts.duplicate(true)
 return {"hp":lab.rules.hp.duplicate(),"initial":init_hp,"cues":lab.cues.duplicate(),"icon":saw_icon,"contacts":contacts,
  "accent":lab.accent.entries,"zoom":lab.accent.zoom,"sp":lab.rules.sp}

func event_of(events:Array,kind:String)->Dictionary:
 for event in events:
  if event.get("kind","")==kind:return event
 return {}

func run():
 if capture:DirAccess.make_dir_recursive_absolute("res://reports")
 lab=load("res://scenes/hunt_duel_lab.tscn").instantiate()
 root.add_child(lab);lab.set_process(false)
 await process_frame
 lab._select("uram",false)
 lab._select("adult",true)
 check(is_instance_valid(lab.shared_world),"Uram and adult boar use the shared 3D world")
 if not is_instance_valid(lab.shared_world):quit(1);return
 var world=lab.shared_world
 check(lab.a.preview.skeleton.get_world_3d()==lab.b.preview.skeleton.get_world_3d(),"real shield and boar share World3D")
 lab.reset_round()
 lab.advance(.85)
 check(lab.approach_active and lab.rules.hp==[100,180],"approach has no SP or damage")
 var incoming:Dictionary=await simulate("foe",-1,120)
 print("Unguarded charge: ",incoming.hp," ",incoming.cues)
 check(incoming.hp[0]<incoming.initial[0] and incoming.cues.count("uram_parry")==0 and incoming.accent==0,"unguarded physical collision hurts; no shield sound or zoom")
 var hit:=event_of(incoming.contacts,"body")
 if hit.is_empty() or hit.motion!="skill":quit(1);return
 var timing:float=float(hit.attack_age)
 var best:=timing-.16
 var front:=Transform3D.IDENTITY
 var half:=Vector2(.35,.36)
 check(world.shield_sweep(Vector3(0,0,1),Vector3(0,0,-1),front,front,half)<INF,"front approach hits shield plane")
 check(world.shield_sweep(Vector3(0,0,-1),Vector3(0,0,1),front,front,half)==INF,"rear cannot trigger parry")
 check(world.shield_sweep(Vector3(1,0,1),Vector3(1,0,-1),front,front,half)==INF,"outside shield rim cannot trigger parry")
 if best>=0:
  for fps in [30,60,120]:
   var good:Dictionary=await simulate("foe",best,fps,false,capture and fps==120)
   print("Timed shield ",fps," FPS: ",good.hp," ",good.cues)
   check(good.icon,"accepted shield input shows Uram icon")
   check(good.hp[0]==good.initial[0] and good.cues.count("uram_parry")==1 and good.accent==1,"one real parry and zero incoming damage at FPS "+str(fps))
   check(not event_of(good.contacts,"shield").is_empty(),"parry requires actual shield contact")
   check(good.zoom==1,"parry zoom resolves")
   var counter_hits:int=good.contacts.filter(func(x):return x.motion=="counter").size()
   check(counter_hits==1 and good.initial[1]-good.hp[1]==18,"counter damage only from a single physical shield strike")
  var far:Dictionary=await simulate("foe",best,120,true)
  check(far.icon and far.hp==far.initial and far.cues.count("uram_parry")==0 and far.accent==0,"timed input with geometry miss has cast icon only")
 for tap in [maxf(0,timing-.75),timing+.1]:
  var wrong:Dictionary=await simulate("foe",tap,120)
  check(wrong.hp[0]<wrong.initial[0] and wrong.cues.count("uram_parry")==0 and wrong.accent==0,"bad timing never plays shield effects or blocks")
 for key in ["attack","skill"]:
  var strike:Dictionary=await simulate(key,-1,120)
  print("Club ",key,": ",strike.hp," ",strike.cues)
  check(strike.initial[1]-strike.hp[1]==(11 if key=="attack" else 27),"physical club hit applies damage once: "+key)
  var whiff:Dictionary=await simulate(key,-1,120,true)
  check(whiff.hp==whiff.initial and whiff.cues.count("uram_"+("basic" if key=="attack" else key))==0,"out of range club is silent and harmless")
 lab.reset_round()
 check(lab.cast_notice.is_empty() and lab.accent.entries==0,"reset clears cast and presentation")
 print("Uram shared world: ",checks," checks, ",fails," failures")
 lab.queue_free();await process_frame;await create_timer(.15).timeout
 quit(1 if fails else 0)
