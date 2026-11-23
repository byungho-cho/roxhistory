extends RefCounted

const BEAT_DAMAGE := [5,5,6,11]

static func damage_at(beat:int,rallied:bool)->int:
 if beat<0 or beat>=BEAT_DAMAGE.size():return 0
 if not rallied:return BEAT_DAMAGE[beat]
 var previous:=0
 for i in beat:previous+=int(BEAT_DAMAGE[i])
 # Cumulative rounding reconciles the visible hits to 27 × 1.20 = 32.
 return roundi(float(previous+int(BEAT_DAMAGE[beat]))*1.2)-roundi(float(previous)*1.2)
## Deterministic poses and drawing for the approved close-range stone-knife presentation.
## The caller owns action interrupts, damage, and actual combat nodes.
const times:Array[float]=[.67,.89,1.10,1.46]
const contacts:Array[float]=[21.0/30.,27.0/30.,33.0/30.,44.0/30.]
const DURATION:=1.94
const ECHO_SECONDS:=.59

static func cam_for(v:HybridCharacter)->Camera3D:
 if v.has_meta("duel_world"):return v.get_meta("duel_world").camera
 return v.camera

static func show_basic(u:Dictionary,e:Dictionary,p:float)->Vector2:
 var edge:=sample_basic(u,e,p)
 var aim:=smoothstep(.10,.44,p)*(1.-smoothstep(.53,.87,p))
 blade(u.actor.preview,edge,p,aim)
 return edge

static func draw_blade(item:CanvasItem,v:HybridCharacter)->void:
 if not v.has_meta("saebom_melee_blade"):return
 var a:Array=v.get_meta("saebom_melee_blade")
 item.draw_colored_polygon(a[0],Color("596372"))
 item.draw_colored_polygon(a[1],Color("d2c8ad"))
 item.draw_colored_polygon(a[2],Color("483630"))
static func project(v:HybridCharacter,pos:Vector3)->Vector2:
 if v.has_meta("duel_world"):return v.get_meta("duel_world").project(pos)
 return v.position+(v.display.position+v.camera.unproject_position(pos)*v.display.scale)*v.scale

static func unproject(v:HybridCharacter,mark:Vector2,depth:float)->Vector3:
 if v.has_meta("duel_world"):
  var world=v.get_meta("duel_world")
  return world.camera.project_position((mark-world.display.position)/world.display.scale,depth)
 var pixel:=((mark-v.position)/v.scale-v.display.position)/v.display.scale
 return v.camera.project_position(pixel,depth)

static func bone_pos(sk:Skeleton3D,b:int)->Vector3:
 return sk.to_global(sk.get_bone_global_pose(b).origin)

static func bone_named(v:HybridCharacter,n:String)->Vector3:
 return bone_pos(v.skeleton,v.skeleton.find_bone(n))

static func shoulder(unit:Dictionary,_attacker:Vector2)->Vector2:
 var v:HybridCharacter=unit.actor.preview
 if v.skeleton.find_bone("front_upper.R")<0 or v.skeleton.find_bone("trunk")<0 or v.skeleton.find_bone("head")<0:
  return unit.feet-Vector2(0,24)
 var front:=project(v,bone_named(v,"front_upper.R"))
 var ribs:=project(v,bone_named(v,"trunk"))
 var head:=project(v,bone_named(v,"head"))
 # The near-body ribs sit behind the front shoulder and clear the visible
 # lower jaw even at the actual phone camera. Do not aim at head or muzzle.
 var side_skin:=front.lerp(ribs,.30)
 side_skin.y=maxf(side_skin.y+6.4,head.y+18.2)
 return side_skin

