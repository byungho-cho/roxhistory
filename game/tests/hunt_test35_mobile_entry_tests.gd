extends SceneTree
## Windows synthetic phone touch on live Main and production TEST42 entry.
## Keep real-device playback/perf as a separate release gate.
var checks:=0
var failures:=0

func _initialize()->void:call_deferred("run")

func check(label:String,ok:bool)->void:
 checks+=1
 print(label,": ",ok)
 if not ok:
  failures+=1
  push_error(label)

func click_touch(button:Button, end_outside:=false)->bool:
 if not is_instance_valid(button) or not button.is_visible_in_tree() or button.disabled:return false
 var pressed:Array[int]=[0]
 var observer:=func():pressed[0]+=1
 button.pressed.connect(observer)
 var pt:=button.get_global_rect().get_center()
 for down in [true,false]:
  var event:=InputEventScreenTouch.new()
  event.index=0
  event.position=Vector2(3,3) if not down and end_outside else pt
  event.pressed=down
  root.push_input(event,true)
  await process_frame
 if is_instance_valid(button):button.pressed.disconnect(observer)
 return pressed[0]==1

func save_frame(name:String)->void:
 var folder:=OS.get_environment("ROXHISTORY_TEST_CAPTURE_DIR")
 if folder.is_empty():return
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(folder.path_join(name+".png"))

func test_lab(lab)->void:
 lab.set_process(false)
 var refill:=lab.find_child("DuelTestCharge",true,false) as Button
 var all:=lab.find_child("DuelTestAll",true,false) as Button
 var pause:=lab.find_child("DuelPause",true,false) as Button
 check("Named TEST42 charge and all controls are visible",is_instance_valid(refill) and refill.is_visible_in_tree() and is_instance_valid(all) and all.is_visible_in_tree())
 if not is_instance_valid(refill) or not is_instance_valid(all):return
 var badge_found:=false
 for label in lab.find_children("*","Label",true,false):
  if label.text=="TEST 42" and label.is_visible_in_tree():badge_found=true
 check("TEST 42 device badge",badge_found)
 check("Uncancelled selected field", await click_touch(lab.find_child("Select_forest",true,false) as Button) and lab.rules.enemy_id=="forest")
 for name in ["hangyeol","uram","saebom"]:
  check("True selectable touch "+name,await click_touch(lab.find_child("Select_"+name,true,false) as Button) and lab.rules.ally_id==name)
 check("Adult-boar touch selection",await click_touch(lab.find_child("Select_adult",true,false) as Button) and lab.rules.enemy_id=="adult")
 for i in range(240):
  if not lab.approach_active:break
  lab._process(1.0/60.0)
 check("Native pair settles out of the intentional approach input lock",not lab.approach_active)
 check("Actual solo charge touch",await click_touch(refill) and is_equal_approx(lab.rules.sp,3.0))
 check("Cancelled release outside 2SP does not cast", not (await click_touch(lab.skill_button,true)) and is_equal_approx(lab.rules.sp,3.0))
 var adult_before:int=lab.rules.hp[1]
 check("Actual solo 2SP touch reaches action",await click_touch(lab.skill_button) and lab.rules.sp<=1.001)
 for i in range(140):
  lab._process(1.0/60.0)
  if lab.rules.hp[1]<adult_before:break
 var released:=false
 if is_instance_valid(lab.shared_world):
  for item in lab.shared_world.projectile_releases:
   if item.motion=="skill":released=true
 print("Saebom adult first touch: actual heavy stone release=",released," enemy HP=",lab.rules.hp[1])
 check("Solo real ranged skill released the authored stone and deals exactly 27 to adult boar",released and adult_before-lab.rules.hp[1]==27)
 check("Han/forest selectors remain interactive after adult ranged test",await click_touch(lab.find_child("Select_hangyeol",true,false) as Button) and await click_touch(lab.find_child("Select_forest",true,false) as Button))
 for i in range(240):
  if not lab.approach_active:break
  lab._process(1.0/60.0)
 var hp_before:int=lab.rules.hp[1]
 check("Solo Han real 2SP touch starts",await click_touch(refill) and await click_touch(lab.skill_button) and lab.rules.sp<=1.001)
 for i in range(160):
  lab._process(1.0/60.0)
  if lab.rules.hp[1]<hp_before:break
 check("Solo Han/forest actual contact lowered opponent HP",lab.rules.hp[1]<hp_before)
 await save_frame("mobile-test35-solo-contact")
 check("Scoped TEST42 Uram and forest selectors remain live",await click_touch(lab.find_child("Select_uram",true,false) as Button) and await click_touch(lab.find_child("Select_forest",true,false) as Button))
 check("Exportable approved dust atlas and original thump available",lab.local_parry_sheets.size()==5 and is_instance_valid(lab.local_parry_thump))
 var early_checked:=false
 var guard_cast:=false
 var guard_contact:=false
 var before_guard:=0
 var actual_rear:=false
 for i in range(2100):
  if lab.motion[1]=="skill" and lab.age[1]>=.78 and lab.age[1]<1.25:
   var w=lab.shared_world
   actual_rear=minf(w.bone_world(1,"front_foot.R").y,w.bone_world(1,"front_foot.L").y)>.65
   if not early_checked:
    await click_touch(refill)
    await click_touch(lab.chain_button)
    check("Real Main touch during lift does not spend SP or arm guard",is_equal_approx(lab.rules.sp,3.) and lab.motion[0]!="chain")
    early_checked=true
  if lab.motion[1]=="skill" and lab.age[1]>=1.88 and not guard_cast:
   before_guard=lab.rules.hp[0]
   guard_cast=await click_touch(lab.chain_button)
  lab._process(1./120.)
  if lab.local_parry_clock>=0.:
   guard_contact=true
   break
 check("Main Uram viewport shows real lifted forelegs in the natural ram",actual_rear and early_checked)
 check("Main Uram true touch guard blocks the contact and plays approved scene",guard_cast and guard_contact and before_guard==lab.rules.hp[0])
 if guard_contact:
  for i in range(84):lab._process(1./120.)
  await save_frame("mobile-test42-uram-guard")
 check("Han and forest reselect after the Uram guard",await click_touch(lab.find_child("Select_hangyeol",true,false) as Button) and await click_touch(lab.find_child("Select_forest",true,false) as Button))
 check("Real 3v3 toggle touch",await click_touch(all) and is_instance_valid(lab.local_formation))
 var squad=lab.local_formation
 if not is_instance_valid(squad):return
 check("Three real portraits and 3 independent forest deer",squad.huds.size()==3 and squad.units.size()==6 and squad.units[3].id=="forest" and squad.units[4].id=="forest" and squad.units[5].id=="forest")
 var start:int=squad.units[3].hp+squad.units[4].hp+squad.units[5].hp
 check("Squad charge touches all active ally SP",await click_touch(refill) and squad.units[0].sp==3.0 and squad.units[1].sp==3.0 and squad.units[2].sp==3.0)
 check("Pause is a real phone touch and freezes squad",await click_touch(pause) and lab.paused)
 var hold:=float(squad.elapsed)
 for i in range(12):lab._process(1.0/60.0)
 check("Paused squad clock did not advance",float(squad.elapsed)==hold)
 check("Resume is a real phone touch",await click_touch(pause) and not lab.paused)
 check("Group Saebom 3SP touch consumes her SP only",await click_touch(squad.huds[2].chain_button) and squad.units[2].sp<.01 and squad.units[0].sp>=2.99 and squad.units[1].sp>=2.99)
 for i in range(480):
  lab._process(1.0/60.0)
  if squad.units[3].hp+squad.units[4].hp+squad.units[5].hp<start:break
 check("Live 3v3 combat actually lowered at least one separate deer HP",squad.units[3].hp+squad.units[4].hp+squad.units[5].hp<start)
 await save_frame("mobile-test35-formation-contact")
 check("Real return toggles off group and shows solo controls",await click_touch(all) and not is_instance_valid(lab.local_formation) and lab.skill_hud.is_visible_in_tree())

