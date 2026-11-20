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
	_step(lab,.48)
	_check(lab.motion[0]=="attack" and "han_basic" in lab.cues,"automatic basic plays confirmed clip")
	_step(lab,.83)
	_check(lab.rules.hp[1]<100,"automatic basic actually applies damage")
	_check("deer_hit" not in lab.cues,"basic does not emit skill hit cue")
	lab.reset_round()
	lab.rules.sp = 2.0
	lab._try_player("skill")
	_check(lab.rules.sp==0.0 and lab.motion[0]=="skill","ordinary skill spends exactly 2 SP")
	_step(lab,.20)
	_check(lab.field.scale.x>1.0,"ordinary skill camera focus")
	_step(lab,maxf(.05,float(lab.contact_at[0])-.20+.03))
	_check(lab.cues.count("deer_hit")==1,"ordinary skill emits defender hit cue once")
	_check(lab.rules.sp>0 and lab.rules.sp<1,"SP gained by elapsed time")
	lab.reset_round()
	lab.rules.sp = 3.0
	lab._try_player("chain")
	_check(lab.rules.sp==0.0 and lab.a.motion=="chain" and "han_chain" in lab.cues,"Han solo chain consumes 3 SP and plays confirmed clip")
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
	lab.queue_free()
	await create_timer(.10).timeout
	print("Hunt duel lab: %d checks, %d failures" % [checks,failed])
	quit(1 if failed>0 else 0)
