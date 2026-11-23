extends SceneTree

const LAB := preload("res://scenes/hunt_duel_lab.tscn")
const Knife := preload("res://scripts/duel_saebom_stone_knife.gd")
var checks := 0
var failures := 0

func _initialize()->void:
	call_deferred("run")

func ck(ok:bool, label:String)->void:
	checks+=1
	print("SAEBOM_MODE ",ok," ",label)
	if not ok:failures+=1

func run()->void:
	var lab=LAB.instantiate()
	lab.show_final_test35=true
	root.add_child(lab)
	lab.set_process(false)
	lab._select("saebom",false)
	lab.next_attack=[999.,999.]
	for n in 200:lab.advance(1./120.)
	lab.next_attack=[999.,999.]
	var world=lab.shared_world
	world.bodies[1].position=world.bodies[0].position+world.direction*2.4
	lab._render_actors()
	lab.rules.sp=3.
	lab._try_player("skill")
	ck(not world.bom_near_skill and not lab.a.preview.has_meta("saebom_melee_blade"),"shared 1v1 starts ranged cast with sling and ranged badge")
	world.bodies[1].position=world.bodies[0].position+world.direction*1.37
	lab._render_actors()
	ck(not world.bom_near_skill and not world.bom_close and not lab.a.preview.has_meta("saebom_melee_blade"),"ranged 2SP commitment cannot flip during a deer close step")
	lab._react(0,"idle")
	lab._render_actors()
	ck(world.bom_close and lab.a.preview.has_meta("saebom_melee_blade"),"next neutral frame makes knife and range mode agree")
	world.bodies[1].position=world.bodies[0].position+world.direction*2.5
	lab.rules.sp=3.
	lab._try_player("skill")
	ck(world.bom_near_skill and lab.a.preview.has_meta("saebom_melee_blade") and lab.cast_notice.icon==lab.MeleeKnifeIcon,"deer retreat cannot change knife, 2SP resolver, or committed cast badge")
	var release_count:int=world.projectile_releases.size()
	for n in 25:lab.advance(1./120.)
	ck(world.projectile_releases.size()==release_count,"melee never releases a ranged projectile")
	lab.reset_round()
	ck(not world.bom_close,"1v1 restart clears sticky mode")

	lab._toggle_local_formation()
	var q=lab.local_formation
	q.configure_saebom_distance_drill("far")
	var u:Dictionary=q.units[2]
	for unit in q.units:unit.next=9999.
	u.sp=3.
	q._request("skill",2)
	ck(not u.bom_near_skill and not u.actor.preview.has_meta("saebom_melee_blade"),"far drill has genuine ranged 2SP and no knife")
	var deer:Dictionary=q.units[3]
	deer.feet=u.feet+Vector2(58.,0.)
	q._draw_pose(0.)
	ck(not u.bom_near_skill and not u.bom_close,"squad ranged cast keeps mode across close crossing")
	q._play(u,"idle")
	q._draw_pose(0.)
	ck(u.bom_close and u.actor.preview.has_meta("saebom_melee_blade"),"squad equips knife and updates readiness after cast returns")
	deer.feet=u.feet+Vector2(142.,0.)
	for n in 120:
		q.units[1].next=9999.
		deer.next=9999.
		q.tick(1./120.,false)
	ck(u.bom_close and u.feet.distance_to(deer.feet)<=67.,"sustained retreat keeps melee and native movement re-enters reach")
	u.sp=3.
	q._request("skill",2)
	ck(u.bom_near_skill and u.actor.preview.has_meta("saebom_melee_blade") and q.cast_notices[2].icon==lab.MeleeKnifeIcon,"squad cast badge, draw and melee resolver share selected mode")
	var hp:int=deer.hp
	var old_flights:int=q.missiles.size()
	for i in Knife.contacts.size():
		u.contact=-1.
		q._resolve(2)
		ck(int(deer.hp)==(hp-[5,10,16,27][i]),"squad knife beat %d has approved damage semantics"%(i+1))
	ck(q.missiles.size()==old_flights,"knife 2SP does not add a sling stone")
	deer.hp=0
	q.saebom_distance_drill="" # Exercise normal squad retargeting, not the drill's single-deer rule.
	q.units[4].hp=100
	q.units[4].feet=u.feet+Vector2(105.,-15.)
	q._play(u,"idle")
	q._draw_pose(0.)
	ck(q._target(2)==4 and u.bom_close and u.actor.preview.has_meta("saebom_melee_blade"),"new living target does not reset melee")
	q.configure_saebom_distance_drill("far")
	ck(not u.bom_close and not u.actor.preview.has_meta("saebom_melee_blade"),"explicit far preset clears sticky mode")
	lab.free()
	print("SAEBOM_MODE ",checks-failures,"/",checks)
	quit(failures)
