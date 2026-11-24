extends SceneTree
const Catalog = preload("res://scripts/hunt_chapter_one_catalog.gd")
var count := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func ck(ok: bool, what: String) -> void:
 count += 1
 if not ok: failed += 1
 print(("PASS " if ok else "FAIL ") + what)
func touch_at(at:Vector2,down:bool,key:int=0)->void:
 var e:=InputEventScreenTouch.new()
 e.index=key;e.position=at;e.pressed=down
 root.push_input(e,true)

func run() -> void:
 var safe:=OS.get_environment("APPDATA").replace("\\","/").to_lower()
 var expected:=OS.get_environment("ROX_STORY_TEST_PROFILE").replace("\\","/").to_lower()
 if safe != expected or not safe.ends_with("/storytour/appdata") or FileAccess.file_exists("user://save.json"):quit(90);return
 if safe.is_empty() or not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(safe+"/"):quit(91);return
 var main_scene:=load("res://scenes/main.tscn") as PackedScene
 if main_scene==null:quit(92);return
 var app=main_scene.instantiate()
 if app.get_script()==null:quit(93);return
 root.add_child(app);await process_frame
 ck(app.chapter_one_preview_enabled(),"opt-in only")
 ck(app.model.start_new({},true),"actual profile starts in isolated save")
 app.application_active=true
 for n in [1,2,3,4,5,6,7,8,9,10]:
  var route_id:=Catalog.route_id(n)
  app.hunt_stage=route_id
  app.show_screen("hunt_select")
  for i in range(4): await process_frame
  var s:=app.find_child("HuntStage"+str(route_id),true,false) as BaseButton
  ck(s!=null and not s.disabled and app.hunt_stage_is_unlocked(route_id),"map selects unlocked proper 1-"+str(n))
  if n<10:ck(not app.hunt_stage_is_unlocked(Catalog.route_id(n+1)),"next stage not yet available "+str(n))
  app.prepare_selected_hunt()
  var until:=Time.get_ticks_msec()+18000
  while app.screen!="hunt" and Time.get_ticks_msec()<until:await process_frame
  ck(app.screen=="hunt","real preparation loads 1-"+str(n))
  if app.screen!="hunt":quit(94);return
  var h=app.hunt
  if n==1:
   ck(h.chapter_one_solo and h.stage_one_one and h.rules.manual_only and h.rules.first_hunt,"preserve shipped 1-1 all tutorial gates")
   app.record_hunt_win()
  else:
   h.arrival_finished=true;h.settle_age=.25;h.start_combat()
   for i in range(360):
    h._process(1./60.)
    if is_instance_valid(h.chapter_story_battle):break
   var b=h.chapter_story_battle
   ck(is_instance_valid(b) and h.running,"actual post-VS combat 1-"+str(n))
   if not is_instance_valid(b):quit(95);return
   var data:Dictionary=Catalog.encounter(n)
   var active:Array=[]
   for u in b.units:
    if u.hp>0:active.append(u.id)
   ck(active==(["hangyeol"] if n in [2,3] else ["hangyeol","uram"] if n==4 else ["hangyeol","uram","saebom"])+data.prey,"exact armed active roster 1-"+str(n))
   if n==2:
    var untouched:int=b.units[4].hp
    b._subtract_hp_and_show(3,6)
    ck(b.units[3].hp==44 and b.units[4].hp==untouched and not b.huds[1].visible and not b.huds[2].visible,"1-2 two independent prey; only Han HUD")
   if n in [3,4]:
    var moved:Dictionary={}
    var slot:int=n-2
    ck(b.story_join_slot==slot and b.units[slot].hp==0 and not b.huds[slot].visible,"pending ally has no combat presence")
    var frozen:float=-1.0
    var real_start:float=-1.0
    var genuine_guide:=false
    var paused_count:=0
    var max_snap_distance:=0.0
    var seen_arrival:=false
    var frozen_hp:Array=[]
    var frozen_sp:Array=[]
    for f in range(449 if n==3 else 390):
     h._process(1./60.)
     if b.story_entry_active():
      if frozen<0.0:
       frozen=b.elapsed
       real_start=b.story_entry_clock
       for u in b.units:frozen_hp.append(u.hp);frozen_sp.append(u.sp)
       var guide:CharacterGuide=h.story_cutin
       genuine_guide=guide.panel_group.has_node("CreamPanel") and guide.character.name=="GuideFullBody" and guide.character.texture.get_height()>guide.character.texture.get_width() and guide.character.get_global_rect().end.y<=app.h
      if is_equal_approx(frozen,b.elapsed) and h.story_cutin.visible and b.units[slot].hp==0 and not b._free_to_cast(0):
       paused_count+=1
    ck(genuine_guide,"uses the original guide panel and contained head-to-feet art")
    ck(paused_count>=238 and paused_count<=243 and real_start>=2.48 and real_start<=2.53,"guide remains after four real seconds of frozen combat")
    var same:=true
    for i in b.units.size():same=same and b.units[i].hp==frozen_hp[i] and b.units[i].sp==frozen_sp[i]
    ck(same and h.story_cutin.visible and h.story_cutin.next_hint.visible and not b.story_entry_done,"HP and SP unchanged, guide still waiting and shows advance")
    var at:Vector2=h.story_cutin.panel_group.get_node("CreamPanel").get_global_rect().get_center()
    var outside:=Vector2(30,52)
    touch_at(outside,true);touch_at(outside,false)
    touch_at(outside,true);touch_at(at,false)
    ck(h.story_cutin.visible and not b.story_entry_done,"backdrop and unmatched release cannot advance")
    touch_at(at,true)
    ck(h.story_cutin.visible and not b.story_entry_done,"touch down alone does not advance")
    var prior_actors: Array[Vector2] = []
    var reserved:Vector2 = b.units[slot].home
    for unit in b.units:
     if unit.hp>0:prior_actors.append(unit.feet)
    var free_reserved:=prior_actors.all(func(feet):return reserved.distance_to(feet)>=36.0)
    var pre_join_feet:Array=[]
    for u in b.units:pre_join_feet.append(u.feet)
    touch_at(at,false)
    if n==3:
     ck(b.units[0].feet==pre_join_feet[0] and is_equal_approx(b.units[1].feet.x-b.units[0].feet.x,38.) and b._target(3)==1 and b._target(4)==1,"1-3 only: actual guide release reforms living units to face Uram")
    else:
     var unchanged:=true
     for i in [0,1,3,4,5]:unchanged=unchanged and b.units[i].feet==pre_join_feet[i]
     ck(unchanged and b.story_uram_opening_targets.is_empty(),"1-4 Saebom causes no reposition or aggro change to existing units")
    ck(not h.story_cutin.visible and b.story_entry_done and h.touch_points.is_empty(),"touch release inside guide dismisses with no click-through")
    seen_arrival=b.story_entry_done
    var entry_point:Vector2=b.units[slot].feet
    max_snap_distance=entry_point.distance_to(b.units[0].feet)
    var clear:=prior_actors.all(func(feet):return entry_point.distance_to(feet)>=34.0)
    var placed:bool=b.story_allied_placement.size()==3
    var lane_ok:bool=(entry_point.is_equal_approx(reserved) if free_reserved else entry_point.distance_to(reserved)<=88.1) if placed else max_snap_distance<100.0
    var hp_after:int=b.units[slot].hp
    var sp_after:float=b.units[slot].sp
    touch_at(at,false,8)
    ck(b.units[slot].hp==hp_after and b.units[slot].sp==sp_after,"later release cannot duplicate or recast entry")
    var first_enemy_attacks:Dictionary={}
    for f in 285:
     h._process(1./60.)
     if n==3:
      for i in [3,4]:
       if not first_enemy_attacks.has(i) and b.units[i].move=="attack" and b.units[i].contact>=0.0:first_enemy_attacks[i]=b.units[i].victim
     for i in 3:
      if b.units[i].move=="attack":moved[i]=true
    if n==3:
     ck(seen_arrival and max_snap_distance>=34.0 and max_snap_distance<100.0,"1-3 exception: Uram and Han have separate slots in the reformed frontline")
    else:
     ck(seen_arrival and clear and lane_ok,"1-4: Saebom appears at assigned open cell or a clear alternate")
    ck(b.story_entry_done and moved.has(slot) and b.huds[slot].visible,"reinforcement joins and attacks following a real delay")
    if n==3:
     ck(first_enemy_attacks.get(3,-1)==1 and first_enemy_attacks.get(4,-1)==1 and b.story_uram_opening_targets.is_empty(),"both opening attacks really commit to Uram, then normal targets")
     ck(not moved.has(2) and not b.huds[2].visible,"no Saebom in 1-3")
   # Force only result of seeded QA fight to test the public-facing save and CTA.
   for j in range(3,b.units.size()):b.units[j].hp=0
   h._process(.0167)
   ck(h.result_shown and h.rules.outcome=="win","real result entered 1-"+str(n))
   if n<10:ck(app.next_hunt_stage_id()==Catalog.route_id(n+1),"next from result maps to "+str(n+1))
  ck(app.chapter_one_story_completions().get(Catalog.STAGE_KEYS[n-1],false)==true,"stable cleared stage 1-"+str(n))
  if n>=6 and n<=9:ck(app.model.state.hunt_cleared==5,"new fights must not overwrite old Ch2 ordinal")
 ck(app.model.state.hunt_cleared==6 and app.hunt_stage_is_unlocked(6),"chapter 2 first id 6 unlocks after canonical final 1-10")
 var reloaded:=GameState.new(app.model.store,true)
 ck(reloaded.state.get("hunt_cleared",-1)==6 and reloaded.state.get(Catalog.CLEARS_KEY,{}).size()==10,"disk persists ten distinct clears with unchanged legacy schema")
 app.model.state.hunt_cleared=12
 app.model.state.erase(Catalog.CLEARS_KEY)
 ck(app.hunt_stage_is_unlocked(Catalog.route_id(6)) and not app.hunt_stage_is_unlocked(Catalog.route_id(7)) and app.hunt_stage_is_unlocked(Catalog.route_id(10)) and app.hunt_stage_is_unlocked(11),"older finished boss and Ch2 retained, new 7 still needs 6")
 print("PRODUCTION TOUR ",count," checks, ",failed," failures")
 quit(failed)
