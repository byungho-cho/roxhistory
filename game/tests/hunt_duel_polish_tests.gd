extends SceneTree
var lab
var checks:=0
var failures:=0
func _initialize():call_deferred("run")
func check(ok:bool,why:String):
 checks+=1
 if not ok:failures+=1;push_error(why)
func step(seconds:float):
 for i in roundi(seconds*120):lab.advance(1.0/120)
func snapshot()->Dictionary:
 return {"elapsed":lab.rules.elapsed,"sp":lab.rules.sp,"hp":lab.rules.hp.duplicate(),"revive":lab.rules.revive_at.duplicate(),"ages":lab.age.duplicate(),"motion":lab.motion.duplicate(),"contact":lab.contact_at.duplicate(),"next":lab.next_attack.duplicate(),"fx":lab.fx.duplicate(true),"visual":lab.visual_clock,"field_scale":lab.field.scale,"field_at":lab.field.position,"positions":[lab.a.preview.position,lab.b.preview.position],"hud_phase":lab.skill_hud.phase}
func tap(b:Control,touch:bool):
 for down in [true,false]:
  if touch:
   var e:=InputEventScreenTouch.new();e.index=0;e.pressed=down;e.position=b.get_global_rect().get_center();root.push_input(e,true)
  else:
   var e:=InputEventMouseButton.new();e.pressed=down;e.button_index=MOUSE_BUTTON_LEFT;e.position=b.get_global_rect().get_center();e.global_position=e.position;root.push_input(e,true)
  await process_frame
func run():
 lab=load("res://scenes/hunt_duel_lab.tscn").instantiate();root.add_child(lab);lab.set_process(false);await process_frame
 var hud=lab.skill_hud
 for touch in [false,true]:
  for sp in [2.0,3.0]:
   for at in [.08,.22]:
    lab.reset_round();lab.advance(lab.APPROACH_END);lab._act(0,"attack");lab.advance(at);lab.rules.sp=sp;lab._refresh()
    check(not lab.skill_button.disabled,"portrait enabled during live auto approach")
    var place=lab.a.preview.position;var before=lab.rules.sp
    await tap(lab.skill_button,touch)
    check(lab.motion[0]=="skill" and is_equal_approx(lab.rules.sp,before-2),"ordinary interrupts automatic attack at2/3 SP")
    check(lab.cues.count("han_skill")==0 and lab.cues.count("han_chain")==0,"portrait emits only ordinary")
    check(lab.a.preview.position.distance_to(place)<.01,"no teleport when interrupting movement")
    var contact=lab.contact_at[0];await tap(lab.skill_button,touch)
    check(lab.cues.count("han_skill")==0 and lab.contact_at[0]==contact,"double tap no repeated spend or contact")
  lab.reset_round();lab.advance(lab.APPROACH_END);lab._act(0,"attack");lab.advance(.1);lab.rules.sp=3;lab._refresh()
  await tap(lab.chain_button,touch)
  check(lab.motion[0]=="chain" and lab.rules.sp==0,"upper chain interrupts and spends3 only")
  check(lab.cues.count("han_chain")==0 and lab.cues.count("han_skill")==0,"upper chain not portrait")
 # The interrupted auto attack must not land at its old contact timestamp.
 lab.reset_round();lab.advance(lab.APPROACH_END);lab._act(0,"attack");var old_contact=lab.contact_at[0];lab.advance(.08);lab.rules.sp=2;lab._refresh();lab._try_player("skill")
 var hp=lab.rules.hp[1];lab.advance(old_contact-.08+.001)
 check(lab.rules.hp[1]==hp,"cancelled auto contact cannot damage enemy")
 step(lab.contact_at[0]-lab.age[0]+.02)
 check(lab.cues.count("deer_hit")==1,"ordinary hit cue once after interruption")
 # Pause during movement/casting freezes every simulation clock and resumes.
 for state in ["attack","skill"]:
  lab.reset_round();lab.advance(lab.APPROACH_END);lab._act(0,state);lab.advance(.12)
  await tap(lab.pause_button,true);check(lab.paused,"pause touch")
  var frozen=snapshot();lab.advance(8)
  check(snapshot()==frozen,"pause freezes all battle/SP/FX/camera state")
  var cues=lab.cues.size();await tap(lab.skill_button,true)
  check(lab.cues.size()==cues,"skill cannot fire while paused")
  await tap(lab.pause_button,false);lab.advance(.1)
  check(not lab.paused and lab.rules.elapsed>frozen.elapsed,"resume same state")
 # Exact one-second death delay; pause excludes its elapsed wall time.
 for side in [0,1]:
  lab.reset_round();lab.advance(lab.APPROACH_END);lab.rules.damage(side,1000);lab._die(side);lab._refresh()
  lab.advance(.4);lab.toggle_pause();var frozen=snapshot();lab.advance(10)
  check(snapshot()==frozen and lab.rules.hp[side]==0,"KO reset countdown paused")
  lab.toggle_pause();lab.advance(.599)
  check(lab.rules.hp[side]==0,"not reset before0.999s")
  lab.advance(.001)
  check(lab.rules.elapsed==0 and lab.rules.hp==[100,100] and lab.rules.sp==1,"both HP/SP/timer reset at1.000s")
  check(lab.a.preview.position.is_equal_approx(lab._duel_anchor(0,lab.START_GAP)) and lab.b.preview.position.is_equal_approx(lab._duel_anchor(1,lab.START_GAP)),"both ground positions reset together")
 # A real reset button remains operable while paused and preserves pause.
 lab.rules.sp=3;lab._refresh();lab.toggle_pause()
 var reset=lab.arena.get_node("DuelReset")
 await tap(reset,true)
 check(lab.paused and lab.rules.sp==1 and lab.rules.elapsed==0,"manual reset active during pause")
 check(not hud.badge.visible and not hud.chain_button.visible,"reset clears readiness")
 lab.toggle_pause();step(lab.APPROACH_END+3)
 check(absf(lab.rules.sp-2.0)<.003,"3s SP cadence retained")
 check(lab.timer.get_theme_color("font_color")==Color("fff2d6") and lab.timer.get_theme_font_size("font_size")==13,"small ivory timer")
 check(hud.sp_label.get_theme_font_size("font_size")==13,"SP legibility")
 # Uram keeps its existing individual shield motion.
 lab._select("uram",false);lab.rules.sp=3;lab._try_player("chain")
 check(lab.a.clip_for("chain")=="parry" and lab.motion[0]=="chain","Uram individual parry preserved")
 print("Duel polish: ",checks," checks, ",failures," failures")
 FileAccess.open("user://duel278-tests.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures}))
 lab.queue_free();await process_frame;await process_frame;quit(0 if failures==0 else 1)
