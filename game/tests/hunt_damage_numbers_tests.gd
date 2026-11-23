extends SceneTree

const Squad = preload("res://scripts/hunt_duel_local_squad.gd")
const Lab = preload("res://scenes/hunt_duel_lab.tscn")
var checks := 0
var fails := 0

func _initialize() -> void:
	call_deferred("run")

func ck(ok: bool, message: String) -> void:
	checks += 1
	print("DAMAGE_NUMBERS ", "PASS " if ok else "FAIL ", message)
	if not ok:fails += 1

func run() -> void:
	root.size = Vector2i(960,540)
	var lab := Lab.instantiate()
	lab.show_final_test35 = true
	root.add_child(lab)
	lab.set_process(false)
	lab.next_attack = [999.0,999.0]
	for frame in 150:lab.advance(1.0/120.0)
	lab.next_attack = [999.0,999.0]
	lab._act(0,"attack")
	for frame in 100:lab.advance(1.0/120.0)
	var duel: Array = lab.damage_numbers.entries
	ck(lab.rules.hp[1]<100 and duel.size()==1 and duel[0].victim==1 and duel[0].loss==100-lab.rules.hp[1],"real shared-world hit records one exact enemy HP delta")
	var old:int=lab.rules.hp[0]
	lab.rules.damage(0,0)
	lab.rules.damage(0,900)
	ck(duel.size()==2 and duel[1].victim==0 and duel[1].ally and duel[1].loss==old,"zero skipped; lethal incoming displays clamped ally delta")
	ck(duel.size()==2 and duel[0].anchor.distance_to(duel[1].anchor)>35.0,"overheads use each victim, not the hit spark")
	lab.reset_round()
	ck(duel.is_empty(),"round reset removes transient entries")
	lab.free()

	var squad := Squad.new()
	root.add_child(squad)
	squad.setup()
	squad.local_melee_polish=true
	for i in squad.units.size():
		squad.units[i].next=9999.
		squad.units[i].feet=Vector2(250.+80.*i,260.+float(i%2)*24.)
	squad.units[5].hp=4
	squad._damage(3,0,7,"attack")
	squad.units[1].sp=3.0
	squad._request("chain",1)
	squad._resolve(1)
	for frame in 75:
		squad.elapsed+=1./120.
		squad._advance_uram_ordinary_wave()
	var entries: Array = squad.damage_numbers.entries
	var enemies := entries.filter(func(e):return e.victim>=3)
	ck(entries.size()==4 and enemies.size()==3,"real Uram field resolution records all three enemies and distinct incoming ally")
	ck(enemies.size()==3 and enemies[0].born==enemies[1].born and enemies[1].born==enemies[2].born,"three enemy numbers born on the same frame")
	ck(enemies.size()==3 and enemies[0].victim!=enemies[1].victim and enemies[1].victim!=enemies[2].victim and enemies[0].victim!=enemies[2].victim,"separate live labels attach to all three victims")
	var tail := enemies.filter(func(e):return e.victim==5)
	ck(tail.size()==1 and tail[0].loss==4,"lethal excess from AoE displays remaining four HP, not nominal damage")
	squad._damage(3,1,0,"attack")
	squad._damage(0,5,55,"skill")
	squad._miss(0,3,"attack")
	squad.saebom_distance_drill="far"
	squad._damage(1,3,55,"skill")
	ck(entries.size()==4,"zero, miss, dead, and a visual-only drill hit add no label")
	squad.damage_numbers._process(.12)
	squad._damage(3,0,2,"attack")
	ck(entries.size()==5 and entries.back().victim==0 and entries.back().loss==2 and entries.back().born>entries[0].born and entries.back().lane>0,"legitimate near-simultaneous damage to the same victim stays separate")
	squad.damage_numbers._process(.70)
	ck(entries.is_empty(),"entries expire and leave no persistent overlay")
	var anchor_hp := int(squad.units[1].hp)
	squad.saebom_distance_drill=""
	squad._begin(1,"chain",3)
	squad.units[1].guard_source=3
	squad.units[1].age=.2
	squad._damage(3,1,23,"attack")
	ck(int(squad.units[1].hp)==anchor_hp and squad.damage_numbers.entries.filter(func(e):return e.victim==1).is_empty(),"true parry creates no damage number over the defender")
	squad.free()

	var field := Squad.new()
	root.add_child(field)
	field.setup()
	field.local_melee_polish=true
	field.units[0].feet=Vector2(420,273)
	field.units[3].feet=Vector2(465,272)
	field._begin(0,"chain",3)
	field._resolve(0)
	var han: Array = field.damage_numbers.entries.duplicate()
	ck(han.size()==3 and han[0].born==han[1].born and han[1].born==han[2].born,"Han 3SP overheads begin together on existing spear ground impact")
	field.damage_numbers.clear()
	field._begin(2,"chain",3)
	field._resolve(2)
	var cloud: Array = field.damage_numbers.entries
	ck(cloud.size()==3 and cloud[0].born==cloud[1].born and cloud[1].born==cloud[2].born,"Saebom direct cloud HP deduction also reports all enemies together")
	field.free()

	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.hunt_stage = 0
	app.show_screen("hunt_select")
	await app.prepare_selected_hunt()
	await process_frame
	var hunt = app.hunt
	if not is_instance_valid(hunt):
		ck(false,"ordinary CH1 Main scene opened")
		quit(fails)
		return
	hunt.set_process(false)
	hunt.arrival_finished=true
	hunt.transition_elapsed=-1.0
	hunt.assigned_cells.assign([0,5,3])
	hunt.start_combat()
	hunt.advance_transition(hunt.TRANSITION_SECONDS)
	hunt.update_actors(.05)
	var campaign: Array = hunt.damage_numbers.entries
	hunt.rules.pending_counter=true
	hunt.rules.attacker=1
	hunt.rules.resolve_attack()
	hunt.rules.pending_damage=18
	hunt.rules.resolve_uram_shield_counter(true)
	ck(campaign.size()==2 and campaign[0].victim==1 and campaign[0].loss==2 and campaign[1].victim==3 and campaign[1].loss==18,"native CH1 ordinary rules display one number for each actor without legacy duplicate")
	hunt.rules.damage_deer(0)
	ck(campaign.size()==2,"native CH1 HP-unchanged impact does not add label")
	print("DAMAGE_NUMBERS ",checks-fails,"/",checks)
	quit(fails)
