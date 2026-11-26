extends RefCounted
## Flower deer motions for the village lab only. The hunt actor remains the
## authority for the existing harvest visuals; this driver adds no game rules.
const STAG_POSE = preload("res://scripts/hunt_deer_approved_pose.gd")
const NATIVE = preload("res://gahui_trial/deer_lab_native.gd")
const ASSETS := "res://gahui_trial/deer_lab_assets/"
const ACTIONS := ["idle","walk","run","attack","skill","hit","heavy_hit"]
const MESH_HOOVES := ["frontToe.L","frontToe.R","rearToe.L","rearToe.R"]
const NATIVE_HOOVES := ["front_foot.L","front_foot.R","hind_foot.L","hind_foot.R"]
const WALK_STANCE := [[30.,14.],[8.,34.],[20.,9.],[0.,24.]]
const RUN_STANCE := [[0.,7.],[30.,39.],[16.,23.],[21.,27.]]
const SOLVE_HZ := 48.0

var body:Node3D
var target:Node3D
var origin:=Vector3.ZERO
var duration:=0.0
var active_action:=""
var actor:RefCounted
var _native:=NATIVE.new()
var _pivot:Node3D
var _calibration:=Transform3D.IDENTITY
var _clips:Dictionary={}
var _current:Dictionary={}
var _rest:Array[Transform3D]=[]
var _floor:Array[float]=[]
var _hit_baseline:Array[Quaternion]=[]
var _hit_mask:=PackedInt32Array()
var _hit_peak:=0.0
var _idle_reference:=Basis.IDENTITY
var _loc_origin:=Vector3.ZERO
var _heading:=Vector3.FORWARD
var _distance:=0.0
var _anchors:Dictionary={}
var _last_step:=-1
var _show_walk_phase:=.05
var _show_run_phase:=.40
var _show_travel:=0.0
var _ready:=false
var _show:=true
var _native_stag:=false

func setup(deer_actor: RefCounted, deer_body: Node3D, facing_target: Node3D, native_stag:=false) -> void:
 actor=deer_actor
 body=deer_body
 target=facing_target
 if not is_instance_valid(body) or actor==null or not is_instance_valid(actor.preview.pivot):return
 origin=body.position
 _native.setup(actor,body,target)
 _native_stag=native_stag
 if _native_stag:return
 _calibration=actor.preview.pivot.transform
 _pivot=Node3D.new()
 _pivot.name="LabFlowerDeerMotion"
 body.add_child(_pivot)
 _pivot.transform=_calibration
 _clips={
  "walk":_load_clip("1069.glb",MESH_HOOVES),
  "run":_load_clip("1070.glb",MESH_HOOVES),
  "quiet":_load_clip("1068.glb",MESH_HOOVES),
  "alert":_load_clip("1064.glb",MESH_HOOVES),
  "idle":_load_clip("idle-lookaround.glb",NATIVE_HOOVES),
  "heavy_hit":_load_clip("heavy-hit.glb",NATIVE_HOOVES)
 }
 for data:Dictionary in _clips.values():
  if data.is_empty():return
 var display:Skeleton3D=_clips.walk.sk
 for key:String in ["run","quiet","alert"]:
  var src:Skeleton3D=_clips[key].sk
  if src.get_bone_count()!=display.get_bone_count():return
  for k in display.get_bone_count():
   if src.get_bone_name(k)!=display.get_bone_name(k):return
 _rest=sample_pose(_clips.quiet,0.0)
 apply_pose(display,_rest)
 for k:int in _clips.walk.feet:_floor.append(_joint(_clips.walk,k).y-body.global_position.y)
 var native_idle:Dictionary=_clips.idle
 pose(native_idle,0.0)
 _idle_reference=native_idle.sk.get_bone_global_pose(native_idle.sk.find_bone("head")).basis
 _match_attack_scale()
 _prepare_hit()
 _ready=not _hit_mask.is_empty()
 if _ready:reset()