static func _curve(t:float,times:Array,poses:Array[Vector2])->Vector2:
 # C1 Hermite join: body leads a single strike and the weight follows through.
 for j in range(1,times.size()):
  if t<=float(times[j]):
   var k:=j-1
   var a:=float(times[k]); var b:=float(times[j])
   var v0:=Vector2.ZERO if k==0 else (poses[j]-poses[k-1])/float(times[j]-times[k-1])
   var v1:=Vector2.ZERO if j==poses.size()-1 else (poses[j+1]-poses[k])/float(times[j+1]-times[k])
   var x:=clampf((t-a)/(b-a),0.,1.)
   return (2.*x*x*x-3.*x*x+1.)*poses[k]+(x*x*x-2.*x*x+x)*(b-a)*v0+(-2.*x*x*x+3.*x*x)*poses[j]+(x*x*x-x*x)*(b-a)*v1
 return poses[-1]

static func _rotate(sk:Skeleton3D,n:String,axis:Vector3,amount:float)->void:
 var i:=sk.find_bone(n)
 if i>=0 and absf(amount)>.0001:sk.set_bone_pose_rotation(i,sk.get_bone_pose_rotation(i)*Quaternion(axis,amount))

static func _from_to(sk:Skeleton3D,i:int,old:Vector3,want:Vector3,weight:=1.0)->void:
 var p:=sk.get_bone_global_pose(i)
 var a:=sk.to_local(old)-p.origin
 var b:=sk.to_local(want)-p.origin
 if a.length_squared()<.00001 or b.length_squared()<.00001:return
 var rotate:=Quaternion.IDENTITY.slerp(Quaternion(a.normalized(),b.normalized()),weight)
 p.basis=Basis(rotate)*p.basis
 sk.set_bone_global_pose(i,p)
 sk.force_update_all_bone_transforms()

static func _arm(sk:Skeleton3D,want:Vector3,pole_hint:Vector3,weight:float,suffix:String="R")->void:
 var upper:=sk.find_bone("upper."+suffix);var fore:=sk.find_bone("lower."+suffix);var hand:=sk.find_bone("hand."+suffix)
 var s:=bone_pos(sk,upper);var e:=bone_pos(sk,fore);var w:=bone_pos(sk,hand)
 var ab:=s.distance_to(e);var bc:=e.distance_to(w)
 var delta:=want-s
 var direction:=delta.normalized()
 var span:=clampf(delta.length(),absf(ab-bc)+.09,ab+bc-.027)
 var along:=(ab*ab-bc*bc+span*span)/(2.*span)
 var side:=sqrt(maxf(0.,ab*ab-along*along))
 var pole:=pole_hint
 pole=(pole-direction*pole.dot(direction)).normalized()
 if pole.length_squared()<.5:pole=(e-s-direction*(e-s).dot(direction)).normalized()
 var elbow:=s+direction*along+pole*side
 _from_to(sk,upper,e,elbow,weight)
 _from_to(sk,fore,bone_pos(sk,hand),s+direction*span,weight)

static func _gear(v:HybridCharacter)->Array:
 if v.has_meta("close_basic_cords"):return v.get_meta("close_basic_cords")
 var sk:Skeleton3D=v.skeleton
 var result:Array=[]
 for model in v.pivot.find_children("*","MeshInstance3D",true,false):
  var n:=String(model.name)
  if not n.begins_with("Sling - cord_"):continue
  var name:=n.trim_prefix("Sling - ")
  var id:=sk.find_bone(name)
  var bind_pose:Transform3D=model.skin.get_bind_pose(id)
  var box:AABB=model.get_aabb()
  var center:=box.get_center()
  var start:=bind_pose*Vector3(center.x,box.position.y,center.z)
  var end:=bind_pose*Vector3(center.x,box.end.y,center.z)
  var grip:=bone_pos(sk,sk.find_bone("hand.R"))
  var bone_matrix:Transform3D=sk.global_transform*sk.get_bone_global_pose(id)
  if grip.distance_to(bone_matrix*start)>grip.distance_to(bone_matrix*end):
   var tmp:=start;start=end;end=tmp
  result.append({"id":id,"a":start,"b":end})
 v.set_meta("close_basic_cords",result)
 return result

