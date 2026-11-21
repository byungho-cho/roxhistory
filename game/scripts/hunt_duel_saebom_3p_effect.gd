extends RefCounted
const WARM := Color(1.0,.48,.07)
const HONEY := Color(1.0,.74,.18)
const PALE := Color(1.0,.94,.62)
var active_tex:Texture2D
var stowed:Dictionary={}
var batch_points:PackedVector2Array
var batch_colors:PackedColorArray
var batch_tris:PackedInt32Array
func draw_wings(layer:Node2D,tex:Texture2D,center:Vector2,elapsed:float,scale0:float=1.,front:bool=false):
 active_tex=tex
 layer.draw_set_transform(center,0.,Vector2.ONE*scale0)
 batch_points.clear(); batch_colors.clear(); batch_tris.clear()
 _draw_wings(layer,Vector2.ZERO,elapsed,front)
 if not batch_tris.is_empty():RenderingServer.canvas_item_add_triangle_array(layer.get_canvas_item(),batch_tris,batch_points,batch_colors)
 layer.draw_set_transform(Vector2.ZERO)
func draw_ally(layer:Node2D,tex:Texture2D,feet:Vector2,elapsed:float,scale0:float=1.,front:bool=false):
 active_tex=tex
 layer.draw_set_transform(feet,0.,Vector2.ONE*scale0)
 _draw_ally(layer,Vector2.ZERO,elapsed,front)
 layer.draw_set_transform(Vector2.ZERO)
func sync_sling(pivot:Node3D,hide_now:bool):
 if pivot==null:return
 for it in pivot.find_children("*","MeshInstance3D",true,false):
  var prop:=it as MeshInstance3D
  if "sling" not in String(prop.name).to_lower():continue
  if hide_now:
   if not stowed.has(prop):stowed[prop]=prop.visible
   prop.visible=false
  elif stowed.has(prop):
   prop.visible=stowed[prop]
   stowed.erase(prop)
func restore_sling():
 for prop in stowed:
  if is_instance_valid(prop):prop.visible=stowed[prop]
 stowed.clear()

func gl(layer:Node2D, p:Vector2, size:Vector2, tone:Color, alpha:float):
 if active_tex!=null and alpha>.003: layer.draw_texture_rect(active_tex,Rect2(p-size*.5,size),false,Color(tone,alpha))
func tint(c:Color,a:float)->Color:
 return Color(c,clampf(a,0.,1.))

func feather(layer:Node2D,p:Vector2,q:Vector2,bend:float,thick:float,side:float,alpha:float,tone:Color):
 if p.distance_to(q)<3. or alpha<.005:return
 var delta:=q-p
 var perpendicular:=Vector2(-delta.y,delta.x).normalized()
 var v:=PackedVector2Array()
 var col:=PackedColorArray()
 for lane in [-1.,-.34,.28,1.]:
  for i in range(17):
   var k:=float(i)/16.
   var aa:=maxf(0.,sin(k*PI))
   var pp:=p.lerp(q,k)+Vector2(side*k*(1.-k)*bend,-k*(1.-k)*(31.2+11.2*sin(k*PI)))
   var o:=clampf((k-.34)/.66,0.,1.)
   var round0:=sqrt(maxf(0.,1.-pow(o,3.7)))
   var bias:=lerpf(.62,1.,smoothstep(.0,.42,k))*round0
   v.push_back(pp+perpendicular*(lane*maxf(.018,bias)*thick))
   var fold:=exp(-pow((float(lane)+.16)*2.6,2.))
   var shadow:=Color("ae621c").lerp(tone,.42+.54*smoothstep(.03,.79,k))
   var hue:=shadow.lerp(Color("ffdf84"),fold*(.31+.36*sin(PI*k)))
   var outline:=.14+.86*pow(maxf(0.,1.-absf(lane)),.47)
   col.push_back(tint(hue,alpha*outline*lerpf(.71,1.,minf(1.,aa*5.))))
 var offset:=batch_points.size()
 batch_points.append_array(v)
 batch_colors.append_array(col)
 for j in range(3):
  for i in range(16):
   var a:=j*17+i
   var b:=a+1
   var c:=a+18
   var d:=a+17
   if absf((v[b]-v[a]).cross(v[c]-v[a]))>.052:batch_tris.push_back(a+offset);batch_tris.push_back(b+offset);batch_tris.push_back(c+offset)
   if absf((v[c]-v[a]).cross(v[d]-v[a]))>.052:batch_tris.push_back(a+offset);batch_tris.push_back(c+offset);batch_tris.push_back(d+offset)