func _load_clip(file:String, hooves:Array) -> Dictionary:
 var resource:=load(ASSETS+file) as PackedScene
 if resource==null:return {}
 var instance:=resource.instantiate() as Node3D
 _pivot.add_child(instance)
 instance.hide()
 var players:=instance.find_children("*","AnimationPlayer",true,false)
 var skeletons:=instance.find_children("*","Skeleton3D",true,false)
 if players.is_empty() or skeletons.is_empty():return {}
 var player:=players[0] as AnimationPlayer
 var skeleton:=skeletons[0] as Skeleton3D
 var clip:StringName=&""
 for entry:StringName in player.get_animation_list():
  if entry!=&"RESET":
   clip=entry
   break
 if clip.is_empty():return {}
 player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 player.play(clip)
 player.advance(0.)
 var feet:=PackedInt32Array()
 for name:String in hooves:
  var id:=skeleton.find_bone(name)
  if id<0:return {}
  feet.append(id)
 return {"model":instance,"player":player,"sk":skeleton,"span":player.get_animation(clip).length,"feet":feet}

func pose(data:Dictionary,t:float)->void:
 data.player.seek(clampf(t,0.,data.span),true)
 data.sk.force_update_all_bone_transforms()

func _joint(data:Dictionary,id:int)->Vector3:
 return data.sk.to_global(data.sk.get_bone_global_pose(id).origin)

func _ground(data:Dictionary)->void:
 var low:=INF
 for id:int in data.feet:low=minf(low,_joint(data,id).y)
 _pivot.position.y+=body.global_position.y-low

# Match the two silhouettes from planted hooves, not pose-dependent antler height.
func _match_attack_scale()->void:
 var sk:Skeleton3D=actor.preview.skeleton
 var native:Array[Vector3]=[]
 for key:String in NATIVE_HOOVES:
  var id:=sk.find_bone(key)
  if id<0:return
  native.append(sk.to_global(sk.get_bone_global_pose(id).origin))
 var mesh:Array[Vector3]=[]
 for id:int in _clips.walk.feet:mesh.append(_joint(_clips.walk,id))
 var mesh_span:=_hoof_span(mesh)
 var native_span:=_hoof_span(native)
 if native_span>.01 and mesh_span>.01:
  var mesh_head:=_joint(_clips.walk,_clips.walk.sk.find_bone("head"))
  var native_head:=sk.to_global(sk.get_bone_global_pose(sk.find_bone("head")).origin)
  var mesh_bottom:=minf(minf(mesh[0].y,mesh[1].y),minf(mesh[2].y,mesh[3].y))
  var native_bottom:=minf(minf(native[0].y,native[1].y),minf(native[2].y,native[3].y))
  # Balance torso length with head height across the two different meshes.
  var height_ratio:float=(mesh_head.y-mesh_bottom)/maxf(.01,native_head.y-native_bottom)
  _native.visual_scale=actor.preview.pivot.scale*(mesh_span/native_span)*pow(clampf(height_ratio/(mesh_span/native_span),.4,3.7),.25)
  actor.preview.pivot.scale=_native.visual_scale

func _hoof_span(points:Array[Vector3])->float:
 var axis:Vector3=(points[0]+points[1]-points[2]-points[3])*.5
 return Vector2(axis.x,axis.z).length()

func fx_contact_time(action:String)->float:
 # The drill is non-damaging; time the cue against the authored strike.
 return duration*.44 if action=="attack" else NATIVE.REAR_ACTIVE+NATIVE.REAR_PAUSE+NATIVE.RAM_DRIVE_END

func fx_release_time()->float:
 return NATIVE.REAR_ACTIVE+NATIVE.REAR_PAUSE

func _prepare_hit()->void:
 var source:Skeleton3D=_clips.alert.sk
 pose(_clips.alert,0.0)
 for k in source.get_bone_count():
  var name:=source.get_bone_name(k).to_lower()
  if "neck" in name or "head" in name:
   _hit_mask.append(k)
   _hit_baseline.append(source.get_bone_pose_rotation(k))
 var peak:=0.0
 for frame in range(1,25):
  var at:=float(frame)/24.0
  pose(_clips.alert,at)
  var amount:=0.0
  for i in _hit_mask.size():amount+=_hit_baseline[i].angle_to(source.get_bone_pose_rotation(_hit_mask[i]))
  if amount>peak:
   peak=amount
   _hit_peak=at

