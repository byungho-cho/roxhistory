extends SceneTree
const LAB=preload("res://scenes/hunt_duel_lab.tscn")
var count:=0
var failed:=0
func _initialize()->void:call_deferred("go")
func ck(ok:bool,msg:String)->void:
 count+=1
 print("CHARGE_STOP ",ok," ",msg)
 if not ok:failed+=1
func go()->void:
 var l=LAB.instantiate()
 l.show_final_test35=true
 root.add_child(l)
 l.set_process(false)
 l._select("saebom",false)
 l.next_attack=[999.,999.]
 for n in 190:l.advance(1./120.)
 var w=l.shared_world
 w.bodies[1].position=w.bodies[0].position+w.direction*1.42
 l._render_actors()
 l._act(1,"skill")
 var damage_frames:=0
 var safest:=INF
 var raw_min:=INF
 for n in 375:
  var hp:int=l.rules.hp[0]
  l.advance(1./120.)
  if l.rules.hp[0]<hp:
   damage_frames+=1
   ck(n==296 and hp-l.rules.hp[0]==27 and w.consumed[1],"same actual charge still lands 27 once at baseline substep 296")
   ck(absf((w.bodies[1].position-w.bodies[0].position).length()-.93843675)<.001,"true ground spacing is unchanged at impact")
   var a=l.a.preview.skeleton.get_node_or_null("OrdinaryHitAccent")
   ck(a!=null and a.charge_flinch and l.ordinary_resting_hit[0],"localized head/shoulder flinch is active through the existing rest-only mode")
   ck(l.a.preview.has_meta("saebom_melee_blade"),"already-held melee blade stays held on impact")
  if w.consumed[1] and l.motion[1]=="skill":
   var out:Vector3=(w.bodies[1].position-w.bodies[0].position).normalized()
   var h:Dictionary=w.hurt_capsule(0)
   var mid:Vector3=(h.a+h.b)*.5
   safest=minf(safest,(w.weapon_point(1)-mid).dot(out)-float(h.radius))
   if w.saebom_deer_display_pivot.is_finite():
    w.restore_saebom_deer_stop()
    raw_min=minf(raw_min,(w.weapon_point(1)-mid).dot(out)-float(h.radius))
    w.present_saebom_deer_stop("skill")
 ck(raw_min<0. and safest>.035,"only display pivots are capped outside the body; original sweep pose restores")
 ck(damage_frames==1 and l.rules.hp[0]==73,"no second damage in the braking or return")
 ck(not w.saebom_deer_display_pivot.is_finite(),"no offset remains once charge finishes")
 l.reset_round()
 ck(w.saebom_deer_stop_action<0 and not w.bom_close,"encounter reset clears display brake and melee state")
 l.free()
 print("CHARGE_STOP ",count-failed,"/",count)
 quit(failed)
