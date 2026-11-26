extends SceneTree
const C=preload("res://scripts/hunt_chapter_one_catalog.gd")
var errors:=0
var count:=0
var app
var movie:=false
func _initialize()->void:call_deferred("run")
func ck(ok:bool,what:String)->void:
 count+=1
 if not ok:errors+=1
 print(("PASS " if ok else "FAIL ")+what)
func render()->void:
 await process_frame
 if movie:await RenderingServer.frame_post_draw
func ready_hunt(n:int):
 app.hunt_stage=C.route_id(n)
 app.show_screen("hunt_select")
 for i in 6:await process_frame
 app.prepare_selected_hunt()
 var until:=Time.get_ticks_msec()+45000
 while Time.get_ticks_msec()<until:
  await process_frame
  if app.screen=="hunt" and app.hunt.arrival_finished:
   app.hunt.set_process(false)
   return app.hunt
 return null
func start(h):
 h.start_combat()
 var e:=InputEventScreenTouch.new()
 e.index=1;e.position=Vector2(430,230);e.pressed=true
 h.handle_vs_skip(e);e.pressed=false;h.handle_vs_skip(e)
 return h.chapter_story_battle
func touch(at:Vector2,down:bool,idx:int=5)->void:
 var e:=InputEventScreenTouch.new()
 e.index=idx;e.position=at;e.pressed=down
 root.push_input(e,true)
func active(b)->Array:
 var out:Array=[]
 for i in 3:
  if b.units[i].hp>0 and b.huds[i].visible:out.append(b.units[i].id)
 return out
func carry(clear_count:int,persisted:Dictionary={}) -> void:
 app.model.state.hunt_cleared=clear_count
 app.model.state[C.CLEARS_KEY]=persisted.duplicate()
 app.model.state[C.RECRUITS_KEY]=[]
 app.model.state.erase("hunt_ch1_formation")
func real_result(h,b,win:bool)->void:
 if win:
  if b.units.size()>4 and b.units[3].hp>0:
   var first:Dictionary=b.units[3]
   var cues:=[]
   b.story_contact_audio.connect(func(cue:String,_priority:int):cues.append(cue))
   b._damage(0,3,first.hp,"attack")
   var before:float=b.elapsed
   for f in 20:h._process(.0334)
   ck(not h.result_shown and b.story_outcome.is_empty() and b.elapsed>before and first.actor.death_effect.visible and first.actor.death_effect.position==first.story_death_point and cues.count("enemy_death")==1,"intermediate prey death shows its own drop and exactly one approved cue without pausing combat")
  for i in range(3,b.units.size()):
   if b.units[i].hp>0:b._damage(0,i,b.units[i].hp,"attack")
 else:
  for i in 3:b.units[i].hp=0
 h._process(.0334)
 if win:
  for frame in 75:h._process(.0334)
 ck(h.result_shown and h.rules.outcome==("win" if win else "loss"),"actual result triggers "+("win" if win else "loss"))