static func _cord(sk:Skeleton3D,data:Dictionary,grip:Vector3,pouch:Vector3,weight:float)->void:
 var bone:int=data.id
 var a:Vector3=data.a
 var direction:Vector3=data.b-a
 var axis:=direction.normalized()
 var tail:=pouch-grip
 if tail.length()<.03:return
 var width:=sk.global_basis.x.length()
 var stretch:=tail.length()/maxf(.01,direction.length())
 var basis:=Basis(Quaternion(axis,tail.normalized()))*Basis(
  Vector3.RIGHT*width+axis*axis.x*(stretch-width),
  Vector3.UP*width+axis*axis.y*(stretch-width),
  Vector3.BACK*width+axis*axis.z*(stretch-width))
 var pose:=sk.global_transform.affine_inverse()*Transform3D(basis,grip-basis*a)
 var saved:=sk.get_bone_global_pose(bone)
 sk.set_bone_global_pose(bone,saved.interpolate_with(pose,weight))

const PALM_LOCAL:=Vector3(-.004,.132,-.046)

static func _palm(sk:Skeleton3D,hand:int,local:Vector3=PALM_LOCAL)->Vector3:
 return sk.global_transform*sk.get_bone_global_pose(hand)*local


static func _plant_leg(sk:Skeleton3D,suffix:String,plant:Transform3D,pole:Vector3)->void:
 var up:=sk.find_bone("thigh."+suffix)
 var low:=sk.find_bone("shin."+suffix)
 var foot:=sk.find_bone("foot."+suffix)
 var hip:=bone_pos(sk,up)
 var knee:=bone_pos(sk,low)
 var ankle:=bone_pos(sk,foot)
 var wanted:=sk.global_transform*plant.origin
 var len1:=hip.distance_to(knee)
 var len2:=knee.distance_to(ankle)
 var d:=(wanted-hip).normalized()
 var reach:=clampf(hip.distance_to(wanted),absf(len1-len2)+.01,len1+len2-.004)
 var mid:=(len1*len1-len2*len2+reach*reach)/(2.*reach)
 var bend:=(pole-d*pole.dot(d)).normalized()
 var side:=sqrt(maxf(0.,len1*len1-mid*mid))
 _from_to(sk,up,knee,hip+d*mid+bend*side)
 _from_to(sk,low,bone_pos(sk,foot),hip+d*reach)
 sk.set_bone_global_pose(foot,plant)
 sk.force_update_all_bone_transforms()


