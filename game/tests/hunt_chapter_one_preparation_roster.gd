extends SceneTree

const Catalog = preload("res://scripts/hunt_chapter_one_catalog.gd")
var fail := 0
var total := 0
func _initialize() -> void: call_deferred("run")
func ck(ok: bool, message: String) -> void:
 total += 1
 if not ok: fail += 1
 print(("PASS " if ok else "FAIL ") + message)

func send_pointer(at:Vector2, down:bool, mouse:bool, pointer:int=0) -> void:
 if mouse:
  var event:=InputEventMouseButton.new()
  event.button_index=MOUSE_BUTTON_LEFT
  event.position=at
  event.global_position=at
  event.pressed=down
  root.push_input(event,true)
 else:
  var event:=InputEventScreenTouch.new()
  event.index=pointer
  event.position=at
  event.pressed=down
  root.push_input(event,true)

func run() -> void:
 var p:=OS.get_environment("APPDATA").replace("\\","/").to_lower()
 if FileAccess.file_exists("user://save.json") or not p.contains("chapter-prep-roster") or not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(p+"/"):quit(90);return
 var app=load("res://scenes/main.tscn").instantiate()
 if app.get_script()==null or not app.has_method("prepare_selected_hunt"):quit(91);return
 root.add_child(app); await process_frame
 app.model.start_new({},true)
 app.application_active=true
 for n in [1,2,3,7,8]:
  app.model.state.hunt_cleared=0 if n==1 else 12
  app.model.state[Catalog.CLEARS_KEY]={"ch1-06":true,"ch1-07":true} if n>3 else {}
  app.hunt_stage=Catalog.route_id(n)
  app.show_screen("hunt_select")
  for i in range(8):await process_frame
  app.prepare_selected_hunt()
  var deadline:=Time.get_ticks_msec()+30000
  while app.screen!="hunt" and Time.get_ticks_msec()<deadline:await process_frame
  ck(app.screen=="hunt","main opens 1-"+str(n))
  if app.screen!="hunt":quit(92);return
  var h=app.hunt
  for i in range(40):await process_frame
  ck(h.arrival_finished and h.preparation.visible and h.placement_grid.visible,"real formation shown, 1-"+str(n))
  if n==1:
   ck(not h.chapter_prep_setup_ok and h.deer.visible and h.prep_tags[3].visible and h.chapter_one_solo and h.rules.manual_only,"unchanged 1-1 single target and manual locks")
  else:
   var expected: Array=Catalog.encounter(n).prey
   var kinds:Array=[];var actual_slots:Array=[]
   for i in h.chapter_prep_foes.size():
    var actor=h.chapter_prep_foes[i]
    var slot:=int(actor.get_meta("chapter_prep_slot"))
    actual_slots.append(slot)
    kinds.append(actor.native_species)
    ck(actor.is_visible_in_tree() and actor.is_native_ready() and actor.native.model_path==actor.Prey.model_path(actor.native_species),"exact visible rig 1-%d slot %d"%[n,slot])
    ck(actor.position.is_equal_approx(h.ENEMY_CELLS[slot]) and h.chapter_prep_foe_tags[i].is_visible_in_tree(),"native role marker/unique grid placement 1-%d slot %d"%[n,slot])
   ck(h.chapter_prep_setup_ok and expected==kinds and actual_slots==([4,2] if expected.size()==2 else [4,0,5]),"complete catalog roster 1-"+str(n))
   ck(not h.prep_tags[3].visible and (h.deer in h.chapter_prep_foes or not h.deer.visible),"no duplicate legacy representative 1-"+str(n))
   var roster_label:=h.find_child("ChapterPrepEnemyRosterCaption",true,false) as Label
   ck(roster_label!=null and roster_label.text=="적 %d마리"%expected.size(),"no single-species label on multi roster 1-"+str(n))
  if DisplayServer.get_name()!="headless" and not OS.get_environment("QA_T43").is_empty():
   var still:=root.get_texture().get_image()
   still.save_png(OS.get_environment("QA_T43").path_join("prep-1-%d.png"%n))
  if n==1: continue
  h.start_combat()
  ck(h.branch_video.visible and not h.placement_grid.visible and h.chapter_prep_foes.all(func(item):return not item.visible),"same-frame lock and prep actors hidden when VS begins 1-"+str(n))
  if n in [2,3]:
   var mouse:bool=n==3
   var at:=Vector2(450,240)
   send_pointer(at,true,mouse)
   send_pointer(at,true,false,5)
   ck(h.branch_video.visible and not h.running and not is_instance_valid(h.chapter_story_battle),"VS press does not start battle before release 1-"+str(n))
   send_pointer(at,false,mouse)
   var first=h.chapter_story_battle
   ck(is_instance_valid(first) and h.running and h.transition_elapsed<0.0 and not h.branch_video.visible and not h.preparation.visible,"same-frame direct combat after VS tap/click 1-"+str(n))
   send_pointer(at,false,false,5)
   ck(first==h.chapter_story_battle and h.vs_skip_presses.is_empty() and not h.result_shown,"held second pointer cannot restart or finish combat 1-"+str(n))
  else:
   for i in range(8):await process_frame
   ck(h.branch_video.visible and not h.running and not is_instance_valid(h.chapter_story_battle),"no input leaves original VS running 1-"+str(n))
  for i in range(135):
   await process_frame
   if is_instance_valid(h.chapter_story_battle):break
  var b=h.chapter_story_battle
  ck(is_instance_valid(b) and h.running and h.chapter_prep_foes.all(func(item):return not item.visible),"no prep ghosts on first combat frame 1-"+str(n))
  if is_instance_valid(b):
   var native_kinds:Array=[];for i in range(3,b.units.size()):native_kinds.append(b.units[i].id)
   ck(native_kinds==Catalog.encounter(n).prey,"combat roster matches preparation 1-"+str(n))
 print("PREP ROSTER ",total," checked ",fail," failed")
 quit(fail)
