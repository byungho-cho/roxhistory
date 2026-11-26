extends Node3D
const LABELS := ["대기", "걷기", "달리기", "평타", "2SP 물화살", "3SP 광역 치유", "일반 피격", "강한 피격"]
const BASIC_RELEASE := .67
const BARRAGE_LEAD_IN := 1.17
const BARRAGE_LOCAL_DURATION := 2.15
const TWO_SP_RELEASES := [.63, 1.06, 1.54]
const FLIGHT_SECONDS := .28
const HEAL_RELEASE := 29.0 / 30.0
const HEAL_DURATION := 74.0 / 30.0
const STRONG_HIT := 7
const STRONG_HIT_RECOVERY := 1.04
const HEAL_CLIP := &"meshy/heal"
const HEAL_ROTATIONS := preload("res://gahui_trial/meshy-heal-upper.res")
# Only rotations in this upper-body set may change for the Meshy 3SP preview.
const UPPER_BONES := [&"Spine", &"Spine01", &"Spine02", &"neck", &"Head", &"LeftShoulder", &"RightShoulder", &"LeftArm", &"RightArm", &"LeftForeArm", &"RightForeArm", &"LeftHand", &"RightHand"]
const HIT_RECOVERY := 1.12
const HIT_BONES := [&"Spine", &"Spine01", &"Spine02", &"Neck", &"Head", &"LeftShoulder", &"RightShoulder", &"LeftArm", &"RightArm", &"LeftForeArm", &"RightForeArm", &"LeftHand", &"RightHand"]
const TIMES := [1.6, 2.2, 2.0, 1.45, BARRAGE_LEAD_IN+BARRAGE_LOCAL_DURATION, HEAL_DURATION, HIT_RECOVERY, 1.17]
const DISPLAY_HEIGHT := 2.33
const STAFF_NAMES := ["RightArm", "RightForeArm", "RightHand"]
# Upper ornament landmark, sampled from the exact GLB and converted into the three weighted joint-local spaces.
const STAFF_POINTS := [Vector3(-4.006,26.77463,19.57927), Vector3(.80739,11.85663,17.98225), Vector3(-3.95062,-5.70762,16.8856)]
const STAFF_WEIGHTS := [.047,.489,.464]
var models: Array[Node3D] = []
var players: Array[AnimationPlayer] = []
var skeletons: Array[Skeleton3D] = []
var names: Array[StringName] = []
var active_clip: StringName
var active := -1
var elapsed := 0.0
var base := {}
var refs := {}
var transition: Array[Transform3D] = []
var hit_anchor: Array[Transform3D] = []
var heal_anchor: Array[Transform3D] = []
var target := Vector3(3,1,0)
var launches := {}
var hits := 0
var origin := Vector3.ZERO
var target_body: Node3D
var rig_ready := false
signal shot_started(point:Vector3)
signal shot_arrived(index:int)

func initialize(deer:Node3D):
 target_body = deer
 var model := (load("res://gahui_trial/presets.glb") as PackedScene).instantiate() as Node3D
 add_child(model)
 var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
 var bounds := mesh.get_aabb()
 model.scale = Vector3.ONE * (DISPLAY_HEIGHT / bounds.size.y)
 model.position.y = -bounds.position.y*model.scale.y
 models.append(model)
 var player := model.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer
 player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 players.append(player)
 skeletons.append(model.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D)
 var clips: Array[StringName] = []
 for key in player.get_animation_list():
  if not String(key).ends_with("RESET"): clips.append(key)
 names.append(match_clip(clips,"idle"))
 names.append(match_clip(clips,"hit"))
 names.append(&"locomotion/walk")
 names.append(&"locomotion/run")
 merge_locomotion()
 install_heal_clip()
 rig_ready = players[0].has_animation(&"locomotion/run") and players[0].has_animation(HEAL_CLIP)
 switch_to(0)

func switch_to(i:int):
 var sk := skeletons[0]
 transition.clear()
 if active >= 0:
  for id in range(sk.get_bone_count()):
   transition.append(sk.get_bone_pose(id))
 active = i
 elapsed = 0.0
 launches.clear()
 hits = 0
 origin = position
 active_clip = names[2] if i==1 else names[3] if i==2 else HEAL_CLIP if i==5 else names[1] if i in [6,STRONG_HIT] else names[0]
 var p := players[0]
 p.stop()
 if i in [5,6,STRONG_HIT]:
  p.play(names[0])
  p.advance(0.0)
  p.seek(0.0, true)
  sk.force_update_all_bone_transforms()
  var anchor := heal_anchor if i==5 else hit_anchor
  anchor.clear()
  for id in range(sk.get_bone_count()):
   anchor.append(sk.get_bone_pose(id))
 p.play(active_clip)
 p.advance(0.0)
 p.seek(.15 if i in [3,4] else 0.0,true)
 sk.force_update_all_bone_transforms()
 for key in ["Spine","Spine01","Head","RightArm","RightForeArm","RightHand","LeftArm","LeftForeArm","RightShoulder","LeftShoulder"]:
  var id := sk.find_bone(key)
  base[key] = sk.get_bone_pose_rotation(id)
  refs[key] = (sk.global_transform.basis * sk.get_bone_global_pose(id).basis).orthonormalized()

