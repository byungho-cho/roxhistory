extends "res://scripts/res011_lab_preview.gd"
## Saebom-only motion adapter. The native clips remain installed for all
## attack, idle-in-combat, block, hit, game-clock and contact consumers.
const MESHY_IDLE:Animation=preload("res://assets/characters/saebom-meshy-motion/idle.res")
const MESHY_WALK:Animation=preload("res://assets/characters/saebom-meshy-motion/walk.res")
const MESHY_RUN:Animation=preload("res://assets/characters/saebom-meshy-motion/run.res")
const MESHY_BRIDGE:Animation=preload("res://assets/characters/saebom-meshy-motion/run-to-walk.res")
const MESHY_DEAD:Animation=preload("res://assets/characters/saebom-meshy-motion/death.res")
const VISUAL := {
 "idle":&"meshy_saebom_idle",
 "walk":&"meshy_saebom_walk",
 "run":&"meshy_saebom_run",
 "req045_death":&"req_meshy_saebom_dead",
}
var saebom_combat_view:=true
var saebom_bridge_clock:=-1.0
var saebom_bridge_started_at:=0.0
var saebom_use_native_locomotion:=false
var last_saebom_motion:="idle"
var last_saebom_motion_time:=0.0
var _bridge_bones:PackedInt32Array=PackedInt32Array()

func _init()->void:
 character="saebom"

func _ready()->void:
 super._ready()
 var lib:=animation.get_animation_library("").duplicate() as AnimationLibrary
 lib.add_animation(VISUAL.idle,MESHY_IDLE)
 lib.add_animation(VISUAL.walk,MESHY_WALK)
 lib.add_animation(VISUAL.run,MESHY_RUN)
 lib.add_animation(VISUAL.req045_death,MESHY_DEAD)
 animation.remove_animation_library("")
 animation.add_animation_library("",lib)
 for track in MESHY_BRIDGE.get_track_count():
  _bridge_bones.append(skeleton.find_bone(MESHY_BRIDGE.track_get_path(track).get_subname(0)))
 animation.play("idle")
 animation.advance(0.0)

func saebom_gait_period(key:String)->float:
 if saebom_use_native_locomotion and key in ["walk","run"]:return 0.0
 match key:
  "idle":return 0.0 if saebom_combat_view else MESHY_IDLE.length
  "walk":return MESHY_WALK.length
  "run":return MESHY_RUN.length
 return 0.0

func motion_duration(key:String)->float:
 var period:=saebom_gait_period(key)
 return period if period>0.0 else super.motion_duration(key)

func sample_clip(clip:String,at:float,source_clock:=NAN)->void:
 if clip!="run":
  saebom_bridge_clock=-1.0
 if (clip=="idle" and saebom_combat_view) or (saebom_use_native_locomotion and clip in ["walk","run"]) or not VISUAL.has(clip):
  super.sample_clip(clip,at,source_clock)
  last_saebom_motion=clip
  last_saebom_motion_time=at
  return
 var alias:StringName=VISUAL[clip]
 var elapsed:=maxf(0.0,at)
 if clip=="req045_death":
  # The controller's existing fade and reward times still use real age
  # and the old mechanical span. Only the sampled pose changes.
  elapsed=maxf(0.0,source_clock if not is_nan(source_clock) else at)
 var span:=animation.get_animation(alias).length
 if StringName(animation.current_animation)!=alias:
  if clip=="req045_death":skeleton.reset_bone_poses()
  animation.play(alias)
  animation.advance(0.0)
 last_saebom_motion_time=clampf(elapsed,0.0,span) if clip=="req045_death" else fposmod(elapsed,span)
 animation.seek(last_saebom_motion_time,true)
 skeleton.force_update_all_bone_transforms()
 pivot.position=Vector3.ZERO
 extract_tail=0.0
 last_sample=at if is_nan(source_clock) else source_clock
 last_saebom_motion=String(alias)

func present_saebom_approach_finish(active:bool,dt:float,remaining:float)->String:
 if not active or last_saebom_motion!=String(VISUAL.run):
  saebom_bridge_clock=-1.0
  return "run"
 if saebom_bridge_clock<0.0:
  saebom_bridge_started_at=MESHY_BRIDGE.length-clampf(remaining,.20,MESHY_BRIDGE.length)
  saebom_bridge_clock=saebom_bridge_started_at
 else:saebom_bridge_clock+=maxf(0.0,dt)
 var bridge_t:=minf(saebom_bridge_clock,MESHY_BRIDGE.length)
 var bridge_in:=smoothstep(0.0,.16,saebom_bridge_clock-saebom_bridge_started_at)
 var walk_in:=smoothstep(MESHY_BRIDGE.length-.23,MESHY_BRIDGE.length,bridge_t)
 var walk_t:=fposmod(.16+maxf(0.0,saebom_bridge_clock-(MESHY_BRIDGE.length-.23)),MESHY_WALK.length)
 for k in _bridge_bones.size():
  var id:=_bridge_bones[k]
  if id<0:continue
  match MESHY_BRIDGE.track_get_type(k):
   Animation.TYPE_POSITION_3D:
    var p:=MESHY_BRIDGE.position_track_interpolate(k,bridge_t).lerp(MESHY_WALK.position_track_interpolate(k,walk_t),walk_in)
    skeleton.set_bone_pose_position(id,skeleton.get_bone_pose_position(id).lerp(p,bridge_in))
   Animation.TYPE_ROTATION_3D:
    var r:=MESHY_BRIDGE.rotation_track_interpolate(k,bridge_t).slerp(MESHY_WALK.rotation_track_interpolate(k,walk_t),walk_in)
    skeleton.set_bone_pose_rotation(id,skeleton.get_bone_pose_rotation(id).slerp(r,bridge_in))
   Animation.TYPE_SCALE_3D:
    var s:=MESHY_BRIDGE.scale_track_interpolate(k,bridge_t).lerp(MESHY_WALK.scale_track_interpolate(k,walk_t),walk_in)
    skeleton.set_bone_pose_scale(id,skeleton.get_bone_pose_scale(id).lerp(s,bridge_in))
 skeleton.force_update_all_bone_transforms()
 return "walk" if saebom_bridge_clock>=MESHY_BRIDGE.length else "run_to_walk"