static func sample_basic(unit:Dictionary,target:Dictionary,p:float)->Vector2:
 var actor=unit.actor
 var view:HybridCharacter=actor.preview
 var cam:=cam_for(view)
 var sk:Skeleton3D=view.skeleton
 view.animation.play(actor.clip_for("idle"),0.0)
 sk.reset_bone_poses()
 actor.resident_sample("idle",0.)
 sk.force_update_all_bone_transforms()
 _gear(view)
 var right:=sk.find_bone("hand.R")
 var left:=sk.find_bone("hand.L")
 var hip:=sk.find_bone("hips")
 var r_foot:=sk.find_bone("foot.R")
 var l_foot:=sk.find_bone("foot.L")
 var stone:=sk.find_bone("sling_stone")
 var pouch:=sk.find_bone("sling_pouch")
 var r_home:=_palm(sk,right)
 var l_local:=Vector3(.004,.132,-.046)
 var l_home:=_palm(sk,left,l_local)
 var center_old:=bone_pos(sk,hip)
 var right_home:=sk.get_bone_global_pose(r_foot)
 var left_home:=sk.get_bone_global_pose(l_foot)
 var slack:=bone_pos(sk,pouch)-r_home
 var rock:=bone_pos(sk,stone)-bone_pos(sk,pouch)
 var edge:Vector2=unit.get("close_basic_edge",Vector2.INF)
 if not edge.is_finite():edge=shoulder(target,unit.feet)
 var face:=1. if edge.x>=unit.feet.x else -1.
 var axis:=cam.global_basis.x*face
 var towards_cam:=(cam.global_basis.z*Vector3(1,0,1)).normalized()
 var forward:=(axis*.96-towards_cam*.28).normalized()
 var side_axis:=Vector3.UP.cross(forward).normalized()
 var is_step:=true
 var rl:=["R","L"]
 var ankle:=[right_home,left_home]
 var front:=0 if bone_pos(sk,r_foot).dot(forward)>=bone_pos(sk,l_foot).dot(forward) else 1
 # Option A: one quiet walking-size foot plant occurs before the short
 # side push-through. Option B: both boots stay planted throughout.
 var step_slide:=smoothstep(.074,.312,p)*(1.-smoothstep(.665,.955,p)) if is_step else 0.
 var toe_lift:=0.
 if is_step and p>.073 and p<.314:
  toe_lift=sin(PI*clampf((p-.073)/.241,0.,1.))*.145
 elif is_step and p>.67 and p<.96:
  toe_lift=sin(PI*clampf((p-.67)/.29,0.,1.))*.074
 var settle:=smoothstep(.016,.19,p)
 var brace:=smoothstep(.025,.303,p)*(1.-smoothstep(.53,.80,p))
 var transfer:=smoothstep(.28,.48,p)*(1.-smoothstep(.60,.91,p))
 var h:=sk.get_bone_global_pose(hip)
 var shift:=(-.104*brace+.258*transfer) if is_step else (-.073*brace+.052*transfer)
 var drop:=(.065*brace+.070*transfer) if is_step else (.113*brace-.052*transfer)
 h.origin+=sk.global_basis.inverse()*(forward*shift+Vector3.DOWN*drop)
 sk.set_bone_global_pose(hip,h)
 sk.force_update_all_bone_transforms()
 var pin:=smoothstep(.008,.10,p)*(1.-smoothstep(.92,1.,p))
 for k in 2:
  var a:Transform3D=ankle[k]
  if is_step and k==front:
   a.origin+=sk.global_basis.inverse()*(forward*.365*step_slide+Vector3.UP*toe_lift)
  var name:String=rl[k]
  var f_id:=r_foot if k==0 else l_foot
  if pin>.01:_plant_leg(sk,name,sk.get_bone_global_pose(f_id).interpolate_with(a,pin),forward+(towards_cam*(.18 if k==0 else -.28)))
 var spine:=sk.find_bone("spine")
 var body:=sk.get_bone_global_pose(spine)
 var pitch:=(-.09*brace+.096*transfer) if is_step else (.08*brace-.04*transfer)
 body.basis=Basis(Quaternion((sk.global_basis.inverse()*side_axis).normalized(),pitch))*body.basis
 sk.set_bone_global_pose(spine,body)
 # Shoulder rotation stays restrained, not a full-body pivot.
 _rotate(sk,"chest",Vector3.UP,(-.05*brace+.045*transfer) if is_step else (-.075*brace+.064*transfer))
 _rotate(sk,"head",Vector3.UP,.029*brace-.025*transfer)
 sk.force_update_all_bone_transforms()
 var rest_mark:=project(view,r_home)
 var hit_vec:Vector3=(axis*.96+Vector3.DOWN*(.095 if is_step else .16)-towards_cam*.10).normalized()*(.27 if is_step else .50)
 var ideal:=edge-Vector2(face*3.1,0.)-(project(view,r_home+hit_vec+rock)-rest_mark)
 var points:Array[Vector2]
 var phases:Array
 if is_step:
  phases=[0.,.08,.22,.33,.405,.48,.57,.69,.92,1.]
  points=[rest_mark,rest_mark+Vector2(-3.*face,0.),rest_mark+Vector2(-9.*face,-9.),
   ideal+Vector2(-20.*face,-7.),ideal+Vector2(-12.*face,-4.0),
   ideal,ideal+Vector2(3.*face,6.),rest_mark+Vector2(5.*face,3.),rest_mark,rest_mark]
 else:
  phases=[0.,.115,.25,.345,.415,.48,.565,.67,.86,1.]
  points=[rest_mark,rest_mark+Vector2(-6.*face,3.),rest_mark+Vector2(-9.*face,10.),
   ideal+Vector2(-7.*face,10.),ideal+Vector2(-3.5*face,6.8),
   ideal,ideal+Vector2(-5.*face,1.5),rest_mark+Vector2(-5.*face,3.),rest_mark+Vector2(-3.*face,-1.),rest_mark]
 var depth:float=-cam.to_local(r_home).z
 var aim:=unproject(view,_curve(p,phases,points),depth-.025*brace+.04*transfer)
 var work:=smoothstep(.015,.145,p)*(1.-smoothstep(.78,1.,p))
 sk.set_bone_pose_rotation(right,sk.get_bone_pose_rotation(right)*Quaternion(Vector3.UP,face*(-.08*brace+.12*transfer)))
 sk.force_update_all_bone_transforms()
 var elbow_pole:Vector3=(Vector3.DOWN*.79+towards_cam*.45-forward*.12).normalized() if is_step else (Vector3.DOWN*.72+towards_cam*.58-forward*.10).normalized()
 for k in 4:
  _arm(sk,aim-(_palm(sk,right)-bone_pos(sk,right)),elbow_pole,work if k==0 else minf(1.,work*1.2))
 var open_hand:Vector3=l_home-forward*.061*transfer+Vector3.UP*.036*brace if is_step else l_home+forward*.16*brace+Vector3.UP*.065*brace-towards_cam*.025*brace
 for k in 3:
  _arm(sk,open_hand-(_palm(sk,left,l_local)-bone_pos(sk,left)),Vector3.DOWN,work*.72,"L")
 return edge