func suite(n:int,expected:Array,owned_toggles:bool)->void:
 var h=await ready_hunt(n)
 if h==null:ck(false,"actual stage prep opens");return
 ck(h.prep_ally_count==expected.size() and h.portrait_frames.size()==expected.size() and h.battle_toggles_unlocked==owned_toggles,"actual 1-%d replay preparation and independent toggle gate (%d owned)"%[n,expected.size()])
 if movie:
  for f in 17:await render()
 if expected.size()==3:
  h.select_hunter(0)
  h.move_hunter(4)
  ck(h.assigned_cells[0]==4,"owned replay hero can use a non-default formation seat")
 if n==1:
  h.speed=2.0
  h.update_toggles()
  ck(h.speed==1.0 and h.auto_button.get_meta("toggle_name")== "AUTO","recruited 1-1 replay forces 1x; AUTO is the only toggle")
 var b=start(h)
 if not is_instance_valid(b):ck(false,"real native squad opens");return
 ck(active(b)==expected and b.story_join_slot==-1 and not is_instance_valid(h.story_cutin),"replay opens with all owned heroes and no recruitment/guide")
 if expected.size()==3:ck(b.units[0].feet.is_equal_approx(b.story_allied_placement[0]),"actual combat honors placement")
 for f in 94:
  h._process(1./30.)
  if movie:await render()
 ck(b.story_entry_clock==0. and not b.story_deer_shove_done,"replay never repeats original recruit or Han shove after 3s")
 b.units[0].sp=3.0
 b._draw_pose(0.)
 var button:Button=b.huds[0].chain_button
 ck(button.is_visible_in_tree() and not button.disabled,"Han replay 3SP HUD becomes clickable at 3 SP")
 var at:=button.get_global_rect().get_center()
 touch(at,true);touch(at,false)
 ck(b.units[0].move=="chain" and b.units[0].sp==0.,"true HUD touch starts 3SP and spends actual SP")
 if not movie:
  for i in range(1,expected.size()):
   b.units[i].sp=3.0
   b._draw_pose(0.)
   var role_button:Button=b.huds[i].chain_button
   ck(role_button.is_visible_in_tree() and not role_button.disabled,"owned replay hero "+str(i)+" has a ready 3SP HUD button")
   var role_at:=role_button.get_global_rect().get_center()
   touch(role_at,true);touch(role_at,false)
   ck(b.units[i].sp==0.0 and b.units[i].move in ["chain","counter"] and b.units[0].move=="chain","second hero "+str(i)+" starts through actual HUD while Han is casting")
  if expected.size()==3:
   # Ready Uram's ordinary action while Han is still in his independently started 3SP.
   var target:int=b._target(1)
   b._begin(1,"attack",target)
   b.units[1].sp=2.0
   var clock:float=b.elapsed
   var prey_hp:int=b.units[target].hp
   b._draw_pose(0.)
   var ready:Button=b.huds[1].portrait_button
   var ready_at:=ready.get_global_rect().get_center()
   ck(not ready.disabled and b.units[1].move=="attack","ready Uram 2SP during own basic and Han cast")
   touch(ready_at,true);touch(ready_at,false)
   ck(b.units[1].move=="skill" and b.units[1].age==0.0 and b.units[1].sp==0.0 and b.elapsed==clock and b.units[0].move=="chain" and b.units[target].hp==prey_hp,"real Uram 2SP touch replaces own unlanded basic with no wait for Han")
  for i in range(expected.size(),3):
   ck(not b.huds[i].visible and not b.story_allows(i,"chain"),"unowned replay hero has no deployment or 3SP entry")
 if movie:
  for f in 55:
   h._process(1./30.)
   await render()

func check_1_1_roster(expected: Array, record_win := false) -> void:
 var h = await ready_hunt(1)
 if not is_instance_valid(h):
  ck(false, "1-1 replay opens after recorded victories")
  return
 if record_win:
  h.rules.outcome = "win"
  h.show_result()
  var select_stage := h.find_child("ResultStageSelect", true, false) as Button
  var may_retry: bool = is_instance_valid(select_stage) and app.hunt_recruitment_clears() == {C.STAGE_KEYS[0]: true}
  ck(may_retry, "1-1 victory records its clear and exposes the result stage selection button")
  if not may_retry:
   return
  select_stage.pressed.emit()
  h = await ready_hunt(1)
  if not is_instance_valid(h):
   ck(false, "1-1 is selectable from the victory result")
   return
 else:
  app.retry_hunt()
 h = app.hunt
 var deadline := Time.get_ticks_msec() + 15000
 while not h.arrival_finished and Time.get_ticks_msec() < deadline:
  await process_frame
 h.set_process(false)
 var showing := 0
 for hunter in h.hunters:
  showing += int(hunter.visible)
 ck(h.arrival_finished and h.prep_ally_count == expected.size() and h.portrait_frames.size() == expected.size() and showing == expected.size(), "1-1 retry preparation shows %d currently cleared allies" % expected.size())
 var b = start(h)
 for i in 100:
  h._process(1.0 / 60.0)
 if expected.size() == 1:
  ck(not is_instance_valid(b) and h.running and h.rules.party_hp[0] > 0 and h.rules.party_hp[1] == 0 and h.rules.party_hp[2] == 0 and h.party_cards[0].hud.visible and not h.party_cards[1].hud.visible and not h.party_cards[2].hud.visible, "1-1 solo retry permits only Han in the live fight and HUD")
 else:
  ck(is_instance_valid(b) and active(b) == expected and b.story_join_slot == -1, "1-1 live replay starts with the exact currently cleared roster")

