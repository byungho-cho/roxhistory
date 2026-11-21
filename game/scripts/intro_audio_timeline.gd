extends Node
## Two non-looping stems follow the video clock; bus settings own all gain/mute.
const DRIFT_LIMIT := .08
const CHECK_INTERVAL := .4
var players: Array[AudioStreamPlayer] = []
var last_video := -1.0
var checked_at := -1.0
var starts := [0,0]
var seeks := [0,0]

func configure(music:AudioStream,effects:AudioStream)->void:
	assert(players.is_empty(),"Configure each intro timeline once")
	for i in 2:
		var player:=AudioStreamPlayer.new()
		player.name="IntroBGM" if i==0 else "IntroSFX"
		player.bus=&"BGM" if i==0 else &"SFX"
		player.stream=music if i==0 else effects
		player.volume_db=0 # Authored WAV envelopes are already baked in.
		player.max_polyphony=1
		add_child(player);players.append(player)

func _audible_seconds(index:int)->float:
	return maxf(0,players[index].get_playback_position()+AudioServer.get_time_since_last_mix()-AudioServer.get_output_latency())

func sync(video_seconds:float,running:bool,force:=false)->void:
	if not running:
		stop()
		return
	if players.size()!=2:return
	var seconds:=maxf(0,video_seconds)
	var discontinuity:=last_video<0 or seconds+.25<last_video or seconds-last_video>.5
	var inspect:=force or discontinuity or checked_at<0 or seconds-checked_at>=CHECK_INTERVAL
	for i in 2:
		var player:=players[i]
		if player.stream==null:continue
		if seconds>=player.stream.get_length():
			player.stop() # A shorter stem must end in silence, not replay its tail.
			continue
		var target:=minf(seconds+AudioServer.get_output_latency(),maxf(0,player.stream.get_length()-.001))
		if force or discontinuity or not player.playing:
			player.play(target);starts[i]+=1
			player.set_meta("timeline_target",seconds)
		elif inspect and absf(_audible_seconds(i)-seconds)>DRIFT_LIMIT:
			player.seek(target);seeks[i]+=1
			player.set_meta("timeline_target",seconds)
	last_video=seconds
	if inspect:checked_at=seconds

func stop()->void:
	for player in players:player.stop()
	last_video=-1;checked_at=-1

func _exit_tree()->void:
	stop()