static func blade(view:HybridCharacter,point:Vector2,phase:float,aim:float)->void:
 var sk:Skeleton3D=view.skeleton
 var right:=sk.find_bone("hand.R")
 var start:=project(view,_palm(sk,right))
 var direction:=(point-start).normalized()
 var anchor:=bone_pos(sk,right)
 var palm:=_palm(sk,right)
 var loft:=smoothstep(.03,.20,phase)*(1.-smoothstep(.20,.43,phase))
 var release_taper:=smoothstep(.50,.59,phase)*(1.-smoothstep(.65,.87,phase))
 var correction:=Vector2(-3,-5)*loft+Vector2(1,3)*release_taper
 var cam:=cam_for(view)
 var depth:float=-cam.to_local(palm).z
 for i in 3:
  _arm(sk,unproject(view,start+correction,depth)-(palm-anchor),Vector3.DOWN,.80*(loft+release_taper))
 start=project(view,_palm(sk,right))
 direction=(point-start).normalized()
 var calm:=Vector2(.21,.98)
 var up:=smoothstep(.10,.44,phase)*(1.-smoothstep(.53,.87,phase))
 var cock:=smoothstep(.06,.19,phase)*(1.-smoothstep(.21,.42,phase))
 var carry:=calm.rotated(-.57*cock)
 var d:=carry.lerp(direction,aim).normalized()
 var normal:=d.orthogonal()
 var distal:=start+d*15.
 var shoulder:=start+d*4.
 var pick:=start+d*9.
 var dagger:PackedVector2Array=PackedVector2Array([shoulder+normal*3.3, pick+normal*3.6,distal,start+d*10.-normal*3.0,pick-normal*2.9,shoulder-normal*3.2])
 var ridge:PackedVector2Array=PackedVector2Array([shoulder, pick+normal*2.9,distal,pick-normal*.3])
 var handle:PackedVector2Array=PackedVector2Array([start-d*3+normal*2.5,shoulder+normal*2.9,shoulder-normal*2.9,start-d*3-normal*2.5])
 var h:=sk.find_bone("hips")
 var hip:=bone_pos(sk,h)
 var hip_basis:=sk.global_basis*sk.get_bone_global_pose(h).basis
 var side_cross:=(cam.global_basis.z*Vector3(1,0,1)).normalized()
 var s0:=hip+side_cross*.19-cam.global_basis.x*.27+Vector3.UP*.09
 var s1:=s0+Vector3.DOWN*.22-cam.global_basis.x*.04
 for item in _gear(view):_cord(sk,item,s0,s1,1.)
 var pouch:=sk.find_bone("sling_pouch")
 var rock:=sk.find_bone("sling_stone")
 var tp:=sk.get_bone_global_pose(pouch)
 var tr:=sk.get_bone_global_pose(rock)
 tp.origin=sk.to_local(s1)
 tr.origin=sk.to_local(s1+Vector3.DOWN*.027)
 sk.set_bone_global_pose(pouch,tp);sk.set_bone_global_pose(rock,tr)
 sk.force_update_all_bone_transforms()
 view.set_meta("saebom_melee_blade", [dagger,ridge,handle])
 if not view.has_meta("duel_world"):view.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE

