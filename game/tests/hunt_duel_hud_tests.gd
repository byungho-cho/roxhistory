extends SceneTree
var checks:=0
var failed:=0
var lab
var out:="user://"
func _initialize():call_deferred("run")
func check(ok:bool,why:String):
 checks+=1
 if not ok:failed+=1;push_error(why)
func step(seconds:float):
 for i in roundi(seconds*120):lab.advance(1.0/120)
func mouse_tap(button:Control):
 var at=button.get_global_rect().get_center()
 for down in [true,false]:
  var e=InputEventMouseButton.new();e.position=at;e.global_position=at;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down
  root.push_input(e,true);await process_frame
func touch_tap(button:Control):
 var at=button.get_global_rect().get_center()
 for down in [true,false]:
  var e=InputEventScreenTouch.new();e.position=at;e.index=0;e.pressed=down
  root.push_input(e,true);await process_frame
func shot(name:String):
 if DisplayServer.get_name()=="headless":return
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+name+".png")
func run():
 lab=load("res://scenes/hunt_duel_lab.tscn").instantiate();root.add_child(lab);lab.set_process(false);await process_frame
 var hud=lab.skill_hud
 check(lab.a.key=="hangyeol" and lab.b.key=="forest","default matchup")
 check(not hud.badge.visible and not hud.chain_button.visible,"1SP hides both")
 check(hud.badge.size==hud.portrait_button.size*.5,"ordinary half width and height")
 check(hud.chain_button.size.is_equal_approx(hud.portrait_button.size*.8),"chain 80 percent")
 await shot("01-initial-1sp")
 # Natural recharge: no testing SP cheat for 2→3 transition.
 step(lab.APPROACH_END+3.0)
 check(hud.normal_ready and not hud.chain_ready and hud.normal_entries==1,"natural 2SP normal entry once")
 step(.65)
 await shot("02-normal-2sp")
 var stable= hud.background.get_theme_stylebox("panel").bg_color
 var glow=hud.warm_glow.modulate.a
 step(2.35)
 check(hud.normal_ready and hud.chain_ready,"natural 3SP both")
 check(hud.normal_entries==1,"2 to 3 must not retrigger normal")
 check(hud.background.get_theme_stylebox("panel").bg_color==stable and is_equal_approx(hud.warm_glow.modulate.a,glow),"ordinary background stays fixed")
 var phase=hud.phase;step(.15)
 check(hud.phase!=phase,"only linked edge advances")
 await shot("03-both-3sp")
 # Do not force idle: tap the live automatic-combat state.
 lab._refresh()
 await mouse_tap(hud.chain_button)
 check(lab.motion[0]=="chain" and lab.rules.sp==0,"mouse linked consumes only3")
 check(lab.cues.count("han_chain")==1 and lab.cues.count("han_skill")==0,"linked no portrait input")
 check(not hud.normal_ready and not hud.chain_ready and not hud.badge.visible and not hud.electricity.visible,"activation refresh same frame")
 await shot("04-chain-activated")
 lab.reset_round();lab.advance(lab.APPROACH_END if lab.approach_active else 0.0);lab.rules.sp=3;lab._refresh(.6)
 await mouse_tap(hud.portrait_button)
 check(lab.motion[0]=="skill" and lab.rules.sp==1,"portrait at3 consumes only2")
 check(lab.cues.count("han_skill")==1 and lab.cues.count("han_chain")==0,"portrait no linked input")
 step(.2);check(lab.field.scale.x>1,"normal camera focus retained")
 await shot("05-normal-activated")
 lab.reset_round();lab.advance(lab.APPROACH_END if lab.approach_active else 0.0);lab.rules.sp=3;lab._refresh(.6)
 await touch_tap(hud.chain_button)
 check(lab.motion[0]=="chain" and lab.rules.sp==0,"touch linked independent")
 lab.reset_round();lab.advance(lab.APPROACH_END if lab.approach_active else 0.0);lab.rules.sp=2;lab._refresh(.6)
 await touch_tap(hud.portrait_button)
 check(lab.motion[0]=="skill" and lab.rules.sp==0,"touch portrait independent")
 # Loss of condition and all reset paths clear light clocks and icons.
 lab.reset_round();lab.advance(lab.APPROACH_END if lab.approach_active else 0.0);lab.rules.sp=3;lab._refresh(.6);lab.rules.sp=1;lab._refresh()
 check(not hud.badge.visible and not hud.chain_button.visible and hud.phase==0,"condition loss clears both")
 lab.rules.sp=3;lab._refresh(.6);lab.reset_round()
 check(lab.rules.sp==1 and lab.timer.text=="00:00" and not hud.badge.visible and not hud.chain_button.visible,"manual reset")
 for side in [0,1]:
  lab.reset_round();lab.advance(lab.APPROACH_END if lab.approach_active else 0.0);lab.rules.sp=3;lab._refresh(.6)
  lab.rules.damage(side,1000);lab._die(side);lab._refresh()
  check(not hud.badge.visible and not hud.chain_button.visible,"KO immediate clear")
  step(1.01)
  check(lab.rules.hp==[100,100] and lab.rules.sp<1.01 and lab.timer.text=="00:00" and not hud.badge.visible,"auto full-round reset")
 for ally in ["hangyeol","uram","saebom"]:
  for enemy in ["forest","adult"]:
   lab._select(ally,false);lab._select(enemy,true)
   check(lab.rules.sp==1 and not hud.chain_button.visible,"selection reset "+ally+enemy)
   lab.rules.sp=3;lab._refresh(.6)
   check(hud.badge_art.texture!=hud.chain_art.texture,"distinct character skill icons "+ally)
   lab.advance(lab.APPROACH_END if lab.approach_active else 0.0);lab._try_player("skill");check(lab.motion[0]=="skill","standalone ordinary "+ally+enemy)
   lab.reset_round();lab.advance(lab.APPROACH_END if lab.approach_active else 0.0);lab.rules.sp=3;lab._try_player("chain")
   check(lab.motion[0]=="chain","standalone linked "+ally+enemy)
   if ally!="hangyeol":step(.4);check(lab.rules.hp[1]==lab.rules.full_hp(1),"no fictitious support/parry damage")
 lab._select("hangyeol",false);lab._select("forest",true)
 await shot("06-reset")
 FileAccess.open(out+"ui-verification.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failed,"physical_fold":false,"viewport":str(root.size)},"  "))
 lab.queue_free();await process_frame;await process_frame
 print("Duel ready HUD: ",checks," checks, ",failed," failures")
 quit(0 if failed==0 else 1)
