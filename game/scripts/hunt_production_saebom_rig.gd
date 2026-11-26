extends "res://scripts/saebom_motion_resident.gd"
## Resident rig for normal hunting; rules own movement, lock, and hit/release timing.
const CLIP_MAP := {"idle":"idle","walk":"walk","run":"run","attack":"basic_attack","basic":"basic_attack","hunt":"basic_attack","hit":"hit_reaction","skill":"sling_heavy","heavy":"sling_heavy","guard":"req045_evasive_guard","death":"req045_death"}
var preview: HybridCharacter:
 get:return self
var restore_after_cast: RefCounted
var saebom_run_age:=0.0

func _init() -> void:
 character = "saebom"
 shared_motion_view = true
 extra_motions = false

func _ready() -> void:
 super._ready()
 rig = skeleton
 heading = pivot.rotation.y
 target_heading = heading
 # Legacy screen touches this presentation handle. The real sling is inside the rig.
 tool_3d = Node3D.new()
 tool_3d.name = "LegacyPresentationHandle"
 pivot.add_child(tool_3d)
 camera.size = 3.5
 _sync_render_size(1.0)
 resident_sample("idle", 0.0)

func _sync_render_size(multiplier:float) -> void:
 var width := maxi(64,roundi(384.0*render_size_factor*multiplier))
 viewport.size = Vector2i(width,roundi(width*720.0/768.0))
 display.scale = Vector2.ONE*(0.46/1.5)*(384.0/float(width))
 display.position = -camera.unproject_position(Vector3.ZERO)*display.scale

func set_render_zoom(factor:float) -> void:
 if viewport == null:return
 if factor >= 1.5:_sync_render_size(2.0)
 elif factor <= 1.25:_sync_render_size(1.0)

func use_training_spear() -> void:
 # Saebom never receives a generated spear.
 pass

func blend_bone(_label:String,_euler:Vector3,_weight:float) -> void:
 # This authored rig owns its poses; Meshy-only bone aliases must not overwrite them.
 pass

func resident_sample(key:String,seconds:float) -> void:
 if not is_instance_valid(animation):return
 var clip:String = CLIP_MAP.get(key,"idle")
 var gait:=saebom_gait_period(key)
 var duration := gait if gait>0.0 else Timing.duration(character,clip,animation.get_animation(clip).length)
 var time := fposmod(seconds,duration) if key in ["idle","walk","run"] else clampf(seconds,0.0,duration)
 sample_clip(clip,time,seconds)

func animate(delta:float,movement:Vector2,phase:float,walking:bool,action:String,action_time:float,paused:bool) -> void:
 if not enabled or paused:return
 clock += maxf(delta,0.0)
 if movement.length_squared()>.01:target_heading=atan2(movement.x,movement.y)
 heading=lerp_angle(heading,target_heading,1.0-exp(-maxf(0.0,delta)*12.0))
 pivot.rotation.y=heading
 if walking:
  var period:=motion_duration("run")
  resident_sample("run",(clock if not is_finite(phase) else phase/TAU*period) if saebom_use_native_locomotion else saebom_run_age)
  saebom_run_age+=maxf(0.,delta)
 elif CLIP_MAP.has(action) and action not in ["idle","walk","run"]:
  resident_sample(action,action_time)
 else:
  resident_sample("idle",clock)

# The release scheduler may sample the authored 2SP native release without moving the unit.
func sample_native_release(key:String,native_seconds:float) -> void:
 if not is_instance_valid(animation):return
 var clip:String = CLIP_MAP.get(key,"idle")
 animation.play(clip)
 animation.advance(0.0)
 animation.seek(clampf(native_seconds,0.0,animation.get_animation(clip).length),true)
 skeleton.force_update_all_bone_transforms()

func has_anchor(bone_name:String) -> bool:
 return is_instance_valid(skeleton) and skeleton.find_bone(bone_name)>=0

func project_bone(bone_name:String) -> Vector2:
 if not has_anchor(bone_name) or camera==null or display==null:return global_position
 var point:=skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone(bone_name)).origin)
 return display.to_global(camera.unproject_position(point))

func stone_world() -> Vector2:
 return project_bone("sling_stone") if has_anchor("sling_stone") else hand_world()

func hand_world() -> Vector2:
 return project_bone("hand.R")

func chest_world() -> Vector2:
 return project_bone("chest")

func head_world() -> Vector2:
 return project_bone("head")

func tool_contact_world() -> Vector2:
 # Compatibility with legacy caller's manual actor scale; new code uses stone_world().
 return global_position+to_local(stone_world())

func apply_support_pose(effect:RefCounted,elapsed:float) -> void:
 if effect==null or not enabled:return
 if restore_after_cast!=null and effect!=restore_after_cast:clear_support_pose()
 restore_after_cast=effect
 effect.call("sync_sling",pivot,elapsed>=.10 and elapsed<2.24)
 if elapsed>=0.0 and elapsed<2.24:effect.call("pose_cast",self,elapsed)
 else:clear_support_pose()

func clear_support_pose() -> void:
 if restore_after_cast!=null:restore_after_cast.call("restore_sling")
 restore_after_cast=null

func set_enabled(value:bool) -> void:
 if not value:clear_support_pose()
 super.set_enabled(value)
