extends SceneTree
const Catalog = preload("res://scripts/hunt_chapter_one_catalog.gd")
var count := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func ck(ok: bool, what: String) -> void:
 count += 1
 if not ok: failed += 1
 print(("PASS " if ok else "FAIL ") + what)
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
   ck(active==(["hangyeol"] if n==2 else ["hangyeol","uram","saebom"])+data.prey,"exact armed active roster 1-"+str(n))
   if n==2:
    var untouched:int=b.units[4].hp
    b._subtract_hp_and_show(3,6)
    ck(b.units[3].hp==44 and b.units[4].hp==untouched and not b.huds[1].visible and not b.huds[2].visible,"1-2 two independent prey; only Han HUD")
   if n==3:
    var moved:Dictionary={}
    for f in range(180):
     h._process(1./60.)
     for i in 3:
      if b.units[i].move=="attack":moved[i]=true
    ck(moved.size()==3,"1-3 three actually fighting")
   # Force only result of seeded QA fight to test the public-facing save and CTA.
   for j in range(3,b.units.size()):b.units[j].hp=0
   h._process(.0167)
   ck(h.result_shown and h.rules.outcome=="win","real result entered 1-"+str(n))
   if n<10:ck(app.next_hunt_stage_id()==Catalog.route_id(n+1),"next from result maps to "+str(n+1))
  ck(app.chapter_one_story_completions().get(Catalog.STAGE_KEYS[n-1],false)==true,"stable cleared stage 1-"+str(n))
  if n>=6 and n<=9:ck(app.model.state.hunt_cleared==5,"new fights must not overwrite old Ch2 ordinal")
 ck(app.model.state.hunt_cleared==6 and app.hunt_stage_is_unlocked(6),"chapter 2 first id 6 unlocks after canonical final 1-10")
 var reloaded:=GameState.new(SaveStore.new("user://"),true)
 ck(reloaded.state.get("hunt_cleared",-1)==6 and reloaded.state.get(Catalog.CLEARS_KEY,{}).size()==10,"disk persists ten distinct clears with unchanged legacy schema")
 app.model.state.hunt_cleared=12
 app.model.state.erase(Catalog.CLEARS_KEY)
 ck(app.hunt_stage_is_unlocked(Catalog.route_id(6)) and not app.hunt_stage_is_unlocked(Catalog.route_id(7)) and app.hunt_stage_is_unlocked(Catalog.route_id(10)) and app.hunt_stage_is_unlocked(11),"older finished boss and Ch2 retained, new 7 still needs 6")
 print("PRODUCTION TOUR ",count," checks, ",failed," failures")
 quit(failed)