func actor_for(_i:int)->int:
 return 0

func step_at(t:float):
 elapsed=t
 if active in [1,2]:
  draw_locomotion(t)
  soften_entry()
  return
 draw_frame(clampf(t-BARRAGE_LEAD_IN,0.0,BARRAGE_LOCAL_DURATION) if active==4 else t)
 if active != STRONG_HIT: soften_entry()
 if active == 4 and t < 1.30: draw_barrage_gather(t)

# Match the approved hunting preview: animation cadence and ground speed slow together.
func draw_locomotion(t:float) -> void:
 var factor := .68 if active == 1 else .50
 var speed := (3.11 if active == 1 else 11.08) * factor
 var stop := 2.03 if active == 1 else 1.16
 var u := clampf(t-stop+.24,0.0,.24)
 var travel_time := t if t < stop-.24 else stop-.24+u-.5*u*u/.24
 var direction := (target_body.position-origin).slide(Vector3.UP).normalized()
 position = origin + direction*speed*travel_time
 if t <= stop:
  draw_frame(travel_time*factor)
  return
 var p := players[0]
 var sk := skeletons[0]
 var rest_time := t-stop
 var departure: Array[Transform3D] = []
 if rest_time < .22:
  draw_frame(travel_time*factor)
  for i in sk.get_bone_count(): departure.append(sk.get_bone_pose(i))
 if p.current_animation != names[0]:
  p.play(names[0])
  p.advance(0.0)
 p.seek(fposmod(rest_time,p.get_animation(names[0]).length),true)
 if not departure.is_empty():
  var mix := smoothstep(0.0,.22,rest_time)
  for i in departure.size():
   sk.set_bone_pose(i,departure[i].interpolate_with(sk.get_bone_pose(i),mix))
 sk.force_update_all_bone_transforms()

func ground_contact() -> Vector3:
 var sk := skeletons[0]
 sk.force_update_all_bone_transforms()
 var l := sk.find_bone("LeftToeBase")
 var r := sk.find_bone("RightToeBase")
 if l < 0 or r < 0: return global_position
 var contact := sk.to_global((sk.get_bone_global_pose(l).origin+sk.get_bone_global_pose(r).origin)*.5)
 contact.y = global_position.y
 return contact

func staff_tip()->Vector3:
 var sk:=skeletons[0]
 var point:=Vector3.ZERO
 for i in range(STAFF_NAMES.size()):
  var id:=sk.find_bone(STAFF_NAMES[i])
  point += (sk.get_bone_global_pose(id) * STAFF_POINTS[i]) * float(STAFF_WEIGHTS[i])
 return sk.to_global(point)

func merge_locomotion():
 var library := AnimationLibrary.new()
 var player := players[0]
 var skeleton_path := player.get_node(player.root_node).get_path_to(skeletons[0])
 for action in ["walk","run"]:
  var clip := (load("res://gahui_trial/"+action+".res") as Animation).duplicate() as Animation
  for idx in clip.get_track_count():
   var path := clip.track_get_path(idx)
   if path.get_subname_count()==0: continue
   clip.track_set_path(idx, NodePath(String(skeleton_path)+":"+String(path.get_subname(0))))
  clip.loop_mode=Animation.LOOP_LINEAR
  library.add_animation(action,clip)
 player.add_animation_library(&"locomotion",library)
 player.get_animation(names[0]).loop_mode=Animation.LOOP_LINEAR

func install_heal_clip() -> void:
 var player := players[0]
 var skeleton_path := player.get_node(player.root_node).get_path_to(skeletons[0])
 var clip := HEAL_ROTATIONS.duplicate() as Animation
 for idx in clip.get_track_count():
  var bone := clip.track_get_path(idx).get_subname(0)
  clip.track_set_path(idx, NodePath(String(skeleton_path)+":"+String(bone)))
 var library := AnimationLibrary.new()
 library.add_animation(&"heal",clip)
 player.add_animation_library(&"meshy",library)

