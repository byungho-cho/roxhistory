extends SceneTree
var failed:=0
var checks:=0
const squad_script := preload("res://scripts/hunt_duel_local_squad.gd")
const catalog := preload("res://scripts/hunt_chapter_one_catalog.gd")
func _initialize() -> void: call_deferred("run")
func ck(ok:bool,what:String)->void:
 checks+=1
 if not ok:failed+=1
 print(("PASS " if ok else "FAIL ")+what)
func make(number:int,story:=true,placement:=PackedVector2Array()):
 var battle=squad_script.new()
 root.add_child(battle)
 if story:
  ck(battle.configure_story_encounter(catalog.encounter(number)),"configure canonical stage "+str(number))
 battle.story_allied_placement=placement
 battle.setup(Callable(),Callable(),Callable(),Callable(),Callable(),Callable(),Callable(),Callable(),Callable(),1.15,Callable(),Callable(),Callable(),Callable(),Callable(),true)
 return battle
func check_stage(number:int)->void:
 var b=make(number)
 var data:Dictionary=catalog.encounter(number)
 ck(b.units.size()==3+data.prey.size(),"actual actor roster 1-"+str(number))
 var live_actor_ids:Array=[]
 for i in b.units.size():
  if b.units[i].hp>0:live_actor_ids.append(b.units[i].id)
 ck(live_actor_ids==(["hangyeol"] if number<=3 else ["hangyeol","uram"] if number==4 else ["hangyeol","uram","saebom"])+data.prey,"actual live parties/species 1-"+str(number))
 for j in range(3,b.units.size()):
  ck(b.units[j].actor.key==data.prey[j-3] and is_instance_valid(b.units[j].actor.preview.skeleton),"actual native wildlife rig "+data.prey[j-3])
 if number==3:
  ck(b.story_allows(0,"skill") and b.story_allows(1,"skill") and not b.story_allows(2,"skill") and not b.story_allows(1,"chain"),"actual 1-3 controls gates")
  var moved:Dictionary={}
  for frame in range(480):
   b.tick(1./60.,false)
   if frame==300:ck(b.story_entry_active() and b.dismiss_story_entry() and not b.dismiss_story_entry(),"squad waits without timeout and accepts one dismissal")
   for i in 3:
    if b.units[i].move=="attack":moved[i]=true
  print("1-3 battle elapsed ",b.elapsed," attack slots ",moved," prey HP ",b.units[3].hp," ",b.units[4].hp)
  ck(moved.has(0) and moved.has(1) and not moved.has(2),"Han and delayed Uram perform native attacks; Saebom never attacks in 1-3")
  ck(b.units[3].hp<100 and b.units[4].hp<100,"1-3 attacks reduce both independent prey health pools")
 if number==2:
  ck(not b.units[1].actor.preview.visible and not b.units[2].actor.preview.visible and not b.huds[1].visible and not b.huds[2].visible,"1-2 never renders inactive allies")
  var hp:int=b.units[4].hp
  b._subtract_hp_and_show(3,12)
  ck(b.units[3].hp==38 and b.units[4].hp==hp,"one flower deer takes damage without copying to second")
 if number==4:
  ck(b.story_allows(2,"skill") and not b._story_enemy_can_use_skill(b.units[3]),"1-4 Saebom skill and enemy basics only")
 if number==5:
  ck(not b.story_allows(1,"chain") and b._story_enemy_can_use_skill(b.units[3]),"1-5 guard requires actual window, juvenile charge eligible")
 if number==10:
  ck(b._story_enemy_can_use_skill(b.units[3]),"adult skill allowed")
  b.elapsed=90.1;b._step(1./120.)
  ck(b.story_outcome=="loss" and b.ended,"actual timer defeat")
 b.queue_free()
 await process_frame
func run()->void:
 for number in [3,2,4,5,6,7,8,9,10]:
  await check_stage(number)
 var preset:=PackedVector2Array([Vector2(515,250),Vector2(590,314),Vector2(396,356)])
 var ordered=make(4,true,preset)
 ck(ordered.units[0].feet==preset[0] and ordered.units[1].feet==preset[1] and ordered.units[2].home==preset[2],"native opening placement matches custom hero seats exactly")
 ordered.story_entry_clock=2.5
 ck(ordered.dismiss_story_entry() and ordered.units[2].feet==preset[2],"late Saebom uses assigned vacant rear seat")
 ordered.queue_free()
 await process_frame
 ordered=make(4,true,preset)
 ordered.units[1].feet=preset[2]
 ordered.story_entry_clock=2.5
 ck(ordered.dismiss_story_entry() and ordered.units[2].feet.distance_to(preset[2])>=36.0 and ordered.units[2].feet.distance_to(preset[2])<54.0,"reserved seat occupied: late ally takes nearby clear spot")
 ordered.queue_free()
 await process_frame
 var reform=make(3)
 reform._begin(0,"skill",3)
 reform.units[0].sp=0.0
 reform._begin(3,"attack",0)
 reform.units[3].hp=79
 reform.units[4].hp=0
 var impacts:Array[float]=[]
 reform.story_uram_entrance_impact.connect(func():impacts.append(reform.elapsed))
 var dead_feet:Vector2=reform.units[4].feet
 var before:float=reform.elapsed
 var before_hp:int=reform.units[0].hp
 var han_contact:float=reform.units[0].contact
 reform.story_entry_clock=2.5
 ck(reform.dismiss_story_entry(),"manual guide dismissal reforms chapter 1-3")
 ck(reform.units[0].move=="skill" and reform.units[0].contact==han_contact and reform.units[0].sp==0.0 and reform.units[0].hp==before_hp and reform.elapsed==before,"preserves Han's paid action, HP, SP and battle clock")
 ck(reform.units[3].victim==-1 and reform.units[3].contact<0.0 and reform.units[3].hp==79 and reform._target(3)==1,"clears only pending old basic, preserves deer HP and redirects living prey")
 ck(reform.units[4].hp==0 and reform.units[4].feet==dead_feet and not reform.story_uram_opening_targets.has(4),"dead prey neither moves nor returns")
 for frame in 34:reform.tick(1./60.,false)
 ck(impacts.size()==1 and impacts[0]==before and reform.elapsed==before and not reform._free_to_cast(0),"one shield cue; introduction keeps existing combat clock and skill input held for the whole beat")
 for frame in 5:reform.tick(1./60.,false)
 ck(reform.story_uram_entrance_clock<0.0 and reform.elapsed>before,"combat resumes its same clock after the short introduction")
 reform.units[1].hp=0
 ck(reform._target(3)==0,"if Uram is no longer alive, normal living-target rules apply")
 reform.queue_free()
 await process_frame
 var lab=make(0,false)
 ck(lab.story_encounter.is_empty() and lab.units.size()==6 and lab.units[3].id=="forest" and lab.units[0].hp==100,"legacy laboratory defaults unchanged")
 lab.queue_free()
 await process_frame
 print("NATIVE CHAPTER ",checks," checks ",failed," failures")
 quit(failed)
