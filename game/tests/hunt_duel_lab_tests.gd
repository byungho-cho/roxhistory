extends SceneTree

const Lab = preload("res://scripts/hunt_duel_lab.gd")
var checks := 0
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failed += 1
		printerr("FAIL: "+label)

func _step(lab: Control, seconds: float) -> void:
	for i in roundi(seconds*120):
		lab.advance(1.0/120.0)

func _run() -> void:
	var clock := Lab.Rules.new()
	clock.advance(2.999)
	_check(not clock.afford(2),"ordinary skill unavailable before 3 seconds")
	clock.advance(.001)
	_check(clock.afford(2) and not clock.afford(3),"ordinary unlocks at 3s")
	clock.advance(3.0)
	_check(clock.afford(3),"solo chain unlocks at 6s")
	var lab := Lab.new()
	root.add_child(lab)
	lab.set_process(false)
	_check(lab.a.key=="hangyeol" and lab.b.key=="forest","default matchup")
	_check(lab.rules.sp==1.0 and lab.timer.text=="00:00","initial 1 SP and timer")
	_check(lab.chain_button.disabled and lab.skill_button.disabled,"both skills are disabled at initial 1 SP")
	var left_start := lab.a.preview.position
	var right_start := lab.b.preview.position
	_check(lab.approach_active and lab.motion==["run","run"],"both open with the native run, not a skill")
	_step(lab,.40)
	var moved_ally := left_start.distance_to(lab.a.preview.position)
	var moved_enemy := right_start.distance_to(lab.b.preview.position)
	_check(moved_ally > 0.0 and is_equal_approx(moved_ally,moved_enemy),"both cover half the approach at each step")
	_check(lab.rules.elapsed==0.0 and lab.rules.hp==[100,100] and lab.rules.sp==1.0 and lab.cues.is_empty(),"approach is presentation only")
	lab.rules.sp=3.0
	lab._try_player("chain")
	_check(lab.rules.sp==3.0 and lab.cues.is_empty(),"cannot cast during approach")
	lab.rules.sp=1.0
	_step(lab,.65)
	_check(not lab.approach_active and lab.motion==["idle","idle"],"settle at attack distance before either attack begins")
	var left_held := lab.a.preview.position
	var right_held := lab.b.preview.position
	_check(is_equal_approx(left_held.distance_to(right_held),Lab.ENGAGE_GAP),"final gap remains inside basic reach without point blank overlap")
	_step(lab,.50)
	_check(lab.motion==["attack","attack"] and lab.rules.hp==[100,100],"deer is already winding up during Han's first attack, before contact")
	_check(lab.cues.is_empty(),"basic attack sounds wait for contact")
	_step(lab,.23)
	_check(lab.rules.hp==[100,89] and lab.cues.count("han_basic")==1,"Han contact triggers exactly one cue and one damage event")
	_check(lab.motion[1]=="attack","Han contact does not cancel the committed deer attack")
	_step(lab,.27)
	_check(lab.rules.hp==[87,89] and lab.cues.count("deer_basic")==1,"deer lands independently during Han recovery")
	_check(lab.motion[0]=="attack","Han is still finishing his motion when the deer lands")
	lab.toggle_pause()
	var frozen: float=lab.rules.elapsed
	_step(lab,.35)
	_check(lab.rules.elapsed==frozen,"pause still freezes the simulation")
	lab.toggle_pause()
	_check(lab.a.preview.position.distance_to(left_held)<=Lab.BASIC_MAX_TRAVEL+.001 and lab.b.preview.position.is_equal_approx(right_held),"basic attacks never move their ground anchors")
	_check("deer_hit" not in lab.cues,"basic does not emit skill hit cue")
	_step(lab,1.0)
	_check(lab.rules.hp==[87,89],"no rapid automatic exchange during the recovery interval")
	lab.reset_round()
	_step(lab,1.05)
	lab.rules.sp = 2.0
	lab._try_player("skill")
	_check(lab.rules.sp==0.0 and lab.motion[0]=="skill","ordinary skill spends exactly 2 SP")
	_step(lab,.20)
	_check(lab.field.scale.x>1.0,"ordinary skill camera focus")
	_step(lab,maxf(.05,float(lab.contact_at[0])-.20+.03))
	_check(lab.cues.count("deer_hit")==1,"ordinary skill emits defender hit cue once")
	_check(lab.rules.sp>0 and lab.rules.sp<1,"SP gained by elapsed time")
	lab.reset_round()
	_step(lab,1.05)
	lab.rules.sp = 3.0
	lab._try_player("chain")
	_check(lab.rules.sp==0.0 and lab.a.motion=="chain" and "han_chain" not in lab.cues,"Han solo chain consumes 3 SP and plays confirmed clip")
	lab._select("saebom",false)
	lab.rules.sp = 3.0
	lab._try_player("chain")
	_step(lab,.4)
	_check(lab.rules.hp[1]==100 and lab.a.motion=="chain" and "bom_chain" in lab.cues,"Saebom support preview creates no damage")
	lab._select("uram",false)
	lab._select("adult",true)
	_check(lab.rules.hp==[100,180] and lab.rules.sp==1.0,"selector resets HP and SP")
	lab.rules.sp = 3.0
	lab._try_player("chain")
	_step(lab,.4)
	_check(lab.rules.hp[1]==180 and lab.a.motion=="chain" and "uram_chain" in lab.cues,"Uram shield preview creates no fictitious damage")
	lab.reset_round()
	lab.rules.elapsed = 61.25
	lab._refresh()
	_check(lab.timer.text=="01:01","timer uses elapsed MM:SS")
	lab.rules.hp[1] = 1
	_step(lab,1.1)
	_check(lab.rules.hp[1]==0 and lab.cues.count("enemy_death")==1,"enemy KO one cue")
	_step(lab,1.0)
	_check(lab.rules.hp==[100,180] and lab.rules.sp<1.4 and lab.timer.text=="00:00","enemy KO starts full new round")
	lab.rules.elapsed = 6
	lab.rules.hp[0] = 1
	lab._act(1,"attack")
	_step(lab,.9)
	_check(lab.rules.hp[0]==0 and lab.cues.count("ally_death")==1,"ally KO one cue")
	_step(lab,1.05)
	_check(lab.rules.hp==[100,180] and lab.rules.sp<1.6 and lab.timer.text=="00:00","ally KO starts full new round")
	lab.reset_round()
	_check(lab.a.key=="uram" and lab.b.key=="adult" and lab.rules.elapsed==0.0,"manual reset keeps selections")
	lab._select("hangyeol",false)
	lab._select("forest",true)
	lab.advance(1.14)
	_check(not lab.approach_active and is_equal_approx(lab.rules.elapsed,.10),"long frame carries only time after approach into the combat clock")
	lab.rules.hp[1] = 1
	_step(lab,.65)
	_check(lab.rules.hp[1]==0,"default duel still allows a real KO")
	_step(lab,1.0)
	_check(lab.approach_active and lab.rules.hp==[100,100] and lab.rules.sp==1.0,"revival resets both and replays the non-damaging approach")
	lab.queue_free()
	await create_timer(.10).timeout
	print("Hunt duel lab: %d checks, %d failures" % [checks,failed])
	quit(1 if failed>0 else 0)