func match_clip(clips: Array[StringName], needle: String) -> StringName:
 for clip in clips:
  if String(clip).to_lower().contains(needle):
   return clip
 return &""

func soften_entry():
 if transition.is_empty() or elapsed >= (.10 if active == 6 else .22): return
 var sk := skeletons[0]
 var mix := smoothstep(0.0, .10 if active == 6 else .22, elapsed)
 for id in range(transition.size()):
  var blended := transition[id].interpolate_with(sk.get_bone_pose(id),mix)
  sk.set_bone_pose_position(id,blended.origin)
  sk.set_bone_pose_rotation(id,blended.basis.get_rotation_quaternion())
  sk.set_bone_pose_scale(id,blended.basis.get_scale())

func twist(key: String, axis: Vector3, degrees: float):
 var sk := skeletons[0]
 var id := sk.find_bone(key)
 var frame: Basis = refs[key]
 var q: Quaternion = base[key]
 sk.set_bone_pose_rotation(id, (q * Quaternion((frame.inverse() * axis).normalized(), deg_to_rad(degrees))).normalized())

func bump(t: float, at: float, span: float) -> float:
 var x := clampf(absf(t-at)/span, 0.0, 1.0)
 return .5 + .5*cos(PI*x)

func draw_frame(t: float):
 var p := players[actor_for(active)]
 if active == 6:
  draw_hit(t, p)
  return
 if active == STRONG_HIT:
  draw_strong_hit(t, p)
  return
 if active == 5:
  draw_heal(t, p)
  return
 if not active in [3,4]:
  var name := active_clip
  if not name.is_empty():
   if p.current_animation != name:
    p.play(name)
    p.advance(0.0)
   var len := p.get_animation(name).length
   var sample := fposmod(t,len)
   if active == 2:
    var first_key := 1.0 / 30.0
    sample = first_key + fposmod(t + .00005, len - first_key)
   p.seek(sample, true)
  return
 var sk:=skeletons[0]
 players[0].seek(.15,true)
 var pulses:Array=[BASIC_RELEASE] if active==3 else TWO_SP_RELEASES
 var prepare:float=0.
 var drive:float=0.
 var finish:float=0.
 for n in range(pulses.size()):
  var release:float=pulses[n]
  var accent:float=[.76,.83,1.12][n] if active==4 else .88
  var width:float=.25 if n==0 else .16
  prepare+=accent*bump(t,release-.19,width*.54)
  # Asymmetric strike: accelerate into release, then decay into the hold instead of snapping straight back.
  var attack:=smoothstep(release-.17,release-.025,t)*(1.-smoothstep(release+.025,release+.146,t))
  drive+=accent*attack
  finish+=accent*bump(t,release+.097,.12 if n<pulses.size()-1 else .21)
 var facing:=global_basis.orthonormalized()
 var forward:=facing.z
 var right:=facing.x
 var vertical:=facing.y
 twist("Spine",vertical,9.0*prepare-11.0*drive-4.5*finish)
 twist("Spine01",right,-4.0*prepare-13.0*drive-4.0*finish)
 twist("Head",vertical,-5.5*prepare+5.0*drive+3.0*finish)
 twist("RightShoulder",vertical,6.0*prepare-9.0*drive-4.5*finish)
 twist("RightArm",right,-16.0*prepare-62.0*drive-19.0*finish)
 twist("RightForeArm",right,-21.0*prepare+22.0*drive+8.0*finish)
 twist("RightHand",right,-1.5*prepare+1.8*drive+1.0*finish)
 twist("LeftShoulder",vertical,-2.0*prepare+4.0*drive)
 twist("LeftArm",forward,5.0*prepare-4.0*drive+4.0*finish)
 twist("LeftForeArm",right,-5.0*prepare+3.0*drive)
 sk.force_update_all_bone_transforms()
 for i in pulses.size():
  var elapsed_since:float=t-float(pulses[i])
  if elapsed_since<-0.00001: continue
  if not launches.has(i):
   var start:=staff_tip()
   launches[i]=start
   shot_started.emit(start)
  if elapsed_since>=FLIGHT_SECONDS and hits==i:
   hits+=1
   shot_arrived.emit(i)

func draw_barrage_gather(t:float) -> void:
 var gather := smoothstep(.62,1.03,t)*(1.0-smoothstep(1.12,1.31,t))
 if gather <= 0.0: return
 var side := global_basis.x.normalized()
 var yaw := global_basis.y.normalized()
 twist("Spine",yaw,7.0*gather)
 twist("RightArm",side,-19.0*gather)
 twist("RightForeArm",side,-22.0*gather)
 skeletons[0].force_update_all_bone_transforms()

