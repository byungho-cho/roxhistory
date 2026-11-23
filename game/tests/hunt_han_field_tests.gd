extends SceneTree
const Squad = preload("res://scripts/hunt_duel_local_squad.gd")
var failed:=0
var old:=false
func _initialize()->void:call_deferred("run")
func check(ok:bool, what:String)->void:
 print("HAN SQUAD ",ok," ",what)
 if not ok:failed+=1
func scenario(primary_distance:float, cost:float, dead_other:bool=false, lost_primary:bool=false)->Array:
 var s:=Squad.new()
 root.add_child(s)
 s.setup()
 s.set_input_paused(false)
 s.units[0].feet=Vector2(365,235)
 s.units[3].feet=Vector2(365+primary_distance,235)
 s.units[4].feet=Vector2(725,337)
 s.units[5].feet=Vector2(763,197)
 if dead_other:s.units[5].hp=0
 s.units[0].sp=cost
 s._request("chain" if cost==3.0 else "skill",0)
 var beat:float=s.units[0].contact
 check(beat>0 and s.units[0].sp==0.0,"active cast starts same contact beat")
 if lost_primary:s.units[3].hp=0
 s.units[0].contact=-1.0
 s._resolve(0)
 var values:=[s.units[3].hp,s.units[4].hp,s.units[5].hp,s.hits.size()]
 print("RESULT ",primary_distance," cost=",cost," hp + events=",values," contact=",beat)
 s.free()
 return values
func run()->void:
 old=OS.get_cmdline_user_args().has("--stock")
 check(scenario(55,3)==[62,77,77,3],"near primary and distant back lanes")
 check(scenario(220,3)==([100,100,100,1] if old else [62,77,77,3]),"far primary and mixed lane positions")
 check(scenario(220,2)==[100,100,100,1],"Han 2SP range unchanged")
 check(scenario(55,3,true)==[62,77,0,2],"no hit on already defeated enemy")
 check(scenario(220,3,false,true)==([0,100,100,0] if old else [0,77,77,2]),"surviving field targets resolve when the initial lane target goes down")
 print("HAN SQUAD ", "PASS" if failed==0 else "FAIL", " failures=",failed)
 quit(failed)
