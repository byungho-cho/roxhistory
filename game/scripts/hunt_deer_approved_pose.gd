extends RefCounted
## Visual retarget: no center/root translation, attacks, strike clocks or VFX events.
const DATA := preload("res://assets/animals/deer-motion/poses.json")
const FEET := ["front_foot.L","front_foot.R","hind_foot.L","hind_foot.R"]
const UPPER := ["trunk","neck","head"]
const HEAVY_BONES := ["trunk","neck","head","tail","front_upper.R","front_shin.R","front_foot.R","hind_upper.R","hind_shin.R","hind_foot.R","front_upper.L","front_shin.L","front_foot.L","hind_upper.L","hind_shin.L","hind_foot.L"]
const WALK_STANCE := [[30.,14.],[8.,34.],[20.,9.],[0.,24.]]
const RUN_STANCE := [[0.,7.],[30.,39.],[16.,23.],[21.,27.]]
static var poses: Dictionary = DATA.data

static func supports(species: String) -> bool:
 return species in ["forest","stag"]

static func apply(rig: Skeleton3D, move: String, age: float, weight:=1.0, keep_collider:=false) -> void:
 if not is_instance_valid(rig) or weight<=0.0 or move not in ["idle","walk","run","hit","heavy_hit"]:return
 if poses.is_empty():return
 match move:
  "idle":
   # Approved lookaround at 2x. Keep the chest, roots and four planted feet.
   var phase:=fposmod(age*2.,float(poses.idle_seconds))/float(poses.idle_seconds)
   _head_pose(rig,poses.idle,phase,weight,false)
  "hit":
   # The lab uses the strongest authored alert neck motion, up and back.
   var frames:Array=poses.light
   var phase:=sin(PI*clampf(age/.38,0.,1.))
   var peak_i:=0
   for j in frames.size():
    if float(frames[j])>float(frames[peak_i]):peak_i=j
   var at:=phase*float(peak_i)
   var n:=floori(at)
   var light:=lerpf(float(frames[n]),float(frames[mini(n+1,peak_i)]),at-float(n))
   _light_hit(rig,clampf(light/maxf(.001,float(frames[peak_i])),0.,1.)*weight)
  "heavy_hit":
   _head_pose(rig,poses.heavy,clampf(age/.74,0.,1.),weight,true,keep_collider)
  "walk","run":
   _gait(rig,move,age,weight)

static func _light_hit(rig:Skeleton3D, amount:float)->void:
 for key:String in ["neck","head"]:
  var index:=rig.find_bone(key)
  if index<0:continue
  var bone:=rig.get_bone_global_pose(index)
  var upward:=Basis(Vector3.RIGHT,-(.15 if key=="neck" else .09)*amount)
  rig.set_bone_global_pose(index,Transform3D(upward*bone.basis,bone.origin))
 rig.force_update_all_bone_transforms()

static func _head_pose(rig: Skeleton3D, frames: Array, phase: float, weight: float, heavy: bool, keep_collider:=false) -> void:
 var at:=phase*float(frames.size()-1)
 var n:=floori(at)
 var keys:=HEAVY_BONES if heavy else UPPER
 for i in range(0 if heavy and not keep_collider else 1,mini(keys.size(),frames[n].size())):
  var id:=rig.find_bone(keys[i])
  if id<0:continue
  var a:Array=frames[n][i]
  var b:Array=frames[mini(n+1,frames.size()-1)][i]
  var q:=Quaternion(a[0],a[1],a[2],a[3]).normalized().slerp(Quaternion(b[0],b[1],b[2],b[3]).normalized(),at-float(n))
  var rest:=rig.get_bone_rest(id).basis.get_rotation_quaternion()
  if not heavy:q=Quaternion.IDENTITY.slerp(q,.74)
  var prior:=rig.get_bone_pose_rotation(id)
  rig.set_bone_pose_rotation(id,prior.slerp(rest*q,clampf(weight,0.,1.)))
 rig.force_update_all_bone_transforms()

