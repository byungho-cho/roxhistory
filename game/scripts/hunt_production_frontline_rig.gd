extends RefCounted
## Presentation only. Caller owns actor positions, timing, collision and damage.
const MODEL_HAN := "res://assets/characters/res050/hangyeol-latest.glb"
const MODEL_URAM := "res://assets/characters/res050/uram-latest.glb"

static func create(hero_key:String)->HybridCharacter:
 match hero_key:
  "hangyeol":return Han.new()
  "uram":return Uram.new()
 return null

class Han extends "res://scripts/res011_lab_preview.gd":
 const CLIP_MAP:={"idle":"idle","walk":"walk","run":"run","basic":"basic_attack","attack":"basic_attack","hunt":"basic_attack","skill":"req047_ground_thrust","chain":"jump_spear_auto_r03","hit":"hit_reaction","parry":"spear_guard","guard":"spear_guard","counter":"parry_counter","death":"req045_death"}
 # Farthest +Z vertex (55) of RES050's chipped-point mesh, weighted 100% to hand.R.
 const SPEAR_BIND_TIP:=Vector3(-.323000014,.924692392,1.272105813)
 var spear_tip_local:Vector3
 var spear_mesh:MeshInstance3D
 var hand_index:=-1
 func _init()->void:
  character="hangyeol";shared_motion_view=true;extra_motions=false
 func _ready()->void:
  super._ready()
  rig=skeleton
  tool_3d=Node3D.new();pivot.add_child(tool_3d)
  heading=pivot.rotation.y;target_heading=heading
  hand_index=skeleton.find_bone("hand.R")
  if hand_index>=0:spear_tip_local=skeleton.get_bone_global_rest(hand_index).affine_inverse()*SPEAR_BIND_TIP
  for mesh in pivot.find_children("*","MeshInstance3D",true,false):
   if "chipped point" in String(mesh.name).to_lower():spear_mesh=mesh as MeshInstance3D;break
  camera.size=3.5
  _resize_render(1.)
  resident_sample("idle",0.)
 func _resize_render(mult:float)->void:
  var w:=maxi(64,roundi(384.*render_size_factor*mult))
  viewport.size=Vector2i(w,roundi(w*720./768.))
  display.scale=Vector2.ONE*(.46/1.5)*(384./float(w))
  display.position=-camera.unproject_position(Vector3.ZERO)*display.scale
 func set_render_zoom(factor:float)->void:
  if not is_instance_valid(viewport):return
  if factor>=1.5:_resize_render(2.)
  elif factor<=1.25:_resize_render(1.)
 func use_training_spear()->void:pass
 func blend_bone(_label:String,_euler:Vector3,_weight:float)->void:pass
 func supports_profile(key:String)->bool:
  return is_instance_valid(animation) and CLIP_MAP.has(key) and animation.has_animation(CLIP_MAP[key])
 func clip_duration(key:String)->float:
  if not supports_profile(key):return 0.
  return Timing.duration(character,CLIP_MAP[key],animation.get_animation(CLIP_MAP[key]).length)
 func resident_sample(key:String,elapsed:float)->bool:
  if not supports_profile(key):return false
  var span:=clip_duration(key)
  sample_clip(CLIP_MAP[key],fposmod(elapsed,span) if key in ["idle","run","walk"] else clampf(elapsed,0.,span),elapsed)
  return true
 func sample_native(key:String,seconds:float)->bool:
  if not supports_profile(key):return false
  var clip:String=CLIP_MAP[key]
  animation.play(clip);animation.advance(0.)
  animation.seek(clampf(seconds,0.,animation.get_animation(clip).length),true)
  pivot.position=Vector3.ZERO
  skeleton.force_update_all_bone_transforms()
  return true
 func animate(delta:float,movement:Vector2,phase:float,walking:bool,action:String,action_time:float,paused:bool)->void:
  if not enabled or paused:return
  clock+=maxf(delta,0.)
  if movement.length_squared()>.01:target_heading=atan2(movement.x,movement.y)
  heading=lerp_angle(heading,target_heading,1.-exp(-maxf(delta,0.)*12.))
  pivot.rotation.y=heading
  if walking:resident_sample("run",phase/TAU*clip_duration("run") if is_finite(phase) else clock)
  elif not resident_sample(action,action_time):resident_sample("idle",clock)
 func feet_world()->Vector2:return global_position
 func _project(point:Vector3)->Vector2:return display.to_global(camera.unproject_position(point))
 func has_spear_anchor()->bool:return hand_index>=0 and is_instance_valid(spear_mesh)
 func spear_tip_world()->Vector2:
  if not has_spear_anchor():return feet_world()
  return _project(skeleton.global_transform*skeleton.get_bone_global_pose(hand_index)*spear_tip_local)
 func contact_point()->Vector2:return spear_tip_world()
 func tool_contact_world()->Vector2:return global_position+to_local(spear_tip_world())