func draw_hit(t:float, player:AnimationPlayer) -> void:
 if active_clip.is_empty() or hit_anchor.is_empty(): return
 var sk := skeletons[0]
 var clip_length := player.get_animation(active_clip).length
 player.seek(minf(t / HIT_RECOVERY * clip_length, clip_length-.002), true)
 var recoil := .50 * smoothstep(0.0, .10, t) * (1.0-smoothstep(.51, HIT_RECOVERY, t))
 for id in range(hit_anchor.size()):
  var anchor := hit_anchor[id]
  var neutral := anchor.basis.get_rotation_quaternion()
  var sampled := sk.get_bone_pose_rotation(id)
  sk.set_bone_pose_position(id, anchor.origin)
  sk.set_bone_pose_scale(id, anchor.basis.get_scale())
  sk.set_bone_pose_rotation(id, neutral.slerp(sampled, recoil) if sk.get_bone_name(id) in HIT_BONES else neutral)
 sk.force_update_all_bone_transforms()

func draw_heal(t:float, player:AnimationPlayer) -> void:
 if heal_anchor.is_empty(): return
 var sk:=skeletons[0]
 var clip_length:=player.get_animation(HEAL_CLIP).length
 player.seek(clampf(t,0.0,clip_length-.001),true)
 var blend:=smoothstep(0.0,.25,t)*(1.0-smoothstep(clip_length-.40,clip_length,t))
 for i in heal_anchor.size():
  var start:=heal_anchor[i]
  var neutral:=start.basis.get_rotation_quaternion()
  var sampled:=sk.get_bone_pose_rotation(i)
  sk.set_bone_pose_position(i,start.origin)
  sk.set_bone_pose_scale(i,start.basis.get_scale())
  sk.set_bone_pose_rotation(i,neutral.slerp(sampled,blend) if sk.get_bone_name(i) in UPPER_BONES else neutral)
 sk.force_update_all_bone_transforms()

func draw_strong_hit(t:float, player:AnimationPlayer) -> void:
 const STEP_START:=.155
 const STEP_END:=.48
 const RETURN_START:=.57
 const STRIDE:=.54
 var recoil_start:=smoothstep(.014,.077,t)
 var refractory:=1.0-smoothstep(.23,.70,t)
 var force:=.92*recoil_start*refractory
 var retreat:=smoothstep(STEP_START,STEP_END,t)
 var recover:=smoothstep(RETURN_START,STRONG_HIT_RECOVERY,t)
 # The impact first snaps the upper body. Start the single backstep only after the initial flinch.
 var stumble:=pow(retreat,1.32)
 position=origin-transform.basis.z*STRIDE*(stumble-recover)
 var sk:=skeletons[0]
 if t>=STRONG_HIT_RECOVERY:
  for i in hit_anchor.size():
   sk.set_bone_pose(i,hit_anchor[i])
  sk.force_update_all_bone_transforms()
  return
 var upper:Dictionary={}
 if force>.001 and not names[1].is_empty():
  player.play(names[1])
  player.advance(0.0)
  var impact_frame:=.08+.45*smoothstep(.01,.23,t)+.10*smoothstep(.26,.53,t)
  player.seek(impact_frame,true)
  for i in hit_anchor.size():
   if sk.get_bone_name(i) in UPPER_BONES:
    upper[i]=hit_anchor[i].basis.get_rotation_quaternion().slerp(sk.get_bone_pose_rotation(i),force)
 var phase:float=retreat if t<RETURN_START else recover
 var step_weight:float=smoothstep(0.0,.24,phase)*(1.0-smoothstep(.69,1.0,phase))
 if step_weight>.001:
  player.play(names[2])
  player.advance(0.0)
  var span:float=player.get_animation(names[2]).length
  var sample:=lerpf(.66,.16,phase) if t<RETURN_START else lerpf(.16,.66,phase)
  player.seek(span*sample,true)
 for i in hit_anchor.size():
  var neutral:=hit_anchor[i]
  if sk.get_bone_name(i) in UPPER_BONES:
   sk.set_bone_pose(i,neutral)
   if upper.has(i): sk.set_bone_pose_rotation(i,upper[i])
  elif step_weight>.001:
   sk.set_bone_pose(i,neutral.interpolate_with(sk.get_bone_pose(i),step_weight))
  else:
   sk.set_bone_pose(i,neutral)
 sk.force_update_all_bone_transforms()
