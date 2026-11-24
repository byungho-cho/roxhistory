extends SceneTree

const Rules := preload("res://scripts/deer_hunt_rules.gd")
const Rally := preload("res://scripts/saebom_rally_cloud.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value:bool, description:String) -> void:
	if not value:failures+=1
	print(("PASS " if value else "FAIL ")+description)

func run() -> void:
	var lesson := Rules.new()
	lesson.han_damage_multiplier = Rules.STAGE_1_1_HAN_DAMAGE_MULTIPLIER
	lesson.queue_attack(Rally.ORDINARY_BASE,0)
	lesson.resolve_attack()
	check(lesson.deer_hp==98,"1-1 Han basic resolves at twice its original 1")
	lesson.queue_attack(Rules.SKILLS.thrust.damage,0)
	lesson.resolve_attack()
	check(lesson.deer_hp==82,"1-1 Han 2SP resolves at twice its original 8")
	lesson.resolve_independent_prey_basic(0)
	check(lesson.party_hp[0]==32,"1-1 independent deer basic remains 2, not 4")
	lesson.attacker=0
	lesson.pending_counter=true
	lesson.resolve_attack()
	check(lesson.party_hp[0]==30,"ordinary prey counter also remains 2 when Han multiplier is active")
	lesson.queue_attack(7,1)
	lesson.resolve_attack()
	check(lesson.deer_hp==75,"other allies do not inherit Han's multiplier")
	lesson.damage_deer(5)
	check(lesson.deer_hp==70,"standalone direct effects do not inherit Han's multiplier")
	var ordinary := Rules.new()
	ordinary.queue_attack(Rally.ORDINARY_BASE,0)
	ordinary.resolve_attack()
	ordinary.queue_attack(Rules.SKILLS.thrust.damage,0)
	ordinary.resolve_attack()
	check(ordinary.deer_hp==91,"normal route has no tutorial multiplier")
	quit(failures)