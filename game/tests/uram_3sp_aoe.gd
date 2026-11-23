
extends SceneTree
const Squad=preload("res://scripts/hunt_duel_local_squad.gd")
const Wave=preload("res://scripts/duel_uram_counter_wave.gd")
var fails:=0
func _initialize()->void:call_deferred("go")
func expect(ok:bool,title:String)->void:
 print("URAM_AOE_QA ",ok," ",title)
 if not ok:fails+=1
func make_q(pts:Array[Vector2])->Node:
 var q:=Squad.new()
 root.add_child(q)
 q.setup()
 q.local_melee_polish=true
 var u:Dictionary=q.units[1]
 u.feet=Vector2(450,265)
 u.sp=3.
 for i in range(0,q.units.size()):
  var unit:Dictionary=q.units[i]
  unit.next=9999.
  if i>=3:unit.feet=u.feet+pts[i-3]
 q._draw_pose(0.)
 return q
func timing(q:Node)->void:
 for t in range(75):
  q.elapsed+=1./120.
  q._advance_uram_ordinary_wave()
  q._advance_uram_short_fans()
func count(q:Node,tag:String,id:int)->int:
 var n:=0
 for h in q.hits:
  if h.type==tag and h.target==id:n+=1
 return n
func go()->void:
 var near:=make_q([Vector2(-280,-34),Vector2(56,0),Vector2(380,188)])
 near.units[0].feet=near.units[1].feet+Vector2(62,30)
 near._request("chain",1)
 expect(near.units[1].move=="counter" and near.units[1].sp==0.,"non-parry spends exactly 3 SP")

 near._resolve(1)
 expect(near.units[4].hp==82 and count(near,"counter",4)==1,"close primary 18 exactly once")
 expect(near.units[3].hp==91 and near.squad_stuns.has(3) and near.units[5].hp==91 and near.squad_stuns.has(5),"non-parry battlefield-wide: both behind and distant are damaged and stunned")
 expect(near.squad_stuns.has(4) and near.units[0].hp==100,"primary stunned, allies untouched")
 timing(near)
 expect(count(near,"counter_splash",3)==1 and count(near,"counter_splash",5)==1 and count(near,"counter_splash",4)==0,"pulse has no repeat or primary double hit")
 var frozen:Vector2=near.units[3].feet
 near._step(1./120.)
 expect(near.units[3].feet==frozen and near.units[3].move=="hit" and near.units[3].contact<0., "stun cancels existing contact and prohibits movement")
 expect(near.combo_opener==-1,"non-parry does not open chain")
 near.free()
 var far:=make_q([Vector2(121,0),Vector2(97,40),Vector2(-45,0)])
 far._begin(1,"counter",3);far._resolve(1)
 expect(far.units[3].hp==100 and far.units[4].hp==100 and far.units[5].hp==100 and not far.uram_ordinary_wave.is_empty(),"remote stock primary remains target-locked and delayed")
 timing(far)
 expect(far.units[3].hp==82 and far.squad_stuns.has(3) and far.units[4].hp==91 and far.squad_stuns.has(4),"remote 18 primary and 9 splash, both stunned")
 expect(far.units[5].hp==91 and count(far,"counter_splash",5)==1 and far.squad_stuns.has(5),"remote resolution still stuns enemy behind")
 far.free()
 var parry:=make_q([Vector2(56,0),Vector2(-240,100),Vector2(410,-134)])
 parry.configure_spotlight(func(_a,_b,_c,_d):pass,func(_a,_b,_c,_d):pass,func(_a,_b,_c):pass,.65,.50)
 parry._begin(1,"chain",3)
 parry.units[1].guard_source=3
 parry.units[1].age=.2
 parry._damage(3,1,23,"attack")
 expect(parry.units[1].hp==100 and parry.units[1].guarded and parry.combo_opener==3 and parry.units[3].hp==82,"valid parry defense/attacker and opener intact")
 timing(parry)
 expect(parry.units[4].hp==91 and parry.squad_stuns.has(4) and parry.units[5].hp==91 and parry.squad_stuns.has(5),"successful parry wave damages and stuns both reached secondary enemies")
 expect(count(parry,"counter",3)==1 and count(parry,"counter_splash",4)==1 and count(parry,"counter_splash",5)==1 and parry.combo_opener==3,"parry primary never doubled, AoE never creates a bonus opener")
 parry.free()
 var dead:=make_q([Vector2(56,0),Vector2(72,31),Vector2(68,-32)])
 dead.units[4].hp=0
 dead.units[5].hp=8
 dead._begin(1,"counter",3);dead._resolve(1);timing(dead)
 expect(count(dead,"counter_splash",4)==0 and not dead.squad_stuns.has(4),"pre-dead enemy ignored")
 expect(dead.units[5].hp==0 and not dead.squad_stuns.has(5),"lethal splash damage once with no stun stars on death")
 dead.free()
 var lost_primary:=make_q([Vector2(121,0),Vector2(-105,44),Vector2(300,166)])
 lost_primary._begin(1,"counter",3)
 lost_primary._resolve(1)
 lost_primary.units[3].hp=0
 timing(lost_primary)
 expect(lost_primary.units[4].hp==91 and lost_primary.units[5].hp==91 and count(lost_primary,"counter",3)==0,"committed wave reaches all living when primary dies mid-flight")
 lost_primary.free()
 quit(fails)
