class_name DemoSoundscape
extends Node

var enabled := false
var active := true
var in_world := false
var in_region := false
const SCENE_MUSIC := {
	"village": preload("res://assets/audio/d0003-bgm/A09-10-warm-horizon.ogg"),
	"world_map": preload("res://assets/audio/d0003-bgm/A09-11-moving-landscape.ogg"),
	"title": preload("res://assets/audio/d0002-bgm/RoxHistory_Title_BGM_edit_candidate_v01.ogg"),
	"hunt_preparation": preload("res://assets/audio/d0002-bgm/RoxHistory_Hunt_Preparation_BGM_edit_candidate_v01.ogg"),
	"hunt_battle": preload("res://assets/audio/d0002-bgm/RoxHistory_Hunt_Battle_BGM_edit_candidate_v01.ogg"),
}
const SCENE_MUSIC_DB := {"village": -12.0, "world_map": -12.0, "title": -10.0, "hunt_preparation": -8.0, "hunt_battle": -10.0}
var scene_music_players: Dictionary[String, AudioStreamPlayer] = {}
var scene_music := ""
var ducked := false
var voices: Array[AudioStreamPlayer] = []
var recorded_work:AudioStreamPlayer
var river: AudioStreamPlayer
var hearth: AudioStreamPlayer
var hearth_proximity := 0.0
var wind: AudioStreamPlayer
var bgm: AudioStreamPlayer
var streams := {}
var events: Array[String] = []
var variant := 0
var river_proximity := 0.5
var bird_wait := 11.0
var nature_random := RandomNumberGenerator.new()
var last_interface_ms := -1000
const APPROVED := {
	"ui":"menu-stone-tap", "building_select":"building-select", "bird":"bird-calls",
	"complete":"construction-complete", "reward":"reward-obtain", "river":"river-flow",
	"hearth":"hearth-fire",
}
const REGION_MUSIC_DB := -10.0
const REGION_WATER_DB := -25.0
const INTERFACE_GAP_MS := 75
const ACTION_CUES := ["quest_click","action_click","popup_open","popup_close","map_open","map_close"]

func _ready() -> void:
	nature_random.randomize()
	for key in ["select","a303_bgm","wood_0","wood_1","stone_0","stone_1","build_0","build_1","gain"]:
		streams[key] = load("res://assets/audio/"+key+".wav")
	for key in APPROVED:
		streams[key] = load("res://assets/audio/d0004-approved/"+APPROVED[key]+".wav")
	streams["quest_click"] = preload("res://assets/audio/d0001-approved/quest-click.wav")
	streams["action_click"] = preload("res://assets/audio/d0001-approved/action-click.wav")
	streams["popup_open"] = preload("res://assets/audio/d0001-approved/popup-open.mp3")
	streams["popup_close"] = preload("res://assets/audio/d0001-approved/popup-close.mp3")
	streams["map_open"] = preload("res://assets/audio/d0001-approved/map-open.mp3")
	streams["map_close"] = preload("res://assets/audio/d0001-approved/map-close.mp3")
	for key in ["wood","stone","build","demolish"]:
		streams["recorded_"+key]=load("res://assets/audio/recorded-actions-v001/"+key+"-hit.wav")
	streams["recorded_stone"] = preload("res://assets/audio/village-sfx-v02/stone-gather-v02.wav")
	streams["recorded_build"] = preload("res://assets/audio/village-sfx-v02/construction-work-v02.wav")
	streams["wind"] = preload("res://assets/audio/village-sfx-v02/village-wind-b02.wav")
	streams["hunt_impact"] = streams["stone_0"]
	recorded_work=AudioStreamPlayer.new();recorded_work.name="RecordedActionVoice";recorded_work.bus=&"SFX";add_child(recorded_work)
	for i in 6:
		var voice := AudioStreamPlayer.new()
		voice.bus = &"SFX"
		add_child(voice); voices.append(voice)
	river = ambience("river",-30,&"Environment")
	hearth = ambience("hearth",-60,&"Environment")
	wind = ambience("wind",-35,&"Environment")
	bgm = ambience("a303_bgm",-60,&"BGM")
	for key: String in SCENE_MUSIC:
		var stream: AudioStreamOggVorbis = SCENE_MUSIC[key].duplicate()
		stream.loop = true
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.bus = &"BGM"
		add_child(player)
		scene_music_players[key] = player

