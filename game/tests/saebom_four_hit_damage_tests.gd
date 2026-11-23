extends SceneTree
const L=preload("res://scenes/hunt_duel_lab.tscn")
const K=preload("res://scripts/duel_saebom_stone_knife.gd")
var bad:=0
var checks:=0
func _initialize()->void:call_deferred("run")
func ck(ok:bool,label:String)->void:
 checks+=1
 print("HIT_SPLIT ",ok," ",label)
 if not ok:bad+=1
func one(hp:int,ally_hp:int,enemy_attack:bool,rally:bool)->Dictionary:
 var l=L.instantiate()
 l.show_final_test35=true
 root.add_child(l)
 l.set_process(false)
 l._select("saebom",false)
 l.next_attack=[999.,999.]
 for i in 200:l.advance(1./120.)
 var w=l.shared_world
 w.bodies[1].position=w.bodies[0].position+w.direction*1.31
 l.rules.hp.assign([ally_hp,hp])
 l.rules.sp=3.
 l._render_actors()
 if rally:l.local_bom_rally_until=l.rules.elapsed+5.
 l._try_player("skill")
 var losses:Array[int]=[]
 var beats:Array[int]=[]
 var changes:Array[float]=[]
 var started:=false
 for i in 234:
  if enemy_attack and not started and l.age[0]>=.54:
   started=true
   l._act(1,"attack")
  var before:int=l.rules.hp[1]
  l.next_attack=[999.,999.]
  l.advance(1./120.)
  if l.rules.hp[1]<before:
   losses.append(before-l.rules.hp[1])
   beats.append(int(w.knife_beat))
   changes.append(l.age[0])
  if not l.rules.living():break
 var out:Dictionary={"losses":losses,"beats":beats,"times":changes,"ally":l.rules.hp[0],"prey":l.rules.hp[1],"projectiles":w.projectile_releases.size()}
 l.free()
 return out
func run()->void:
 ck([K.damage_at(0,false),K.damage_at(1,false),K.damage_at(2,false),K.damage_at(3,false)]==[5,5,6,11],"base hit amounts total 27")
 ck([K.damage_at(0,true),K.damage_at(1,true),K.damage_at(2,true),K.damage_at(3,true)]==[6,6,7,13],"cumulative +20 percent rounding totals 32")
 var regular:=one(100,100,false,false)
 ck(regular.losses==[5,5,6,11] and regular.beats==[1,2,3,4] and regular.projectiles==0,"genuine shared 1v1 detects and damages all four expected time windows: %s"%[regular])
 var rallied:=one(100,100,false,true)
 ck(rallied.losses==[6,6,7,13] and rallied.prey==68,"genuine shared 1v1 still totals 32 when fully buffed")
 var rescue:=one(4,1,true,false)
 ck(rescue.losses==[4] and rescue.beats==[1] and rescue.ally==1 and rescue.prey==0,"first genuine contact KOs prey and prevents the still-pending retaliatory hit; actual HP is clamped: %s"%[rescue])
 var interrupt:=one(100,1,true,false)
 ck(interrupt.ally==0 and interrupt.losses==[5] and interrupt.prey==95,"live foe can interrupt with lethal contact; prior actual damage stays: %s"%[interrupt])
 var l=L.instantiate()
 l.show_final_test35=true
 root.add_child(l)
 l.set_process(false)
 l._select("saebom",false)
 l._toggle_local_formation("near")
 var q=l.local_formation
 for unit in q.units:unit.next=999.
 var u:Dictionary=q.units[2]
 var v:Dictionary=q.units[3]
 u.feet=v.feet-Vector2(48,0)
 u.sp=3.
 q._request("skill",2)
 var squad:Array[int]=[]
 for i in K.contacts.size():
  var hp:=int(v.hp)
  q._resolve(2)
  squad.append(hp-int(v.hp))
 ck(squad==[5,5,6,11] and q.missiles.is_empty(),"dedicated squad near split hits without launching a sling stone")
 var hits:int=q.hits.size()
 v.hp=3
 q._play(u,"idle")
 u.sp=3.
 q._request("skill",2)
 q._resolve(2)
 q._resolve(2)
 ck(v.hp==0 and q.hits.size()==hits+1,"squad lethal early contact produces only one damage event")
 l.free()
 print("HIT_SPLIT ",checks-bad,"/",checks)
 quit(bad)