class Uram extends "res://scripts/uram_lab_rig.gd":
 const CLIP_MAP:={"idle":"idle","walk":"walk","run":"run","basic":"club_attack","attack":"club_attack","hunt":"club_attack","skill":"req047_club_slam","chain":"parry","parry":"parry","hit":"hit_reaction","guard":"req045_shield_guard","counter":"req045_shield_counter","death":"req045_death"}
 func _init()->void:
  use_retouch=true;extra_motions=false
 func _ready()->void:
  super._ready()
  rig=skeleton
  tool_3d=Node3D.new();pivot.add_child(tool_3d)
  heading=pivot.rotation.y;target_heading=heading
  animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
  resident_sample("idle",0.)
 func use_training_spear()->void:pass
 func blend_bone(_label:String,_euler:Vector3,_weight:float)->void:pass
 func supports_profile(key:String)->bool:
  return is_instance_valid(animator) and CLIP_MAP.has(key) and animator.has_animation(CLIP_MAP[key])
 func clip_duration(key:String)->float:
  return clip_length(CLIP_MAP[key]) if supports_profile(key) else 0.
 func resident_sample(key:String,seconds:float)->bool:
  if not supports_profile(key):return false
  var span:=clip_duration(key)
  show_pose(CLIP_MAP[key],fposmod(seconds,span) if key in ["idle","walk","run"] else clampf(seconds,0.,span))
  return true
 func sample_native(key:String,seconds:float)->bool:
  if not supports_profile(key):return false
  show_pose(CLIP_MAP[key],clampf(seconds,0.,clip_duration(key)))
  return true
 func animate(delta:float,movement:Vector2,phase:float,walking:bool,action:String,action_time:float,paused:bool)->void:
  if not enabled or paused:return
  clock+=maxf(delta,0.)
  if movement.length_squared()>.01:target_heading=atan2(movement.x,movement.y)
  heading=lerp_angle(heading,target_heading,1.-exp(-maxf(delta,0.)*12.))
  pivot.rotation.y=heading
  if walking:resident_sample("run",phase/TAU*clip_duration("run") if is_finite(phase) else clock)
  elif not resident_sample(action,action_time):resident_sample("idle",clock)
 func feet_world()->Vector2:return global_position
 func _project(point:Vector3)->Vector2:return display.to_global(camera.unproject_position(point))
 func has_club_anchor()->bool:return is_instance_valid(club)
 func has_shield_anchor()->bool:return is_instance_valid(shield)
 func club_head_world()->Vector2:
  if not has_club_anchor():return feet_world()
  # Authored quad, stone center at u=.84, v=.50 in stone-club.png.
  return _project(club.to_global(Vector3(CLUB_SIZE.x*.34,0.,0.)))
 func shield_face_world()->Vector2:
  return _project(shield.global_position) if has_shield_anchor() else feet_world()
 func shield_direction_world()->Vector2:
  if not has_shield_anchor():return Vector2.ZERO
  return shield_face_world().direction_to(_project(shield.to_global(Vector3(0.,0.,.5))))
 func contact_point()->Vector2:return club_head_world()
 func tool_contact_world()->Vector2:return global_position+to_local(club_head_world())
