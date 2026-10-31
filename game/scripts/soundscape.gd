class_name DemoSoundscape
extends Node

var enabled := false
var active := true
var in_world := false
var ducked := false
var voices: Array[AudioStreamPlayer] = []
var river: AudioStreamPlayer
var wind: AudioStreamPlayer
var streams := {}
var events: Array[String] = []
var variant := 0
var river_proximity := 0.5

func _ready() -> void:
	for key in ["ui","wood_0","wood_1","stone_0","stone_1","build_0","build_1","gain","complete","reward","river","wind"]:
		streams[key] = load("res://assets/audio/"+key+".wav")
	for i in 6:
		var voice := AudioStreamPlayer.new()
		voice.bus = "Master"
		add_child(voice); voices.append(voice)
	river = ambience("river",-30)
	wind = ambience("wind",-35)

func ambience(key: String, volume: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	var stream: AudioStreamWAV = streams[key].duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length()*stream.mix_rate)
	player.stream = stream; player.volume_db = volume
	add_child(player)
	return player

func configure(sound: bool, foreground: bool, playing: bool, popup: bool) -> void:
	enabled = sound; active = foreground; in_world = playing; ducked = popup
	if not enabled or not active:
		stop_effects()
	if not enabled or not active or not in_world:
		if river: river.stop(); wind.stop()
	elif river and not river.playing:
		river.volume_db = -55; wind.volume_db = -55
		river.play(); wind.play()

func stop_effects() -> void:
	for voice in voices: voice.stop()

func stop_work() -> void:
	for voice in voices:
		if voice.get_meta("work",false): voice.stop()

func cue(key: String) -> void:
	if not enabled or not active: return
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
	voice.set_meta("work",work)
	voice.volume_db = -8 if work else (-13 if key == "ui" else -12)
	voice.pitch_scale = 1.0
	voice.play()
	events.append(key)
	if events.size()>96: events.pop_front()

func _process(delta: float) -> void:
	if river and river.playing:
		var duck := -8.0 if ducked else 0.0
		river.volume_db = move_toward(river.volume_db,lerpf(-27,-17,river_proximity)+duck,delta*22)
		wind.volume_db = move_toward(wind.volume_db,-39+duck,delta*22)