static func sample_skill(u:Dictionary,e:Dictionary,t:float)->Vector2:
 var actor=u.actor
 var v:HybridCharacter=actor.preview
 var sk:Skeleton3D=v.skeleton
 v.animation.play(actor.clip_for("idle"),0.0)
 sk.reset_bone_poses()
 actor.resident_sample("idle",0.)
 sk.force_update_all_bone_transforms()
 _gear(v)
 var cam:=cam_for(v)
 var right:=sk.find_bone("hand.R")
 var left:=sk.find_bone("hand.L")
 var hip:=sk.find_bone("hips")
 var r0:=_palm(sk,right)
 var l0:=_palm(sk,left,Vector3(.004,.132,-.046))
 var home:=project(v,r0)
 var front:=shoulder(e,u.feet)
 var side:=signf(front.x-u.feet.x)
 var fwd:=cam.global_basis.x*side
 var cam_flat:=(cam.global_basis.z*Vector3(1,0,1)).normalized()
 var axes:=[Vector2(0.91,.41),Vector2(.87,-.50),Vector2(.99,.10),Vector2(.64,.77)]
 var where:=[Vector2(0,-2),Vector2(1,3),Vector2(1,-1),Vector2(1,0)]
 var marks:Array[Vector2]=[home,home,home+Vector2(-side*10,-17)]
 var tt:Array=[0.,.32,.54]
 var edge:=front
 var patch:=0.
 var twist:=0.
 var fin:=0.
 for i in range(4):
  var sd:Vector2=axes[i]
  sd.x*=side
  var dest:Vector2=front+where[i]
  var anchor:=dest-Vector2(side*12.,sd.y*7.)
  marks.append(anchor-sd*(9. if i<3 else 18.))
  tt.append(float(times[i])-(.071 if i<3 else .116))
  marks.append(anchor);tt.append(times[i])
  marks.append(anchor+sd*(5. if i<3 else 8.));tt.append(float(times[i])+.052)
  var pulse:=exp(-pow((t-float(times[i]))/(.074 if i<3 else .13),2.))
  patch+=pulse*(.46 if i<3 else 1.0)
  twist+=pulse*(-1. if i==1 else 1.)*(.085 if i<3 else .215)
  if i==3:fin=pulse
  if absf(t-float(times[i]))<.080:edge=dest
 marks.append(home+Vector2(side*4,3));tt.append(1.68)
 marks.append(home);tt.append(1.93)
 var foot_r:=sk.get_bone_global_pose(sk.find_bone("foot.R"))
 var foot_l:=sk.get_bone_global_pose(sk.find_bone("foot.L"))
 var wind:=smoothstep(.33,.53,t)*(1.-smoothstep(.52,.67,t))+.94*smoothstep(1.18,1.34,t)*(1.-smoothstep(1.35,1.47,t))
 var h:=sk.get_bone_global_pose(hip)
 h.origin+=sk.global_basis.inverse()*(fwd*(.20*patch-.13*wind)+Vector3.DOWN*(.08*patch+.16*wind))
 sk.set_bone_global_pose(hip,h)
 sk.force_update_all_bone_transforms()
 if patch+wind>.02:
  _plant_leg(sk,"R",foot_r,fwd+cam_flat*.22)
  _plant_leg(sk,"L",foot_l,fwd-cam_flat*.28)
 _rotate(sk,"spine",Vector3.UP,twist-.10*wind)
 _rotate(sk,"chest",Vector3.UP,.64*twist-.071*wind)
 _rotate(sk,"head",Vector3.UP,-.24*twist)
 sk.force_update_all_bone_transforms()
 var grip_goal:=unproject(v,_curve(t,tt,marks),-cam.to_local(r0).z-.07*wind+.055*fin)
 var work:=smoothstep(.34,.54,t)*(1.-smoothstep(1.69,1.94,t))
 for i in range(5):
  _arm(sk,grip_goal-(_palm(sk,right)-bone_pos(sk,right)),Vector3.DOWN*.75+cam_flat*.56,work)
 var lgoal:=l0-fwd*(.073*patch)+Vector3.UP*(.087*wind)
 for i in range(3):
  _arm(sk,lgoal-(_palm(sk,left,Vector3(.004,.132,-.046))-bone_pos(sk,left)),Vector3.DOWN,work*.75,"L")
 blade(v,edge,0.,work)
 return edge