func ambience(key: String, volume: float, bus: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	var stream: AudioStreamWAV = streams[key].duplicate()
	var loop_frames := roundi(stream.get_length()*stream.mix_rate)
	# Godot 4.5's WAV mixer may read loop_end inclusively, even though it wraps
	# at this offset. A head-frame guard makes that read safe and periodic;
	# the original master and the N-frame loop interval remain unchanged.
	# https://github.com/godotengine/godot/issues/119778
	if stream.format in [AudioStreamWAV.FORMAT_8_BITS,AudioStreamWAV.FORMAT_16_BITS]:
		var frame_bytes := (2 if stream.stereo else 1)*(2 if stream.format==AudioStreamWAV.FORMAT_16_BITS else 1)
		var guarded := stream.data
		guarded.append_array(guarded.slice(0,frame_bytes))
		stream.data = guarded
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = loop_frames
	player.stream = stream; player.volume_db = volume; player.bus = bus
	add_child(player)
	return player

func configure(sound: bool, foreground: bool, playing: bool, popup: bool, region: bool = false, title: bool = false, hunt_music: String = "", world_map: bool = false) -> void:
	var was_nature := in_region or in_world
	if (in_world and not playing) or (in_region and not region): stop_effects()
	var was_audible := enabled and active
	enabled = sound; active = foreground; in_world = playing; ducked = popup; in_region = region
	scene_music = "title" if title else ("world_map" if world_map else "village") if playing else hunt_music
	sync_scene_music()
	if popup or not playing:stop_work()
	if not was_nature and (in_region or in_world): bird_wait = nature_random.randf_range(9,14)
	if enabled and active and not was_audible: last_interface_ms = -1000
	if not enabled or not active:
		stop_effects()
		if bgm and bgm.playing:
			bgm.stream_paused = true
			bgm.volume_db = -60
		if bgm and not in_region: bgm.stop()
	elif bgm:
		if in_region:
			if bgm.stream_paused: bgm.stream_paused = false
			elif not bgm.playing:
				bgm.volume_db = -60
				bgm.play()
		elif bgm.stream_paused: bgm.stop()
	if not enabled or not active or not (in_world or in_region):
		if river: river.stop(); wind.stop()
	elif river and not river.playing:
		river.volume_db = -55; wind.volume_db = -55
		river.play()
	if wind:
		if enabled and active and in_world:
			if not wind.playing: wind.volume_db = -55; wind.play()
		else: wind.stop() # The region map uses one quiet water bed beneath the music.
	if not enabled or not active or not in_world: hearth.stop()
	trace_status("configure")

func trace_status(reason: String) -> void:
	if "--test-ui" not in OS.get_cmdline_user_args(): return
	var village := scene_music_players["village"]
	print("PLAY_AUDIO_STATE "+JSON.stringify({"reason":reason,"enabled":enabled,"active":active,"world":in_world,"playing":village.playing,"paused":village.stream_paused,"position":village.get_playback_position(),"db":village.volume_db}))
	print("A303_AUDIO_STATE "+JSON.stringify({"reason":reason,"enabled":enabled,"active":active,"region":in_region,"bgm":bgm.playing,"paused":bgm.stream_paused,"position":bgm.get_playback_position(),"music_db":bgm.volume_db,"water":river.playing,"wind":wind.playing,"events":events,"ticks_ms":Time.get_ticks_msec()}))

func stop_effects() -> void:
	if recorded_work:recorded_work.stop()
	for voice in voices: voice.stop()

func stop_work() -> void:
	if recorded_work:recorded_work.stop()
	for voice in voices:
		if voice.get_meta("work",false): voice.stop()

func interface_time_ms() -> int:
	return Time.get_ticks_msec()

func cue(key: String) -> void:
	if not enabled or not active: return
	if key in ["wood","stone","build","demolish"]:
		if not in_world or ducked:return
		# One work voice: never stack the five-second listening arrangements.
		recorded_work.stop();recorded_work.stream=streams["recorded_"+key]
		recorded_work.volume_db=-8;recorded_work.pitch_scale=1.0;recorded_work.play()
		events.append("recorded_"+key)
		if events.size()>96:events.pop_front()
		return
	if key in ["ui","select","building_select"]:
		var now := interface_time_ms()
		if now-last_interface_ms < INTERFACE_GAP_MS: return
		last_interface_ms = now
		# UI and region cues share one audible slot, even after the rate gate.
		# Replace their previous tail instead of stacking up to four 250ms cues.
		for previous in voices:
			if previous.stream in [streams.get("ui"),streams.get("select"),streams.get("building_select")]:previous.stop()
	if key in ACTION_CUES:
		for previous in voices:
			if previous.has_meta("action_cue") and previous.get_meta("action_cue"):
				previous.stop()
	var work := key in ["wood","stone","build"]
	if work:
		variant = (variant+1)%2
		key += "_"+str(variant)
	if not streams.has(key): return
	var voice: AudioStreamPlayer = null
	for candidate in voices:
		if not candidate.playing: voice = candidate; break
	if voice == null: return # Bounded pool; never stack unbounded effects.
	voice.stream = streams[key]
	voice.bus = &"Environment" if key == "bird" else &"SFX"
	voice.set_meta("work",work)
	voice.set_meta("action_cue",key in ACTION_CUES)
	voice.volume_db = -8 if work else (-20 if key == "bird" else -12)
	voice.pitch_scale = nature_random.randf_range(.96,1.02) if key == "bird" else 1.0
	voice.play()
	events.append(key)
	if events.size()>96: events.pop_front()
	if key in ["ui","select","bird"]: trace_status(key)

func sync_scene_music() -> void:
	for key: String in scene_music_players:
		var player := scene_music_players[key]
		if not enabled or not active:
			if key != scene_music:
				player.stop()
			elif player.playing:
				player.stream_paused = true
			player.volume_db = -60.0
		elif key == scene_music:
			if player.stream_paused:
				player.stream_paused = false
			elif not player.playing:
				player.volume_db = -60.0
				player.play()
		elif player.stream_paused:
			player.stop()

func fade_scene_music(delta: float) -> void:
	for key: String in scene_music_players:
		var player := scene_music_players[key]
		if not player.playing or player.stream_paused:continue
		var selected := key == scene_music
		var target := float(SCENE_MUSIC_DB[key]) - (6.0 if ducked else 0.0) if selected else -60.0
		player.volume_db = move_toward(player.volume_db, target, delta * 100.0)
		if not selected and player.volume_db <= -60.0:player.stop()

func _process(delta: float) -> void:
	if not enabled or not active: return
	fade_scene_music(delta)
	if bgm and bgm.playing and not bgm.stream_paused:
		var target := REGION_MUSIC_DB+(-3.0 if ducked else 0.0) if in_region else -60.0
		bgm.volume_db = move_toward(bgm.volume_db,target,delta*100)
		if not in_region and bgm.volume_db <= -59.9: bgm.stop()
	if river and river.playing:
		var duck := -8.0 if ducked else 0.0
		var water_level := REGION_WATER_DB if in_region else lerpf(-36.0206,-26.0206,river_proximity)
		river.volume_db = move_toward(river.volume_db,water_level+duck,delta*22)

		if wind.playing:
			var variation := sin(TAU*wind.get_playback_position()/wind.stream.get_length())*1.5
			wind.volume_db = move_toward(wind.volume_db,-39+duck+variation,delta*22)
	if in_world and hearth_proximity > 0.0 and not hearth.playing:
		hearth.volume_db = -60.0
		hearth.play()
	if hearth.playing:
		var fire_db := lerpf(-60.0,-24.0,hearth_proximity) - (8.0 if ducked else 0.0)
		hearth.volume_db = move_toward(hearth.volume_db,fire_db,delta*35)
		if hearth_proximity <= 0.0 and hearth.volume_db <= -59.9: hearth.stop()
	if (in_region or in_world) and not ducked:
		bird_wait -= minf(delta,.1)
		if bird_wait <= 0:
			cue("bird")
			bird_wait = nature_random.randf_range(22,36)
