extends SceneTree
class SoundSpy extends RefCounted:
 var calls:=0
 func cue(_kind:String)->void:calls+=1
class AppStub extends Node:
 var model:GameState
 var audio:=SoundSpy.new()
 var screen:="play"
 var modal:=false
 var world_map_open:=false
 var application_active:=true
 var task:=""
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures.append(message);push_error(message)
func _initialize()->void:
 var app:=AppStub.new();app.model=GameState.new(SaveStore.new("user://building_audio_%d"%Time.get_ticks_usec()));app.model.start_new()
 var driver:=BuildingWorkAudio.new(app)
 for pair in [[0.0,0],[1.49,0],[1.5,1],[34.99,1],[35.0,3],[70.0,4]]:check(driver.phase(pair[0])==pair[1],"Sparse time phase "+str(pair[0]))
 var now:=Time.get_unix_time_from_system()
 app.model.begin_construction("chief",Vector2(1100,700),now)
 driver._process(.1);check(app.audio.calls==1,"New foreground construction sounds once")
 for i in 10:driver._process(.1)
 check(app.audio.calls==1,"Continuous progress does not loop audio")
 app.modal=true
 app.model.state.construction_jobs[0].started_at=now-2
 driver._process(2);check(app.audio.calls==1,"Popup suppresses sparse work phrase")
 app.modal=false;driver._process(2);check(app.audio.calls==1,"Closing popup does not replay missed work")
 app.model.state.construction_jobs[0].started_at=now-36
 driver._process(2);check(app.audio.calls==1,"Restored old job has no first-phrase replay")
 driver._process(2);check(app.audio.calls==1,"Old job remains quiet until next interval")
 app.model.state.construction_jobs.clear();driver._process(.1);check(driver.observed.is_empty(),"Completed or cancelled work clears tracking")
 driver.free();app.model=null;app.free()
 print(JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
