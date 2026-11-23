extends SceneTree
const LAB=preload("res://scenes/hunt_duel_lab.tscn")
const Accent=preload("res://scripts/hunt_ordinary_hit_accent.gd")
var failed:=0
var checks:=0

func _initialize()->void:
	call_deferred("run")

func ck(ok:bool, msg:String)->void:
	checks+=1
	print("SAEBOM_FLINCH ",ok," ",msg)
	if not ok:failed+=1

func run()->void:
	var l=LAB.instantiate()
	l.show_final_test35=true
	root.add_child(l)
	l.set_process(false)
	l._select("saebom",false)
	var w=l.shared_world
	var hit_at:=-1.0
	var draw_at:=-1.0
	for n in 555:
		l.advance(1./120.)
		if is_equal_approx(hit_at,-1.0) and l.rules.hp[0]<100:
			hit_at=l.visual_clock
			ck(l.rules.hp[0]==87 and w.saebom_melee_pending and not w.bom_close and not l.a.preview.has_meta("saebom_melee_blade"),"natural deer hit still subtracts 13 HP with no knife on its hit frame")
			ck(l.ordinary_resting_hit[0],"preserves resting head-only receiver substitution")
		if w.bom_close and draw_at<0.0:
			draw_at=l.visual_clock
			ck(l.a.preview.has_meta("saebom_melee_blade") and l.motion[0]!="hit" and hit_at>0.0 and draw_at-hit_at>=Accent.END,"knife first appears on a natural safe frame after hit reaction")
	ck(draw_at>hit_at and hit_at>0.0 and w.bom_close,"same stock encounter eventually commits melee")
	ck(w.projectile_releases.size()==1,"original ranged opening still releases exactly once")
	l.reset_round()
	ck(not w.bom_close and not w.saebom_melee_pending,"fresh encounter clears pending and committed mode")
	l.next_attack=[999.,999.]
	for n in 200:l.advance(1./120.)
	l.next_attack=[999.,999.]
	w.bodies[1].position=w.bodies[0].position+w.direction*1.45
	l._act(1,"attack")
	l._render_actors()
	ck(w.saebom_melee_pending and not w.bom_close,"pending genuine threat defers drawing before damage is known")
	l.age[1]=l.b.duration*.71
	l._render_actors()
	ck(w.bom_close and l.rules.hp[0]==100 and l.a.preview.has_meta("saebom_melee_blade"),"miss with no HP drop draws as soon as the contact window closes")
	l._toggle_local_formation()
	var q=l.local_formation
	q.configure_saebom_distance_drill("far")
	var u:Dictionary=q.units[2]
	var deer:Dictionary=q.units[3]
	deer.feet=u.feet+Vector2(60.,0.)
	q._begin(3,"attack",2)
	q._draw_pose(0.)
	ck(u.saebom_melee_pending and not u.bom_close,"squad real incoming target queues draw without changing equipped mode")
	deer.contact=-1.
	q._damage(3,2,11,"attack")
	ck(u.hp==89 and not u.bom_close and not u.actor.preview.has_meta("saebom_melee_blade"),"squad hit applies original HP without a weapon switch")
	deer.feet=u.feet+Vector2(102.,0.)
	q._play(u,"idle")
	q.elapsed+=.18
	q._draw_pose(0.)
	ck(not u.bom_close,"short post-hit hold survives early neutral and same-target retreat")
	q.elapsed+=.04
	q._draw_pose(0.)
	ck(u.bom_close and u.actor.preview.has_meta("saebom_melee_blade"),"retreat does not discard pending one-way switch")
	u.sp=3.
	q._request("skill",2)
	ck(u.bom_near_skill and u.actor.preview.has_meta("saebom_melee_blade") and q.cast_notices[2].icon==l.MeleeKnifeIcon,"next cast commits knife prop, icon and move atomically")
	q._damage(3,2,1,"attack")
	q._draw_pose(0.)
	ck(u.bom_close and u.bom_near_skill and u.actor.preview.has_meta("saebom_melee_blade"),"already-melee hit neither drops blade nor cancels committed cast")
	q.configure_saebom_distance_drill("far")
	ck(not u.bom_close and not u.saebom_melee_pending,"far preset clears mode and pending trigger")
	l.free()
	print("SAEBOM_FLINCH ",checks-failed,"/",checks)
	quit(failed)