func set_visible(visible:bool)->void:
 if visible==_show:return
 _show=visible
 if not is_instance_valid(body):return
 if _native_stag:restore_native()
 else:_present(active_action)

func restore_native()->void:
 if not is_instance_valid(body):return
 if is_instance_valid(_pivot):_pivot.hide()
 actor.preview.pivot.visible=_show

func _present(action:String)->void:
 if not is_instance_valid(_pivot):return
 var native_visual:=action in ["attack","skill"] or not _ready
 actor.preview.pivot.visible=_show and native_visual
 _pivot.visible=_show and not native_visual
 for data:Dictionary in _clips.values():
  if not data.is_empty():data.model.hide()
 if native_visual:return
 _current=_clips.heavy_hit if action=="heavy_hit" else _clips.walk
 _current.model.show()

func play(action:String)->bool:
 if (action not in ACTIONS and action!="locomotion") or not is_instance_valid(body):return false
 if _native_stag:
  _native.origin=body.position
  active_action=action
  if action=="idle":
   _native.reset()
   duration=1.00833
   return true
  if not _native.play(action):return false
  duration=_native.duration
  return true
 if not _ready:
  if action=="locomotion":return false
  if action=="idle":reset();return true
  var native_ok:=_native.play(action)
  if native_ok:
   duration=_native.duration
   active_action=action
  return native_ok
 active_action=action
 _last_step=-1
 _anchors.clear()
 _loc_origin=body.position
 if action in ["attack","skill"]:
  _native.origin=body.position
  if not _native.play(action):return false
  duration=_native.duration
 else:
  _pivot.transform=_calibration
  var to_target:Vector3=(body.get_parent() as Node3D).to_local(target.global_position)-body.position
  to_target.y=0.0
  _heading=to_target.normalized() if to_target.length_squared()>.001 else Vector3(sin(_calibration.basis.get_euler().y),0.,cos(_calibration.basis.get_euler().y))
  match action:
   "idle":duration=_clips.idle.span
   "locomotion":
    duration=6.65
    _distance=minf(11.3834937491,maxf(0.0,to_target.length()-NATIVE.MOVE_GAP))
    _pivot.rotation.y=atan2(_heading.x,_heading.z)
    _rewind_showcase()
   "walk","run":
    var running:=action=="run"
    duration=1.50 if running else 1.75
    _distance=minf(maxf(0.0,to_target.length()-NATIVE.MOVE_GAP),(5.35 if running else 2.05)*(duration-.38))
    _pivot.rotation.y=atan2(_heading.x,_heading.z)
   "hit":duration=.38
   "heavy_hit":duration=_clips.heavy_hit.span
 _present(action)
 sample(0.0)
 return true

func sample(seconds:float)->bool:
 if active_action.is_empty():return false
 if _native_stag:
  if active_action=="idle":
   actor.sample(0.0,false)
   actor.preview.pivot.position.y+=_native._floor_delta()
   STAG_POSE.apply(actor.preview.skeleton,"idle",seconds)
   return false
  var ended:=_native.sample(seconds)
  if active_action in ["walk","run","hit","heavy_hit"]:
   STAG_POSE.apply(actor.preview.skeleton,active_action,seconds)
   actor.preview.pivot.position.y+=_native._floor_delta()
  return ended
 if not _ready or active_action in ["attack","skill"]:return _native.sample(seconds)
 var age:=clampf(seconds,0.0,duration)
 match active_action:
  "idle":_idle_pose(fposmod(maxf(seconds,0.0),duration))
  "walk","run":
   var wanted:=floori(age*SOLVE_HZ)
   if wanted<_last_step:
    _anchors.clear()
    _last_step=-1
   while _last_step<wanted:
    _last_step+=1
    _gait(float(_last_step)/SOLVE_HZ)
   _gait(age)
  "locomotion":
   var wanted:=floori(age*SOLVE_HZ)
   if wanted<_last_step:
    _last_step=-1
    _rewind_showcase()
   while _last_step<wanted:
    _last_step+=1
    _showcase_frame(float(_last_step)/SOLVE_HZ)
  "hit":
   var data:Dictionary=_clips.walk
   var dst:Skeleton3D=data.sk
   var src:Skeleton3D=_clips.alert.sk
   apply_pose(dst,_rest)
   pose(_clips.alert,_hit_peak*sin(PI*age/duration))
   for i in _hit_mask.size():
    var k:=_hit_mask[i]
    var relative:=_hit_baseline[i].inverse()*src.get_bone_pose_rotation(k)
    dst.set_bone_pose_rotation(k,dst.get_bone_pose_rotation(k)*Quaternion.IDENTITY.slerp(relative,.75))
   dst.force_update_all_bone_transforms()
   _pivot.position.y=_calibration.origin.y
   _ground(data)
  "heavy_hit":
   _pivot.position.y=_calibration.origin.y
   pose(_clips.heavy_hit,age)
   _ground(_clips.heavy_hit)
 return active_action!="idle" and seconds>=duration

