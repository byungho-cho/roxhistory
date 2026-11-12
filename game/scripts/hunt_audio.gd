extends Node

const ROOT := "res://assets/audio/hunt-d0003/"
const APPROVED := {
	"S02":"menu-stone-tap", "S06":"menu-stone-tap", "S07":"popup-open", "S08":"popup-close",
	"S11":"vs-collision", "S12":"battle-start", "S16":"normal-hit", "S18":"heavy-hit",
	"S20":"cooperative-attack", "S22":"deer-hurt", "S23":"orb-full", "S24":"skill-ready",
	"S26":"victory", "S27":"hunt-failure",
}
const APPROVED_ROOT := "res://assets/audio/d0004-approved/"
const LEVELS := {
	"S01":-20.0,"S02":-18.0,"S03":-20.0,"S04":-16.0,"S05":-18.0,"S06":-18.0,
	"S07":-18.0,"S08":-18.0,"S09":-15.0,"S10":-17.0,"S11":-11.0,"S12":-12.0,
	"S13":-26.0,"S14":-26.0,"S15":-15.0,"S16":-12.0,"S17":-14.0,"S18":-9.0,
	"S19":-13.0,"S20":-10.0,"S21":-15.0,"S22":-18.0,"S23":-16.0,"S24":-16.0,
	"S25":-20.0,"S26":-10.0,"S27":-12.0,
}

var streams := {}
var pool: Array[AudioStreamPlayer] = []
var priorities: Array[int] = []
var music: Array[AudioStreamPlayer] = []
var recent := {}
var enabled := false
var paused := false
var battle := false
var blend := 0.0

func _ready() -> void:
	for id in LEVELS:
		var path := APPROVED_ROOT+str(APPROVED[id]) if APPROVED.has(id) else ROOT+str(id)
		streams[id] = load(path+".wav")
	for index in 6:
		var player := AudioStreamPlayer.new()
		add_child(player)
		player.bus = &"SFX"
		pool.append(player)
		priorities.append(0)
	for id in ["B03","B01","B02"]:
		var player := AudioStreamPlayer.new()
		var stream: AudioStreamWAV = load(ROOT+id+".wav").duplicate()
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = roundi(stream.get_length()*stream.mix_rate)
		player.stream = stream
		add_child(player)
		player.bus = &"BGM"
		music.append(player)


func _exit_tree() -> void:
	for player in pool + music:
		player.stop()
		player.stream = null
	streams.clear()


func update(delta: float, audible: bool, held: bool) -> void:
	if enabled!=audible:
		enabled = audible
		for player in music:
			if enabled:player.play()
			else:player.stop()
	if paused!=held or not enabled:
		for player in pool:
			if not enabled or player.stream!=streams["S07"]:player.stop()
	paused = held
	blend = move_toward(blend,1.0 if battle else 0.0,delta/.8)
	var attenuation := -6.0 if paused else 0.0
	music[0].volume_db = -8.0+attenuation+linear_to_db(maxf(.0001,cos(blend*PI*.5)))
	music[1].volume_db = -8.0+attenuation+linear_to_db(maxf(.0001,sin(blend*PI*.5)))
	music[2].volume_db = -26.0+attenuation


func cue(id: String, priority := 1) -> void:
	if not enabled or paused or not streams.has(id):return
	var now := Time.get_ticks_msec()
	var gap := 420 if id == "S22" else 90
	var cue_key: String = APPROVED.get(id,id)
	if now-int(recent.get(cue_key,-1000))<gap:return
	if APPROVED.has(id):
		for voice in pool:
			if voice.playing and voice.stream == streams[id]:
				if id == "S22":return
				voice.stop()
	var slot := -1
	for index in pool.size():
		if not pool[index].playing:
			slot = index
			break
		if priorities[index]<priority and (slot<0 or priorities[index]<priorities[slot]):
			slot = index
	if slot<0:return
	recent[cue_key] = now
	priorities[slot] = priority
	var player := pool[slot]
	player.stop()
	player.stream = streams[id]
	player.volume_db = LEVELS[id]
	player.play()