static func ribbon(fx:CanvasItem,c:Vector2,angle:float,radius:float,p:float,gain:float,large:bool,curvature:float)->void:
 var axis:=Vector2.from_angle(angle)
 var normal:=axis.orthogonal()
 var start:=.02+.16*smoothstep(.20,1.,p)
 var end:=clampf(.69+p*3.5,0.,1.0)
 var alpha:=pow(1.-p,1.51)*gain
 for layer in range(4):
  var le:=PackedVector2Array()
  var ri:=PackedVector2Array()
  var tint:Color=[Color(.96,.30,.04,alpha*.09),Color(1.,.60,.12,alpha*.26),Color(1.,.71,.25,alpha*.67),Color(1.,.95,.72,alpha*.92)][layer]
  var w:float=[11.,6.8,3.2,1.35][layer]
  if not large:w*=.66
  for j in range(35):
   var u:=float(j)/34.
   var s:=lerpf(start,end,u)
   var arc:=sin(s*PI)*radius*curvature
   var p0:=c+axis*radius*(2.*s-1.)+normal*(arc-radius*curvature)
   var taper:=pow(maxf(.0003,sin(u*PI)),.67)*(1.-.33*u)
   le.append(p0+normal*taper*(w*.74+(0.75 if layer==3 else 0.)))
   ri.insert(0,p0-normal*taper*w*.59)
  le.append_array(ri)
  if alpha>.013:fx.draw_colored_polygon(le,tint)
 if large:
  for k in range(2):
   var hair:=PackedVector2Array()
   for j in range(23):
    var u:=lerpf(.09+float(k)*.12,.90-float(k)*.05,float(j)/22.)
    var s:=lerpf(start,end,u)
    var shift:float=(-9. if k==0 else 10.)*pow(maxf(0.,sin(u*PI)),.50)
    hair.append(c+axis*radius*(2.*s-1.)+normal*((sin(s*PI)-1.)*radius*curvature+shift*(.75+.35*p)))
   fx.draw_polyline(hair,Color(1.,.76,.36,alpha*(.36 if k==0 else .51)),1.,true)

static func glint(fx:CanvasItem,c:Vector2,axis:Vector2,len:float,alpha:float)->void:
 var ortho:=axis.orthogonal()
 fx.draw_colored_polygon(PackedVector2Array([c-axis*len,c+ortho*1.05,c+axis*len,c-ortho*1.05]),Color(1.,.83,.48,alpha))