func _idle_pose(age:float)->void:
 var dest:Skeleton3D=_clips.walk.sk
 var src:Skeleton3D=_clips.idle.sk
 apply_pose(dest,_rest)
 pose(_clips.idle,fposmod(age*2.,float(_clips.idle.span)))
 var h:=src.find_bone("head")
 var yaw:=clampf((_idle_reference.inverse()*src.get_bone_global_pose(h).basis).get_euler().y,-.28,.28)
 for name in ["neck2","head"]:
  var id:=dest.find_bone(name)
  var bone:=dest.get_bone_global_pose(id)
  dest.set_bone_global_pose(id,Transform3D(Basis(Vector3.UP,yaw*(.6 if name=="head" else .4))*bone.basis,bone.origin))
  dest.force_update_all_bone_transforms()
 _pivot.position.y=_calibration.origin.y
 _ground(_clips.walk)

func _gait(t:float)->void:
 var running:=active_action=="run"
 var cycle:=.50 if running else float(_clips.walk.span)
 var data:Dictionary=_clips[active_action]
 var progress:=clampf(t/duration,0.0,1.0)
 var ramp:=.24
 var travel:=progress
 if progress<ramp:
  travel=progress*progress/(2.*ramp*(1.-ramp))
 elif progress>1.-ramp:
  travel=1.-pow(1.-progress,2.)/(2.*ramp*(1.-ramp))
 else:travel=(progress-.5*ramp)/(1.-ramp)
 body.position=_loc_origin+_heading*_distance*travel
 var blend:=smoothstep(0.,.22,t)*(1.-smoothstep(duration-.32,duration,t))
 var phase:=fposmod((.40 if running else .05)+t/cycle,1.0)
 var motion:=sample_pose(data,phase*float(data.span))
 if running and phase>.86:
  motion=blended(motion,sample_pose(data,0.0),smoothstep(.86,1.,phase))
 var display:Dictionary=_clips.walk
 var sk:Skeleton3D=display.sk
 apply_pose(sk,blended(_rest,motion,blend))
 _pivot.position.y=_calibration.origin.y+(.065 if running else -.085)*blend
 for i in display.feet.size():
  var k:int=display.feet[i]
  var raw:=_joint(display,k)
  var rule:Array=(RUN_STANCE if running else WALK_STANCE)[i]
  var weight:=st_weight(phase*40.,rule)*blend
  if weight<=0.0001:
   _anchors.erase(i)
   continue
  if not _anchors.has(i):
   var floor_y:=_floor[i]+body.global_position.y
   _anchors[i]=Vector3(raw.x,floor_y,raw.z)
  force_foot(sk,k,raw.lerp(_anchors[i],weight))
 if blend<.001:_ground(display)

func _rewind_showcase()->void:
 _anchors.clear()
 _show_travel=0.
 _show_walk_phase=.05
 _show_run_phase=.40

