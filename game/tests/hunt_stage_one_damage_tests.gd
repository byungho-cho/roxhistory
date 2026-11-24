extends SceneTree

const Rules := preload("res://scripts/deer_hunt_rules.gd")
const Rally := preload("res://scripts/saebom_rally_cloud.gd")
const Actions := preload("res://scripts/hunt_production_frontline_actions.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value:bool, description:String) -> void:
	if not value:failures+=1
	print(("PASS " if value else "FAIL ")+description)

func run() -> void:
	var lesson := Rules.new()
	lesson.han_ordinary_damage = Rally.SQUAD_BASE
	lesson.queue_attack(lesson.han_ordinary_damage,0)
	lesson.resolve_attack()
	check(lesson.deer_hp==86,"1-1 Han basic resolves at the normal Chapter One 14")
	lesson.queue_attack(Actions.HAN_STORY_2SP_DAMAGE,0)
	lesson.resolve_attack()
	check(lesson.deer_hp==59,"1-1 Han 2SP resolves at the normal Chapter One 27")
	lesson.resolve_independent_prey_basic(0)
	check(lesson.party_hp[0]==32,"1-1 independent deer basic remains 2, not 4")
	lesson.attacker=0
	lesson.pending_counter=true
	lesson.resolve_attack()
	check(lesson.party_hp[0]==30,"ordinary prey counter remains 2")
	lesson.queue_attack(7,1)
	lesson.resolve_attack()
	check(lesson.deer_hp==52,"other allies do not inherit Han's ordinary tuning")
	lesson.damage_deer(5)
	check(lesson.deer_hp==47,"standalone direct effects are unchanged")
	var ordinary := Rules.new()
	ordinary.queue_attack(Rally.ORDINARY_BASE,0)
	ordinary.resolve_attack()
	ordinary.queue_attack(Rules.SKILLS.thrust.damage,0)
	ordinary.resolve_attack()
	check(ordinary.deer_hp==91,"other legacy route values are unchanged")
	quit(failures)