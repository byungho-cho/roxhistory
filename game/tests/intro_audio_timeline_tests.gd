extends SceneTree
class TimelineProbe extends "res://scripts/intro_audio_timeline.gd":
	var audible := [0.0,0.0]
	func _audible_seconds(index:int)->float:return audible[index]
var checks:=0
var failures:=0
func _initialize():call_deferred("run")
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures+=1;push_error(message)
func run():
	var timeline:=TimelineProbe.new();root.add_child(timeline)
	var stem:=AudioStreamWAV.new();stem.format=AudioStreamWAV.FORMAT_16_BITS;stem.mix_rate=8000
	var silence:=PackedByteArray();silence.resize(60*8000*2);stem.data=silence
	timeline.configure(stem,stem)
	check(timeline.players.size()==2,"only two stem voices")
	check(timeline.players[0].bus==&"BGM" and timeline.players[1].bus==&"SFX","independent existing settings buses")
	check(timeline.players[0].volume_db==0 and timeline.players[1].volume_db==0,"no additional legacy gain or crossfade")
	timeline.sync(6.02,true);await create_timer(.04).timeout
	check(timeline.starts==[1,1],"both stems start together at video time")
	check(timeline.players[0].get_meta("timeline_target")==6.02 and timeline.players[1].get_meta("timeline_target")==6.02,"shield contact offset shared")
	timeline.audible=[6.1,6.1];timeline.sync(6.1,true);await create_timer(.04).timeout
	check(timeline.starts==[1,1],"normal frame does not start extra voices")
	timeline.audible=[6.5,6.25];timeline.sync(6.5,true);await create_timer(.04).timeout
	check(timeline.seeks==[0,1],"only drifting effects stem corrected")
	timeline.audible=[.01,.01];timeline.sync(.01,true);await create_timer(.04).timeout
	check(timeline.starts==[2,2],"loop restarts both stems from new video clock")
	timeline.sync(12.0,false);await create_timer(.04).timeout
	check(not timeline.players[0].playing and not timeline.players[1].playing,"background stops both stems")
	timeline.sync(12.0,true);await create_timer(.04).timeout
	check(timeline.starts==[3,3] and timeline.players[0].get_meta("timeline_target")==12.0,"resume seeks video time rather than replaying opening")
	timeline.audible=[17.0,17.0];timeline.sync(17.0,true);await create_timer(.04).timeout
	check(timeline.starts==[4,4],"forward seek resynchronizes both stems")
	timeline.sync(61,true);await create_timer(.04).timeout
	check(timeline.starts==[4,4] and not timeline.players[0].playing,"short stem ends without repeating its tail")
	timeline.stop()
	check(not timeline.players[0].playing and not timeline.players[1].playing,"skip and exit stop all voices")
	timeline.queue_free();stem=null;await process_frame;await create_timer(.2).timeout
	print("Intro stem timeline: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

