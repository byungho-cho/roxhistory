extends SceneTree
const S=preload("res://scripts/hunt_duel_local_squad.gd")
var bad:=0
var checks:=0
func _initialize()->void:call_deferred("go")
func ck(ok:bool,msg:String)->void:
 checks+=1
 print("AGGRO ",ok," ",msg)
 if not ok:bad+=1
func go()->void:
 var q:=S.new()
 root.add_child(q)
 q.setup()
 var nats:Dictionary={}
 var min_clear:=INF
 for n in 520:
  q.tick(1./120.,false)
  for ev in q.hits:
   if ev.get("result","")=="hit" and int(ev.from)>=3:nats[ev.target]=true
  for i in range(3,6):
   for j in range(i+1,6):
    if q.units[i].hp>0 and q.units[j].hp>0:min_clear=minf(min_clear,(q.units[i].feet as Vector2).distance_to(q.units[j].feet))
 ck(nats.has(1),"natural default opening brings a deer into tank range and hits Uram: %s"%[nats])
 ck(min_clear>=33.5,"native ground anchors on enemy lanes remain separate: %s"%min_clear)
 q.free()
 q=S.new()
 root.add_child(q)
 q.setup()
 var points:=[Vector2(470,200),Vector2(490,270),Vector2(650,360),Vector2(555,314),Vector2(550,270),Vector2(677,365)]
 for i in 6:q.units[i].feet=points[i]
 ck([q._target(3),q._target(4),q._target(5)]==[1,1,2],"simultaneous local tank priority and far Saebom priority by geometry")
 # Hold all other actors fixed while checking exact ratio choices.
 q.units[0].feet=Vector2(573,309)
 ck(q._target(3)==0,"point-blank Han beats Uram even inside the tank radius")
 q.units[0].feet=Vector2(629,314)
 ck(q._target(3)==1,"local Uram at 78.5 px wins over Han at 74 px using 1.2 versus 1.1")
 q.units[0].feet=points[0]
 var initial:int=q._target(3)
 q._damage(2,3,11,"attack")
 ck(q.units[3].hp==89 and q._target(3)==initial,"nonlethal Saebom damage does not generate aggro")
 q.hits.clear()
 q.units[3].feet=Vector2(710,314)
 q.units[0].feet=Vector2(790,314)
 q.units[2].feet=Vector2(710,391)
 ck(q._target(3)==0,"Han at 80 px beats Saebom at 77 using 1.1 versus 1.0")
 q.units[0].feet=Vector2(815,314)
 q.units[2].feet=Vector2(710,414)
 ck(q._target(3)==2,"both outside 98 px use neutral weights and nearer Saebom wins")
 q.units[0].feet=points[0]
 q.units[2].feet=points[2]
 q.units[3].feet=Vector2(610,335)
 ck(q._target(3)==2,"far enemy selects nearest ally, no tank pull")
 q.units[3].feet=q.units[0].feet
 ck(q._target(3)==0,"point-blank zero distance stays finite and chooses the valid ally")
 ck([q._target(0),q._target(1),q._target(2)]==[3,4,5],"allied target selection unchanged")
 q.units[5].feet=Vector2(548,220)
 q.units[3].feet=Vector2(545,323)
 q.units[4].feet=Vector2(552,270)
 for n in 240:
  for i in range(3,6):q._approach_enemy_slot(i,1,1./120.)
 ck(q._enemy_slot_ready(3,1) and q._enemy_slot_ready(4,1) and q._enemy_slot_ready(5,1),"three local foes reach their distinct tank slots without overlap")
 ck(q.units[3].feet.y>q.units[4].feet.y and q.units[4].feet.y>q.units[5].feet.y,"front and opposing flanks remain stable")
 q._begin(3,"attack",1)
 q.units[1].hp=0
 q.units[0].feet=Vector2(560,315)
 ck(q.units[3].victim==1 and q._target(3)==0,"Han next when closer, committed deer still locked to defeated Uram")
 var han:int=q.units[0].hp
 q._resolve(3)
 ck(q.units[0].hp==han and q.hits.is_empty(),"no damage redirected from a defeated victim")
 q.units[0].hp=0
 ck([q._target(3),q._target(4),q._target(5)]==[2,2,2],"last living ally still targeted")
 q.units[2].hp=0
 ck(q._target(3)==-1 and q._target(4)==-1 and q._target(5)==-1,"does not target any knocked-out ally")
 q.configure_saebom_distance_drill("near")
 ck(q._target(3)==2,"dedicated near drill still attacks only Saebom")
 q.configure_saebom_distance_drill("far")
 ck(q._target(3)==1,"dedicated far drill still starts on Uram")
 q.free()
 print("AGGRO ",checks-bad,"/",checks)
 quit(bad)