static func _gait(rig: Skeleton3D, move: String, age: float, weight: float) -> void:
 var gait:Array=poses[move]
 var running:=move=="run"
 var phase:=fposmod((.40 if running else .05)+age/(.50 if running else .91),1.)
 var at:=phase*float(gait.size())
 var n:=floori(at)
 var rest_feet:Array[Vector3]=[]
 var feet:=PackedInt32Array()
 for key:String in FEET:
  var id:=rig.find_bone(key)
  if id<0:return
  feet.append(id)
  rest_feet.append(rig.get_bone_global_rest(id).origin)
 var forward:Vector3=(rest_feet[0]+rest_feet[1]-rest_feet[2]-rest_feet[3])*.5
 forward.y=0.
 var stride:=forward.length()
 if stride<=.01:return
 forward/=stride
 var right:=Vector3.UP.cross(forward)
 var lo:=INF
 for id in feet:lo=minf(lo,rig.get_bone_global_pose(id).origin.y)
 for i in 4:
  var a:Array=gait[n][i]
  var b:Array=gait[(n+1)%gait.size()][i]
  var v:=Vector3(a[0],a[1],a[2]).lerp(Vector3(b[0],b[1],b[2]),at-float(n))
  var stance:Array=(RUN_STANCE if running else WALK_STANCE)[i]
  var stance_at:=fposmod(phase*40.-float(stance[0]),40.)
  var stance_span:=fposmod(float(stance[1])-float(stance[0]),40.)
  var planted:=smoothstep(0.,2.6,stance_at)*(1.-smoothstep(stance_span-2.6,stance_span,stance_at))
  var target:=rest_feet[i]+stride*(right*clampf(v.x,-.12,.12)*.32+forward*clampf(v.z,-.70,.70)*.63)
  target.y=lo+stride*(1.-planted)*clampf(v.y,0.,.23)
  _solve_hoof(rig,feet[i],rig.get_bone_global_pose(feet[i]).origin.lerp(target,weight*.82))

# Finish the approved ram's hoof landing on the native surface. Only the
# two leg chains are adjusted; head, trunk and gameplay sweep stay untouched.
static func ram_landing(rig: Skeleton3D, ram_age: float) -> void:
 if not is_instance_valid(rig) or ram_age<.30 or ram_age>.49:return
 for i in FEET.size():
  var id:=rig.find_bone(FEET[i])
  if id<0:continue
  var goal:=rig.get_bone_global_pose(id).origin
  var floor_y:=rig.get_bone_global_rest(id).origin.y
  var land_at:float=(.438 if i<2 else .328)+(.014 if i%2==1 else 0.)
  var land_weight:=smoothstep(land_at-.043,land_at+.008,ram_age)*(1.-smoothstep(.465,.49,ram_age))
  if land_weight<=.001:continue
  goal.y=lerpf(goal.y,floor_y,land_weight)
  _solve_hoof(rig,id,goal)

static func _solve_hoof(sk: Skeleton3D, hoof: int, goal: Vector3) -> void:
 var shin:=sk.get_bone_parent(hoof)
 var upper:=sk.get_bone_parent(shin)
 if upper<0:return
 var a:=sk.get_bone_global_pose(upper)
 var b:=sk.get_bone_global_pose(shin)
 var c:=sk.get_bone_global_pose(hoof)
 var ab:=b.origin-a.origin
 var bc:=c.origin-b.origin
 var first:=ab.length()
 var second:=bc.length()
 if minf(first,second)<.0001:return
 var dir:=(goal-a.origin).normalized()
 if dir.is_zero_approx():return
 var reach:=clampf(goal.distance_to(a.origin),absf(first-second)+.0001,first+second-.0001)
 var axial:=(first*first-second*second+reach*reach)/(2.*reach)
 var pole:=ab.slide(dir).normalized()
 if pole.is_zero_approx():pole=Vector3.FORWARD.slide(dir).normalized()
 var knee:=a.origin+dir*axial+pole*sqrt(maxf(first*first-axial*axial,0.))
 sk.set_bone_global_pose(upper,Transform3D(Basis(Quaternion(ab.normalized(),(knee-a.origin).normalized()))*a.basis,a.origin))
 var next:=sk.get_bone_global_pose(shin)
 var foot:=sk.get_bone_global_pose(hoof)
 sk.set_bone_global_pose(shin,Transform3D(Basis(Quaternion((foot.origin-next.origin).normalized(),(a.origin+dir*reach-knee).normalized()))*next.basis,next.origin))
 sk.set_bone_global_pose(hoof,Transform3D(c.basis,sk.get_bone_global_pose(hoof).origin))
 sk.force_update_all_bone_transforms()
