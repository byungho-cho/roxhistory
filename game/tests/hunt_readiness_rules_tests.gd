extends SceneTree
const Rules=preload("res://scripts/deer_hunt_rules.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func _initialize():
 var solo:=Rules.new()
 solo.party_hp=[34,0,0];solo.skills_enabled=false
 solo.charges=[3.,3.,3.]
 check(not solo.can_use("thrust") and not solo.can_reserve_manual(0,2) and not solo.can_use_frontline_skill(0,2),"solo rejects ordinary and chain skills")
 solo.charges=[0.,0.,0.];solo.set_auto(true)
 check(solo.auto_enabled and solo.reserved_skill=="","AUTO remains enabled without reserving a skill")
 var elapsed:=0.
 var hits:=0
 var counters:=0
 while solo.outcome.is_empty() and elapsed<1000.:
  var action:=solo.advance(.05)
  elapsed+=.05
  if action=="auto_thrust":
   check(solo.attacker==0,"only Han schedules attacks")
   hits+=1;solo.resolve_attack()
  elif action=="counter":
   check(solo.attacker==0,"only Han receives existing counters")
   counters+=1;solo.resolve_attack()
  check(solo.charges==[0.,0.,0.],"solo does not accumulate skill SP")
 check(solo.outcome=="loss" and solo.deer_hp>0,"unmodified current balance reaches natural defeat")
 print("SOLO_NATURAL_OUTCOME time=",elapsed," attacks=",hits," counters=",counters," prey_hp=",solo.deer_hp," party=",solo.party_hp)
 var legacy:=Rules.new();legacy.charges=[3.,3.,3.]
 check(legacy.skills_enabled and legacy.can_use("thrust") and legacy.party_hp==[34,33,33],"other chapters retain default roster and skill rules")
 print("Readiness solo rules: ",checks," checks, ",failures," failures")
 quit(0 if failures==0 else 1)