func _draw_wings(layer:Node2D,join:Vector2,elapsed:float,front:bool):
 var dt:=elapsed-.32
 if dt<0. or dt>1.95:return
 var gain:=smoothstep(0.,.20,dt)*(1.-smoothstep(.78,1.92,dt))
 var unfold:=smoothstep(.30,.57,dt)
 var further:=1.-smoothstep(.85,1.97,dt)*.12

 if front:
  var flash:=smoothstep(.53,.70,dt)*(1.-smoothstep(.77,1.17,dt))
  gl(layer,join,Vector2(117,126),Color("f7bd56"),flash*.48)
  gl(layer,join+Vector2(0,22),Vector2(41,72),Color("ffd789"),flash*.56)
  return
 gl(layer,join,Vector2(510,300)*(.42+unfold*.58),Color("ffbd58"),gain*.13)
 # Position paths transcribed from the right wing of the provided 500-square reference.
 var tips:=[Vector2(170,-210),Vector2(192,-190),Vector2(207,-160),Vector2(214,-126),Vector2(209,-98),Vector2(207,-65),Vector2(192,-34),Vector2(183,-11),Vector2(168,10),Vector2(160,31),Vector2(137,54),Vector2(107,67),Vector2(78,79)]
 var starts:=[Vector2(84,-83),Vector2(89,-72),Vector2(87,-57),Vector2(79,-47),Vector2(72,-35),Vector2(64,-25),Vector2(62,-19),Vector2(52,-16),Vector2(48,-13),Vector2(42,-12),Vector2(33,-9),Vector2(29,-7),Vector2(21,-3)]
 for n in [-1.,1.]:
  var side:=float(n)
  var hinged:=join+Vector2(side*13.,-3.)
  for i in range(13):
   var opening:=smoothstep(.30+.003*float(i),.54+.006*float(i),dt)*further
   var sz:=opening*1.33
   var a:Vector2=starts[i]
   var b:Vector2=tips[i]
   feather(layer,hinged+Vector2(side*a.x,a.y)*sz,hinged+Vector2(side*b.x,b.y)*sz,-20.*sz,lerpf(17.,14.,float(i)/12.)*sz,side,gain*opening,Color("d89538").lerp(Color("ffca61"),1.-float(i)/12.))
  for row in range(3):
   for i in range(13):
    var q:=float(i)/12.
    var opening:=smoothstep(.30+.003*float(i),.54+.005*float(i),dt)*further
    var sz:=opening*1.33
    var a:Vector2=starts[i]
    var b:Vector2=tips[i]
    var factor:=.79-float(row)*.215
    var st:=a*factor*.79+Vector2(5.,0.)
    var en:=b*factor
    feather(layer,hinged+Vector2(side*st.x,st.y)*sz,hinged+Vector2(side*en.x,en.y)*sz,-11.*sz,(15.-float(row)*3.)*sz,side,opening*gain,Color("f7b345").lerp(Color("ffdc82"),float(row)/2.))

