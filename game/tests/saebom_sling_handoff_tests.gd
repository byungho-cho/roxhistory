extends SceneTree
const L=preload("res://scenes/hunt_duel_lab.tscn")
var failed:=0
var checks:=0
func _initialize()->void:call_deferred("run")
func ck(ok:bool,msg:String)->void:
 checks+=1
 print("SLING_HANDOFF ",ok," ",msg)
 if not ok:failed+=1
func test_solo(when:String)->void:
 var l=L.instantiate()
 l.show_final_test35=true
 root.add_child(l)
 l.set_process(false)
 l._select("saebom",false)
 for n in 200:
  l.next_attack=[999.,999.]
  l.advance(1./120.)
 var w=l.shared_world
 var left:Vector3=w.bodies[0].position
 var d:Vector3=w.direction
 w.bodies[1].position=left+d*3.8
 l._render_actors()
 l._act(0,"attack")
 var moved:=false
 var held_on_idle:=false
 var blended:=false
 var fwd:Vector2=Vector2.ZERO
 var unchanged:=true
 for n in 145:
  var active:bool=not w.projectile.is_empty()
  if not moved and ((when=="before_release" and l.age[0]>.13) or (when=="during_flight" and active and w.projectile.flight_age>.02)):
   moved=true
   w.bodies[1].position=left+d*1.37+(d.cross(Vector3.UP)*.65 if when=="during_flight" else Vector3.ZERO)
  l.next_attack=[999.,999.]
  l.advance(1./120.)
  if not w.projectile.is_empty():
   var v:Vector3=w.projectile.velocity
   if fwd==Vector2.ZERO:fwd=Vector2(v.x,v.z)
   else:unchanged=unchanged and fwd.is_equal_approx(Vector2(v.x,v.z))
   blended=blended or w.bom_close or l.a.preview.has_meta("saebom_melee_blade")
   held_on_idle=held_on_idle or l.motion[0]=="idle"
 ck(moved and not blended and w.projectile_releases.size()==1 and is_equal_approx(float(w.projectile_releases[0].attack_age),.32),when+" never displays knife over live stone nor changes release count/age")
 ck(moved and unchanged and w.bom_close and l.a.preview.has_meta("saebom_melee_blade"),when+" keeps fixed shot and equips knife only after original lifecycle")
 if when=="before_release":ck(l.rules.hp[1]==89,"a target that approaches before release still takes the native shot")
 else:ck(l.rules.hp[1]==100 and held_on_idle,"real lateral dodge stays a miss and sling stays held through early idle")
 l.free()
func run()->void:
 test_solo("before_release")
 test_solo("during_flight")
 var l=L.instantiate()
 l.show_final_test35=true
 root.add_child(l)
 l.set_process(false)
 l._select("saebom",false)
 l._toggle_local_formation("far")
 var q=l.local_formation
 var u:Dictionary=q.units[2]
 var deer:Dictionary=q.units[3]
 deer.feet=u.feet+Vector2(126.,0.)
 q._begin(2,"attack",3)
 q._resolve(2)
 ck(q.missiles.size()==1,"squad native ranged resolution launches one locked stone")
 deer.feet=u.feet+Vector2(54.,0.)
 q._play(u,"idle")
 q._draw_pose(0.)
 ck(u.saebom_melee_pending and not u.bom_close and not u.actor.preview.has_meta("saebom_melee_blade"),"squad queues close transition but displays no knife while sling stone unresolved")
 deer.hp=0
 for n in 100:q._update_projectiles(1./120.)
 ck(q.missiles.is_empty() and deer.hp==0 and q.hits[-1].result=="miss","target KO clears without phantom HP or retarget")
 deer.hp=100
 q._draw_pose(0.)
 ck(u.bom_close and u.actor.preview.has_meta("saebom_melee_blade"),"next valid neutral pose after projectile lifecycle equips knife")
 l.free()
 print("SLING_HANDOFF ",checks-failed,"/",checks)
 quit(failed)
