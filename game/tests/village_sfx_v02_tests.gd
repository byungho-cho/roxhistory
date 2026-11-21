extends SceneTree
var checks := 0
var failures: Array[String] = []
func check(value: bool, message: String) -> void:
 checks += 1
 if not value: failures.append(message); push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var audio = load("res://scripts/soundscape.gd").new()
 root.add_child(audio)
 await process_frame
 check(audio.streams.recorded_stone.resource_path == "res://assets/audio/village-sfx-v02/stone-gather-v02.wav", "Stone uses v0.2")
 check(audio.streams.recorded_build.resource_path == "res://assets/audio/village-sfx-v02/construction-work-v02.wav", "Build uses v0.2")
 check(audio.streams.recorded_wood.resource_path == "res://assets/audio/recorded-actions-v001/wood-hit.wav", "Wood keeps v0.1")
 check(audio.streams.gain.resource_path == "res://assets/audio/gain.wav", "Gather complete keeps v0.1")
 check(audio.streams.recorded_demolish.resource_path == "res://assets/audio/recorded-actions-v001/demolish-hit.wav", "Demolition unchanged")
 audio.configure(true, true, true, false)
 for key in ["stone", "build"]:
  var stream: AudioStreamWAV = audio.streams["recorded_" + key]
  check(stream.mix_rate == 44100 and not stream.stereo, key + " valid PCM")
  check(stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, key + " no loop")
  audio.cue(key)
  check(audio.recorded_work.playing and audio.recorded_work.stream == stream, key + " correct playback")
  for i in 20: audio.cue(key)
  check(audio.voices.filter(func(v): return v.get_meta("work", false) and v.playing).is_empty(), key + " no stacked playback")
  audio.stop_work()
  check(not audio.recorded_work.playing, key + " cancellation stops")
 audio.cue("stone"); audio.configure(false, true, true, false)
 check(not audio.recorded_work.playing, "Sound off stops")
 var count: int = audio.events.size()
 audio.cue("build")
 check(audio.events.size() == count, "Sound off suppresses")
 audio.configure(true, true, true, false); audio.cue("build"); audio.configure(true, true, true, true)
 check(not audio.recorded_work.playing, "Popup stops")
 audio.configure(true, true, true, false); audio.cue("stone"); audio.configure(true, false, true, false)
 check(not audio.recorded_work.playing, "Background stops")
 audio.queue_free(); await process_frame
 print(JSON.stringify({"checks":checks,"failures":failures}))
 quit(0 if failures.is_empty() else 1)