func _draw_ally(layer:Node2D,pos:Vector2,elapsed:float,front:bool):
 var dt:=elapsed-.96
 if dt<0. or dt>.92:return
 var gain:=smoothstep(0.,.032,dt)*(1.-smoothstep(.32,.82,dt))
 var footfall:=smoothstep(0.,.038,dt)*(1.-smoothstep(.095,.38,dt))
 var climb:=smoothstep(.025,.4,dt)
 var anchor:=pos-Vector2(0.,lerpf(7.,149.,climb))
 var footprint:=pos-Vector2(0,5)
 if not front:
  gl(layer,footprint,Vector2(190,68),WARM,.82*footfall)
  gl(layer,footprint,Vector2(106,31),HONEY,.81*footfall)
  gl(layer,anchor,Vector2(254,lerpf(76.,282.,climb)),WARM,.78*gain)
  gl(layer,anchor,Vector2(158,lerpf(52.,204.,climb)),HONEY,.76*gain)
  gl(layer,anchor,Vector2(95,lerpf(35.,109.,climb)),PALE,.68*gain)
 else:
  gl(layer,footprint,Vector2(93,38),PALE,footfall*.75)
  gl(layer,anchor,Vector2(91,lerpf(31.,105.,climb)),HONEY,gain*.58)
  for i in range(8):
   var ph:=clampf((dt-float(i)*.021)/(.42+float(i)*.023),0.,1.)
   var x:=sin(float(i)*2.39+dt)*49.*(.58+ph*.36)
   var at:=pos+Vector2(x,-5.-ph*(154.+fmod(float(i)*37.,63.)))
   var tone:=PALE if i%3==0 else HONEY
   var a:=gain*pow(sin(ph*PI),.9)*.71
   gl(layer,at,Vector2(25,39),tone,a*.72)
   layer.draw_line(at+Vector2(-1,9),at+Vector2(2,-5),tint(tone,a),1.6,true)


func aim_arm_segment(sk:Skeleton3D,bone:int,child:int,goal:Vector3,blend:float):
 if bone<0 or child<0 or blend<=0.:return
 var parent:=sk.get_bone_parent(bone)
 var inv:=sk.get_bone_global_pose(parent).basis.orthonormalized().inverse()
 var from:=sk.get_bone_global_pose(child).origin-sk.get_bone_global_pose(bone).origin
 if from.length_squared()<.00001:return
 var local_from:Vector3=(inv*from.normalized()).normalized()
 var local_to:Vector3=(inv*goal.normalized()).normalized()
 var turn:=Quaternion(local_from,local_to)
 sk.set_bone_pose_rotation(bone,(Quaternion.IDENTITY.slerp(turn,blend)*sk.get_bone_pose_rotation(bone)).normalized())
 sk.force_update_all_bone_transforms()
func pose_cast(actor,elapsed:float,sample_idle:bool=true):
 if sample_idle:actor.resident_sample("idle",.63+.05*sin(elapsed*2.3))
 var dt:=elapsed-.32
 var load0:=smoothstep(-.32,.15,dt)*(1.-smoothstep(.33,.55,dt))
 var unfold:=smoothstep(.30,.57,dt)
 var recover:=1.-smoothstep(1.03,1.76,dt)
 var strength:=maxf(load0,unfold*recover)
 if strength<.001:return
 var sk:Skeleton3D=actor.preview.skeleton
 if sk==null:return
 var chest:=sk.find_bone("chest")
 if chest>=0:sk.set_bone_pose_rotation(chest,(sk.get_bone_pose_rotation(chest)*Quaternion(Vector3.RIGHT,-.10*load0+.07*unfold*recover)).normalized())
 sk.force_update_all_bone_transforms()
 for side in [-1.,1.]:
  var name0:=".R" if side<0 else ".L"
  var upper:=sk.find_bone("upper"+name0)
  var lower:=sk.find_bone("lower"+name0)
  var hand:=sk.find_bone("hand"+name0)
  var out:=Vector3(side,.21,.12)
  var gather_upper:=Vector3(side*.30,-.43,.75)
  var gather_lower:=Vector3(-side*.64,.53,.43)
  aim_arm_segment(sk,upper,lower,gather_upper.lerp(out,unfold),strength)
  aim_arm_segment(sk,lower,hand,gather_lower.lerp(Vector3(side,.17,.18),unfold),strength)