func run()->void:
 var app=load("res://scenes/main.tscn").instantiate()
 root.add_child(app)
 await process_frame
 app.application_active=true
 check("Isolated clean ordinary profile",app.model.start_new({},true))
 await app.enter_game()
 await process_frame
 if app.modal:app.close_modal()
 var flask:=app.find_child("DuelTestEntry",true,false) as Button
 check("Flask exists in the real Main play view without TEST42 CLI",is_instance_valid(flask) and not ("--duel-local-test=35" in OS.get_cmdline_user_args()))
 if is_instance_valid(flask):
  var previous_world_mode:int=app.world.process_mode
  check("Real Main flask responds to a phone touch",await click_touch(flask))
  var lab=app.parry_lab
  check("Main opened the 1v1 TEST42 profile with world safely paused",is_instance_valid(lab) and bool(lab.get("local_melee_polish")) and app.world.process_mode==Node.PROCESS_MODE_DISABLED)
  if is_instance_valid(lab):
   await test_lab(lab)
   check("Closing TEST42 by real touch restores the Main play world",await click_touch(lab.find_child("DuelClose",true,false) as Button) and not is_instance_valid(app.parry_lab) and app.screen=="play" and not app.modal and app.world.process_mode==previous_world_mode)
 app.queue_free()
 await process_frame
 print("TEST42 Mobile entry: ",checks," checks; ",failures," failures")
 quit(int(failures>0))
