extends SceneTree
const Placement=preload("res://scripts/hunt_start_placement.gd")
const Hunt=preload("res://scripts/deer_hunt_screen.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;push_error(label)
func _initialize():
	for a in 6:
		for b in 6:
			for c in 6:
				if a==b or a==c or b==c:continue
				var slots:Array=[a,b,c]
				var saved:=slots.duplicate()
				var end:=Placement.plan(Hunt.ALLY_CELLS,slots,Hunt.FORMATION_CENTER,Hunt.HUNTER_BATTLE_CENTER,Hunt.DEER_SLOT)
				var swapped:=Placement.plan(Hunt.ALLY_CELLS,[b,a,c],Hunt.FORMATION_CENTER,Hunt.HUNTER_BATTLE_CENTER,Hunt.DEER_SLOT)
				check(slots==saved,"planning does not rewrite assigned seats")
				check(end[0].is_equal_approx(swapped[1]) and end[1].is_equal_approx(swapped[0]),"actor exchange preserves cell-derived destinations")
				if 5 in slots:
					check(end[slots.find(5)].is_equal_approx(Hunt.HUNTER_BATTLE_CENTER+(Hunt.ALLY_CELLS[5]-Hunt.FORMATION_CENTER)*.62),"production front-seat weapon contact calibration is unchanged")
				for frame in 61:
					var t:=float(frame)/60
					var p:Array[Vector2]=[]
					for i in 3:p.append(Hunt.ALLY_CELLS[slots[i]].lerp(end[i],t))
					for i in 3:
						check(Rect2(330,170,330,250).has_point(p[i]),"formation stays clear of surrounding HUD")
						check(p[i].distance_to(Hunt.ENEMY_CELLS[4].lerp(Hunt.DEER_SLOT,t))>=49.9,"approach keeps prey body clearance")
						for j in range(i):check(p[i].distance_to(p[j])>56.0,"all120arrangements retain approach clearance")
				for i in 3:
					var previous:Vector2=end[i]
					for frame in 61:
						var beat:=sin(float(frame)/60*PI)
						var amount:=Placement.ordinary_lunge(end[i],Hunt.DEER_SLOT,42.0)
						var moved:=Placement.clear_motion(end[i],end[i]+end[i].direction_to(Hunt.DEER_SLOT)*amount*beat,end,i)
						for j in 3:
							if j!=i:check(moved.distance_to(end[j])>=49.9,"ordinary approach avoids standing allies")
						check(moved.distance_to(previous)<8.0,"clearance correction does not teleport during strike")
						previous=moved
	check(Placement.ordinary_lunge(Vector2(550,245),Hunt.DEER_SLOT,42)==0,"front slot never lunges inside prey")
	print("Production start placement: ",checks," checks, ",failures," failures")
	quit(0 if failures==0 else 1)