func check_reset_replay_roster() -> void:
 carry(4, {C.STAGE_KEYS[0]: true, C.STAGE_KEYS[1]: true, C.STAGE_KEYS[2]: true, C.STAGE_KEYS[3]: true})
 app.show_screen("hunt_select")
 app.model.state.hero_growth = {"uram": {"level": 2, "xp": 3}, "saebom": {"level": 2, "xp": 4}}
 app.confirm_hunt_progress_reset(Callable())
 app._reset_hunt_progress(Callable())
 ck(app.hunt_recruitment_clears().is_empty() and app.model.state[C.RECRUITS_KEY] == ["uram", "saebom"], "hunt-only reset retains acquired heroes and clears current chapter wins")
 for stage in [1, 2, 3, 4]:
  app.hunt_stage = C.route_id(stage)
  if stage == 1:
   await check_1_1_roster(["hangyeol"], true)
   continue
  app.record_hunt_win()
  if stage == 3:
   await check_1_1_roster(["hangyeol", "uram"])
  elif stage == 4:
   await check_1_1_roster(["hangyeol", "uram", "saebom"])
 ck(HeroGrowth.owns(app.model.state, "uram") and HeroGrowth.owns(app.model.state, "saebom") and HeroGrowth.read(app.model.state, "uram").xp == 3 and HeroGrowth.read(app.model.state, "saebom").xp == 4, "deployment gating preserves retained hero ownership and XP")

func run()->void:
 movie=DisplayServer.get_name()!="headless"
 app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await process_frame
 app.model.start_new({},true);app.application_active=true
 if app.modal:app.close_modal()
 if not movie:
  carry(1)
  var h=await ready_hunt(2)
  if h==null:quit(91);return
  var b=start(h)
  ck(h.prep_ally_count==1 and not b.story_allows(0,"chain"),"fresh 1-2 keeps solo tutorial and 3SP lesson lock")
  real_result(h,b,false)
  ck(not app.chapter_one_story_completions().has(C.STAGE_KEYS[1]),"loss alone does not unlock replay")
  h=await ready_hunt(2);b=start(h)
  ck(h.prep_ally_count==1 and not b.story_allows(0,"chain") and b.story_encounter.first_visit,"loss retry remains first-run")
  real_result(h,b,true)
  ck(app.chapter_one_story_completions().has(C.STAGE_KEYS[1]),"real saved 1-2 victory unlocks replay")
  await suite(2,["hangyeol"],false)
  h=await ready_hunt(3);b=start(h)
  ck(h.prep_ally_count==1 and b.story_join_slot==1 and not b.story_allows(0,"chain"),"fresh 1-3 has Han alone then only authored Uram join")
  real_result(h,b,false)
  h=await ready_hunt(3);b=start(h)
  ck(b.story_join_slot==1 and not b.story_allows(0,"chain"),"1-3 loss retry still authored and not free replay")
  real_result(h,b,true)
  await suite(3,["hangyeol","uram"],true)
 if not movie:
  carry(4)
  await suite(2,["hangyeol"],true)
 carry(4,{C.STAGE_KEYS[0]:true,C.STAGE_KEYS[1]:true,C.STAGE_KEYS[2]:true,C.STAGE_KEYS[3]:true})
 await suite(2,["hangyeol","uram","saebom"],true)
 await suite(3,["hangyeol","uram","saebom"],true)
 if not movie:
  await suite(1,["hangyeol","uram","saebom"],true)
  await check_reset_replay_roster()
 print("EARLY REPLAY ",count," checks, ",errors," failures")
 quit(errors)