func _showcase_frame(t:float)->void:
 var go:=smoothstep(1.52,2.04,t)
 var sprint:=smoothstep(3.10,3.58,t)
 var stop:=smoothstep(4.56,5.18,t)
 var motion:=go*(1.-stop)
 var speed:=lerpf(2.05,5.35,sprint)*motion
 _show_travel+=speed/SOLVE_HZ
 body.position=_loc_origin+_heading*_distance*minf(1.,_show_travel/11.3834937491)
 if t<=1.52:
  _idle_pose(t)
  return
 var run_period:=.50
 var walk_period:=float(_clips.walk.span)
 _show_walk_phase=fposmod(_show_walk_phase+lerpf(.45,1.,motion)/(SOLVE_HZ*walk_period),1.)
 _show_run_phase=fposmod(_show_run_phase+lerpf(.55,1.,motion)/(SOLVE_HZ*run_period),1.)
 var walk_pose:=sample_pose(_clips.walk,_show_walk_phase*walk_period)
 var run_pose:=sample_pose(_clips.run,_show_run_phase*float(_clips.run.span))
 if _show_run_phase>.86:
  run_pose=blended(run_pose,sample_pose(_clips.run,0.),smoothstep(.86,1.,_show_run_phase))
 var sk:Skeleton3D=_clips.walk.sk
 apply_pose(sk,blended(_rest,blended(walk_pose,run_pose,sprint),motion))
 _pivot.position.y=_calibration.origin.y+lerpf(-.085,.065,sprint)*motion
 var running:=sprint>=.5
 var phase:=_show_run_phase if running else _show_walk_phase
 for i in _clips.walk.feet.size():
  var k:int=_clips.walk.feet[i]
  var raw:=_joint(_clips.walk,k)
  var rule:Array=(RUN_STANCE if running else WALK_STANCE)[i]
  var weight:=st_weight(phase*40.,rule) if motion>.94 and (sprint<.07 or sprint>.93) else 0.
  if weight<=.0001:
   _anchors.erase(i)
   continue
  if not _anchors.has(i):_anchors[i]=Vector3(raw.x,_floor[i]+body.global_position.y,raw.z)
  force_foot(sk,k,raw.lerp(_anchors[i],weight))
 if motion<.001:_ground(_clips.walk)

func reset()->void:
 if not is_instance_valid(body):return
 _native.origin=origin
 _native.reset()
 if _ready:
  active_action="idle"
  duration=_clips.idle.span
  _pivot.transform=_calibration
  _present("idle")
  sample(0.0)
 else:
  active_action=""
  duration=0.0
  restore_native()
func snapshot(sk:Skeleton3D)->Array[Transform3D]:
 var result:Array[Transform3D]=[]
 for k in sk.get_bone_count():result.append(sk.get_bone_pose(k))
 return result
func blended(a:Array[Transform3D],b:Array[Transform3D],u:float)->Array[Transform3D]:
 var r:Array[Transform3D]=[]
 for k in a.size():r.append(a[k].interpolate_with(b[k],u))
 return r
func apply_pose(sk:Skeleton3D,src:Array[Transform3D])->void:
 for k in src.size():
  sk.set_bone_pose(k,src[k])
 sk.force_update_all_bone_transforms()
func sample_pose(data:Dictionary,t:float)->Array[Transform3D]:
 pose(data,t)
 return snapshot(data.sk)
func force_foot(sk:Skeleton3D,foot:int,world:Vector3)->void:
 var goal:=sk.to_local(world)
 var short:=sk.get_bone_parent(foot)
 var mid:=sk.get_bone_parent(short)
 var long:=sk.get_bone_parent(mid)
 var prior:=sk.get_bone_global_pose(foot).basis
 for round in range(8):
  for k:int in [mid,long,short]:
   var a:=sk.get_bone_global_pose(k)
   var from:=sk.get_bone_global_pose(foot).origin-a.origin
   var to:=goal-a.origin
   if minf(from.length_squared(),to.length_squared())<.000001:continue
   var delta:=Quaternion(from.normalized(),to.normalized())
   var capped:=Quaternion.IDENTITY.slerp(delta,minf(1.,.28/maxf(delta.get_angle(),.0001)))
   sk.set_bone_global_pose(k,Transform3D(Basis(capped)*a.basis,a.origin))
   sk.force_update_all_bone_transforms()
 var current:=sk.get_bone_global_pose(foot)
 sk.set_bone_global_pose(foot,Transform3D(prior,current.origin))
 sk.force_update_all_bone_transforms()
func st_weight(frame:float,rule:Array)->float:
 var delta:=fposmod(frame-float(rule[0]),40.)
 var len:=fposmod(float(rule[1])-float(rule[0]),40.)
 if delta>len:return 0.
 return smoothstep(0.,2.6,delta)*smoothstep(0.,2.6,len-delta)
