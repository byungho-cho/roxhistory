extends SceneTree
var lab
var checks:=0
var failed:=0
var evidence:=[]
func _initialize():call_deferred("run")
func check(ok:bool,why:String):
 checks+=1
 if not ok:failed+=1;push_error(why)
func run():
 lab=load("res://scenes/hunt_duel_lab.tscn").instantiate();root.add_child(lab);lab.set_process(false);await process_frame
 for key in ["attack","skill","chain"]:
  lab.reset_round();lab.advance(lab.APPROACH_END);lab.next_attack=[999.0,999.0]
  lab.rules.sp=3
  if key=="attack":lab._act(0,key)
  else:lab._try_player(key)
  lab.next_attack=[999.0,999.0]
  var impact:float=lab.contact_at[0]
  var maximum:=0.0
  check(lab.cues.count("han_"+("basic" if key=="attack" else key))==0,"no strike sound before actual contact")
  while lab.age[0]+.00001<impact:
   lab.advance(minf(1.0/60,impact-lab.age[0]));await process_frame
   maximum=maxf(maximum,lab._position(0).distance_to(lab._settled_anchor(0)))
   check((lab._position(1)-lab._position(0)).dot(lab.Left.direction_to(lab.Right))>25,"committed actor never crosses the enemy")
  var error:float=lab.presentation.spear_point(lab.a).distance_to(lab._position(1)-Vector2(0,33))
  check(error<3,"mesh spear tip reaches body for "+key)
  check(maximum<=lab.BASIC_MAX_TRAVEL+.01,"short target-aware step, no fixed78px dash")
  check(lab.rules.hp[1]==100-({"attack":11,"skill":27,"chain":38}[key]),"unchanged per-attack authoritative damage")
  check(lab.cues.count("han_"+("basic" if key=="attack" else key))==1,"one sound on contact")
  check(lab.fx.any(func(f):return f.name=="contact_"+key),"painted contact effect created on hit frame")
  check(lab.rules.sp<3 if key!="attack" else true,"normal and chain spend separately")
  evidence.append({"motion":key,"tip_error":error,"maximum_step":maximum,"contact_seconds":impact})
  for i in 170:lab.advance(1.0/120)
  check(lab.motion[0]=="idle","authored recovery returns to ready pose")
  check(lab.presentation.spear_point(lab.a).distance_to(lab._position(1)-Vector2(0,33))>18,"ready spear does not overlap body")
 lab.reset_round();lab.advance(lab.APPROACH_END);lab.rules.hp[1]=1;lab._act(0,"attack");lab.next_attack=[999.0,999.0]
 lab.advance(lab.contact_at[0]);lab.advance(.15)
 check(lab.motion[1]=="death" and lab.b.preview.modulate.a>.9 and lab.b.death_effect.age<0,"deer fall visible before reward replacement")
 lab.toggle_pause();var age=lab.age.duplicate();lab.advance(5);check(age==lab.age,"pause freezes death/reward progression")
 lab.toggle_pause();lab.advance(.85)
 check(lab.approach_active and lab.rules.hp==[100,100] and lab.rules.sp==1,"unchanged one-second full reset")
 print("D0070 contact: ",checks," checks, ",failed," failures")
 FileAccess.open("D:/workspace/roxhistory/build/d0070-282/contact-d0070.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failed,"contacts":evidence},"  "))
 lab.queue_free();await process_frame;await create_timer(.3).timeout;quit(1 if failed else 0)
