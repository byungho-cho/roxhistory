extends Node3D
const LABELS := ["대기", "걷기", "달리기", "평타", "2SP 물화살", "3SP 광역 치유", "피격"]
const TIMES := [1.6, 2.2, 2.0, 1.45, 2.15, 2.15, 1.6]
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
var bolt: MeshInstance3D
var rings: Array[MeshInstance3D] = []
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
 var shape := SphereMesh.new()
 shape.radius = .062
 shape.height = .124
 bolt = mesh_obj(shape,Color("#67dcff"),true)
 bolt.top_level = true
 bolt.hide()
 for i in range(3):
  var ring := TorusMesh.new()
  ring.inner_radius = .94
  ring.outer_radius = 1.0
  ring.rings = 44
  ring.ring_segments = 8
  rings.append(mesh_obj(ring,Color("#72e8de"),true))
  rings[-1].hide()
 rig_ready = players[0].has_animation(&"locomotion/run")
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
 active_clip = names[2] if i==1 else names[3] if i==2 else names[1] if i==6 else names[0]
 var p := players[0]
 p.stop()
 p.play(active_clip)
 p.advance(0.0)
 p.seek(.15 if i in [3,4,5] else 0.0,true)
 sk.force_update_all_bone_transforms()
 for key in ["Spine","Spine01","Head","RightArm","RightForeArm","RightHand","LeftArm","LeftForeArm"]:
  var id := sk.find_bone(key)
  base[key] = sk.get_bone_pose_rotation(id)
  refs[key] = (sk.global_transform.basis * sk.get_bone_global_pose(id).basis).orthonormalized()

func actor_for(_i:int)->int:
 return 0

func step_at(t:float):
 elapsed=t
 if active in [1,2]:
  var travel := minf(t* (1.02 if active==1 else 2.2), 2.3)
  position = origin + (target_body.position-origin).slide(Vector3.UP).normalized()*travel
 draw_frame(t)
 soften_entry()

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

func match_clip(clips: Array[StringName], needle: String) -> StringName:
 for clip in clips:
  if String(clip).to_lower().contains(needle):
   return clip
 return &""

func mesh_obj(shape: Mesh, color: Color, luminous: bool) -> MeshInstance3D:
 var obj := MeshInstance3D.new()
 obj.mesh = shape
 var mat := StandardMaterial3D.new()
 mat.albedo_color = color
 if luminous:
  mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 obj.material_override = mat
 add_child(obj)
 return obj


func soften_entry():
 if transition.is_empty() or elapsed >= .22: return
 var sk := skeletons[0]
 var mix := smoothstep(0.0, .22, elapsed)
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
 bolt.hide()
 for ring in rings: ring.hide()
 var p := players[actor_for(active)]
 if not active in [3,4,5]:
  var name := active_clip
  if not name.is_empty():
   if p.current_animation != name:
    p.play(name)
    p.advance(0.0)
   var len := p.get_animation(name).length
   var sample := minf(t,len-.002) if active == 6 else fposmod(t,len)
   if active == 2:
    var first_key := 1.0 / 30.0
    sample = first_key + fposmod(t + .00005, len - first_key)
   p.seek(sample, true)
  return
 var sk := skeletons[0]
 p.seek(.15, true)
 var wind := bump(t,.32,.26)
 var push := 0.0
 var lift := 0.0
 var pulses: Array[float] = [.67]
 if active == 4:
  pulses = [.63, 1.06, 1.54]
  wind = bump(t,.29,.27) + .24*bump(t,.84,.17) + .38*bump(t,1.29,.19)
 elif active == 5:
  pulses = []
  lift = bump(t,.93,.78)
  wind = bump(t,.31,.27)
 for k in range(pulses.size()):
  var strength := (1.16 if k == 2 else .88) if active == 4 else .66
  push += strength*bump(t,pulses[k],.25)
 twist("Spine", Vector3(0,1,0), 9.0*wind-14.0*push)
 twist("Spine01", Vector3(1,0,0), 3.0*wind-9.0*push-9.0*lift)
 twist("Head", Vector3(0,1,0), -7.0*wind+5.0*push)
 twist("RightArm", Vector3(1,0,0), -15.0*wind-67.0*push-41.0*lift)
 twist("RightForeArm", Vector3(1,0,0), -21.0*wind+25.0*push-22.0*lift)
 twist("RightHand", Vector3(1,0,0), -2.0*wind+2.0*push)
 twist("LeftArm", Vector3(0,0,1), 6.0*wind+4.0*push+40.0*lift)
 twist("LeftForeArm", Vector3(1,0,0), -9.0*wind+6.0*push-18.0*lift)
 sk.force_update_all_bone_transforms()
 for k in range(pulses.size()):
  if t < pulses[k]: continue
  if not launches.has(k):
   var start := staff_tip()
   launches[k] = start
   shot_started.emit(start)
  var flight := (t-pulses[k])/.28
  if flight >= 1.0:
   if hits == k:
    hits+=1
    shot_arrived.emit(k)
   continue
  var start: Vector3 = launches[k]
  var finish:=target_body.global_position+Vector3.UP*.95
  var strength := 1.32 if active==4 and k==2 else 1.0
  bolt.global_position = start.lerp(finish,flight)
  if bolt.global_position.distance_squared_to(finish)>.000001:
   bolt.look_at(finish,Vector3.UP,true)
  bolt.scale = Vector3(.55,.55,2.6)*strength
  bolt.show()
 if active == 5:
  for i in range(rings.size()):
   var f := (t-.83-float(i)*.16)/.70
   if f < 0.0 or f >= 1.0: continue
   rings[i].scale = Vector3(1, .35, 1)*(.18 + .90*f)
   rings[i].position = Vector3(0,.025+f*.30,0)
   rings[i].show()

