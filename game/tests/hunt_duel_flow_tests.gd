extends SceneTree
var lab
var failures=0
var checks=0
var contacts=[]
func _initialize():call_deferred("run")
func check(ok,why):
 checks+=1
 if not ok:failures+=1;push_error(why)
func run():
 lab=load("res://scenes/hunt_duel_lab.tscn").instantiate();root.add_child(lab);lab.set_process(false);await process_frame
 for moving in [false,true]:
  for key in ["attack","skill"]:
   lab.reset_round();lab.next_attack=[999.0,999.0]
   if moving:lab._act(1,"attack");lab.advance(.1)
   lab._act(0,key)
   lab.next_attack[0]=999
   if not moving:lab.next_attack[1]=999
   var contact=lab.contact_at[0];var previous=lab.rules.hp[1]
   while lab.age[0]+.000001<contact:
    lab.advance(minf(1.0/120,contact-lab.age[0]));await process_frame
   var tip=lab.presentation.spear_point(lab.a);var target=lab._position(1)-Vector2(0,33)
   var error=tip.distance_to(target)
   contacts.append({"motion":key,"moving_target":moving,"tip":str(tip),"target":str(target),"error":error,"hp":lab.rules.hp[1],"display":lab.bars[1].value})
   check(error<3.0,"real spear tip reaches live target: %s moving=%s error=%s"%[key,moving,error])
   check(lab.rules.hp[1]==previous-(11 if key=="attack" else 27),"authoritative damage unchanged")
   check(lab.bars[1].value>lab.rules.hp[1] and lab.bars[1].value<previous,"HP display starts smoothly at hit")
   var before=lab.bars[1].value;lab.toggle_pause();lab.advance(2)
   check(lab.bars[1].value==before,"HP interpolation paused")
   lab.toggle_pause()
   for i in 30:lab.advance(1.0/120);await process_frame
   check(is_equal_approx(lab.bars[1].value,float(lab.rules.hp[1])),"HP reaches authoritative target by .22s")
 # Frame crossings must show contact, not skip it or calibrate a blended pose.
 for fps in [30,60]:
  lab.reset_round();lab.next_attack=[999.0,999.0];lab._act(0,"attack")
  while lab.rules.hp[1]==100:lab.advance(1.0/fps);await process_frame
  check(lab.presentation.spear_point(lab.a).distance_to(lab._position(1)-Vector2(0,33))<.1,"exact basic contact on %d FPS hit frame"%fps)
 # Portrait cast from a live approach retains position and real weapon contact.
 for at in [.08,.22]:
  lab.reset_round();lab._act(0,"attack");lab.advance(at);lab.rules.sp=2
  var feet=lab._position(0);lab._try_player("skill");lab.next_attack=[999.0,999.0]
  check(lab._position(0).distance_to(feet)<.01,"ordinary cast does not teleport during approach")
  var hit=lab.contact_at[0]
  while lab.age[0]+.000001<hit:
   lab.advance(minf(1.0/120,hit-lab.age[0]));await process_frame
  check(lab.presentation.spear_point(lab.a).distance_to(lab._position(1)-Vector2(0,33))<3,"ordinary spear contact from approach")
  check(lab.rules.hp[1]==73 and lab.cues.count("deer_hit")==1,"one ordinary hit, no cancelled basic damage")
 lab.reset_round();lab.rules.ally_id="uram";lab.reset_round();lab.rules.sp=3;lab._try_player("chain")
 for i in 30:lab.advance(1.0/120);await process_frame
 check(lab.rules.hp[1]==100 and lab.bars[1].value==100,"damage-free shield preview does not reduce HP display")
 lab.rules.ally_id="hangyeol"
 # No phantom hits during early preparation; original 2.6-second clock retained.
 lab.reset_round();var hit_times=[];var old=100;var overlap=false
 for i in 800:
  lab.advance(1.0/120);await process_frame
  if lab.rules.hp[1]!=old:hit_times.append(lab.rules.elapsed);old=lab.rules.hp[1]
  if lab.motion[0]=="attack" and lab.age[0]>lab.motion_contact[0] and lab.presentation.phase[1]=="prepare":overlap=true
 check(hit_times.size()==3,"one damage event per automatic attack")
 check(absf(hit_times[1]-hit_times[0]-lab.Rules.BASIC_EVERY)<.02,"original 2.6s damage cadence")
 check(overlap,"enemy preparation overlaps ally recovery")
 lab.reset_round();check(lab.bars[0].value==100 and lab.bars[1].value==100,"reset snaps both displayed HP to full")
 var report_path=OS.get_environment("ROX_DUEL_FLOW_REPORT")
 if not report_path.is_empty():FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify({"contacts":contacts,"automatic_hit_times":hit_times,"recovery_preparation_overlap":overlap,"checks":checks,"failures":failures},"  "))
 print("Duel flow: ",checks," checks, ",failures," failures")
 lab.queue_free();await process_frame;await create_timer(.2).timeout;quit(1 if failures else 0)