static func ground_echo(fx:CanvasItem,floor_point:Vector2,age:float)->void:
 if age<0. or age>.59:return
 var p:=clampf(age/.59,0.,1.)
 var push:=1.-pow(1.-p,2.1)
 var vanish:=pow(1.-p,1.60)
 for ring in range(3):
  var lag:=maxf(0.,p-float(ring)*.070)
  if ring>0 and lag<.001:continue
  var spread:=(12.+(118.-float(ring)*20.)*(1.-pow(1.-lag,2.18)))
  for wing in range(4):
   var arc:=PackedVector2Array()
   var gl:=PackedVector2Array()
   var angles:=Vector2(float(wing)*TAU/4.+.13,float(wing)*TAU/4.+1.45)
   for j in range(27):
    var angle:=lerpf(angles.x,angles.y,float(j)/26.)
    var v:=floor_point+Vector2(cos(angle)*spread,sin(angle)*spread*.26)
    arc.append(v);gl.append(v+Vector2(0,1.6))
   var ceiling:=(.63 if wing<2 else .36)*vanish*pow(.67,float(ring))
   fx.draw_polyline(gl,Color(1.,.50,.05,ceiling*.26),8.-push*3.1,true)
   fx.draw_polyline(arc,Color(1.,.92,.48,ceiling),2.70-p*1.38,true)
 for k in range(19):
  var seed:=float(k)*2.399963
  var side:=cos(seed)
  var n:=sin(seed)
  var drift:=(.38+.58*absf(sin(float(k)*17.)))
  var foot:=floor_point+Vector2(side*drift*(17.+push*115.),n*(9.+push*25.)-p*21.*drift)
  var air:=smoothstep(.05,.29,p)*(1.-smoothstep(.35,.92,p))
  var sz:=2.+push*(4.+float(k%4))
  fx.draw_circle(foot,sz,Color(.97,.63,.30,air*.13),true,-1.,true)
  fx.draw_circle(foot-Vector2(1.,1.2),sz*.48,Color(1.,.80,.52,air*.12),true,-1.,true)
  if k%2==0:glint(fx,foot,Vector2.from_angle(seed+1.54),2.4+push*2.2,air*.60)
static func draw_event(fx:CanvasItem,i:int,c:Vector2,floor_point:Vector2,age:float)->void:
 if i==3:ground_echo(fx,floor_point,age)
 if true:
  var fin:=i==3
  var duration:=.195 if not fin else .46
  if age<0. or age>=duration:return
  var p:=age/duration
  var alpha:=pow(1.-p,1.36)

  var angle:float=[-.47,.61,-.12,.63][i]
  ribbon(fx,c,angle,32. if not fin else 64.,p,.84 if not fin else 1.,fin,.33)
  if i==1:
   ribbon(fx,c,angle-1.34,28.,p,.65,false,-.26)
  if fin:
   ribbon(fx,c,angle-1.29,58.,p,.96,true,-.30)
   ribbon(fx,c+Vector2(8.,2.),angle-.13,74.,p,.25,false,.52)
   ribbon(fx,c+Vector2(-7.,6.),angle-1.14,69.,p,.23,false,-.43)
   if p>.11 and p<.55:ribbon(fx,c+Vector2(3,7),angle-1.44,52.,p,.32,false,-.46)
   if p<.46:
    var snap:=pow(1.-p/.46,2.)
    glint(fx,c,Vector2.from_angle(.22),8.+p*21.,snap*.86)
    glint(fx,c,Vector2.from_angle(1.79),6.+p*19.,snap*.75)
  for j in range(23 if fin else 7):
   var theta:=float(j)*2.399963+float(i)*.7
   var ray:=Vector2.from_angle(theta)
   var len:=(26. if not fin else 98.)*(.66+.30*sin(float(j)*47.))
   var at:=c+ray*(9.+len*(.14+.79*p))+Vector2(0.,p*p*20.)
   if fin and j%3==2:fx.draw_circle(at,1.10+alpha,Color(1.,.94,.67,alpha*.52),true,-1.,true)
   glint(fx,at,ray,(2.9 if not fin else 3.7)+(2.3 if fin and j%3==0 else 0.)*alpha,alpha*(.56 if not fin else .84))
