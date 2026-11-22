extends RefCounted
## Presentation-only entry points. Caller owns animation timing, actual hits, and parry events.
const UramHeavy=preload("res://scripts/hunt_duel_uram_2p_effect.gd")
const HAN_SKILL_SECONDS:=11./30.
const HAN_CHAIN_SECONDS:=.70
const HAN_RADIAL_EXTENT:=Vector2(557.,201.)
const HAN_SKILL_ORIGIN:=Vector2(90.,117.)
const HAN_SKILL_SIZE:=288.
var han_skill:Array[Texture2D]=[]
var han_chain:Array[Texture2D]=[]
var han_radial:Array[Texture2D]=[]

func prepare()->bool:
 if han_skill.size()==11 and han_chain.size()==21 and han_radial.size()==21:return true
 han_skill=_load_frames("res://assets/effects/duel-2sp-authored/han_2sp_impact_%02d.png",11)
 han_chain=_load_frames("res://assets/effects/duel-3sp-authored/hangyeol/192/han_chain_impact_%02d.png",21)
 han_radial=_load_frames("res://assets/effects/duel-3sp-polished/hangyeol/192/han_3sp_radial_%02d.png",21)
 return han_skill.size()==11 and han_chain.size()==21 and han_radial.size()==21

func _load_frames(template:String,count:int)->Array[Texture2D]:
 var frames:Array[Texture2D]=[]
 for i in count:
  var path:=template%i
  var tex:=load(path) as Texture2D if ResourceLoader.exists(path) else null
  if tex==null or tex.get_size()!=Vector2(192,192):
   push_warning("Missing or invalid frontline VFX frame: "+path)
   frames.clear()
   return frames
  frames.append(tex)
 return frames

func _light(layer:CanvasItem,tex:Texture2D,p:Vector2,size:Vector2,color:Color,a:float)->void:
 if tex!=null and a>.003:layer.draw_texture_rect(tex,Rect2(p-size*.5,size),false,Color(color,clampf(a,0.,1.)))

func _frame(frames:Array[Texture2D],age:float)->Texture2D:
 return frames[clampi(floori(age*30.),0,frames.size()-1)]

func draw_han_skill_hit(layer:CanvasItem,at:Vector2,direction:Vector2,age:float,scale0:=1.)->void:
 if age<0. or age>=HAN_SKILL_SECONDS or han_skill.size()!=11:return
 layer.draw_set_transform(at,direction.angle()+.57)
 layer.draw_texture_rect(_frame(han_skill,age),Rect2(-HAN_SKILL_ORIGIN*(HAN_SKILL_SIZE/192.)*scale0,Vector2.ONE*HAN_SKILL_SIZE*scale0),false)
 layer.draw_set_transform(Vector2.ZERO)

func _ray(layer:CanvasItem,tex:Texture2D,from:Vector2,to:Vector2,width:float,alpha:float)->void:
 if alpha<=.003:return
 layer.draw_line(from,to,Color("41a5ff",alpha*.25),width,true)
 layer.draw_line(from,to,Color("6bd9ff",alpha*.50),width*.46,true)
 layer.draw_line(from,to,Color("ddfaff",alpha*.82),width*.14,true)
 _light(layer,tex,to,Vector2.ONE*width*1.65,Color("e9fbff"),alpha*.7)

func draw_han_chain_cast(layer:CanvasItem,tex:Texture2D,foot:Vector2,chest:Vector2,hand:Vector2,tip:Vector2,phase0:float,trail:PackedVector2Array=PackedVector2Array(),scale0:=1.)->void:
 var phase:=clampf(phase0,0.,1.)
 var power:=smoothstep(.035,.21,phase)*(1.-smoothstep(.70,.86,phase))
 var charge:=power*(1.-smoothstep(.22,.39,phase))
 var gather:=smoothstep(.07,.19,phase)*(1.-smoothstep(.43,.54,phase))
 if gather>.001:
  for i in 11:
   var side:=Vector2.from_angle(float(i)*TAU/11.+.21)
   var offset:=side*Vector2(76.+float(i%3)*11.,31.+float(i%3)*10.)
   var start:=foot+(offset+Vector2(0.,-11.*float(i%4)))*scale0
   var t:=clampf((phase-.03-.036*float(i%4))/.38,0.,1.)
   var bend:=start.lerp(tip,smoothstep(0.,1.,t))+side*7.*sin(PI*t)*scale0
   var tail:=start.lerp(tip,smoothstep(0.,1.,maxf(0.,t-.12)))
   var spark:=gather*sin(PI*t)
   _light(layer,tex,bend,Vector2(19,15)*lerpf(.72,1.25,t)*scale0,Color("48caff"),spark*.8)
   layer.draw_line(tail,bend,Color("7edcff",spark*.60),1.7*scale0,true)
   _light(layer,tex,bend,Vector2(7,6)*scale0,Color("e4fbff"),spark*.93)
  _light(layer,tex,tip,Vector2(88,65)*scale0,Color("2a9cff"),gather*smoothstep(.21,.39,phase)*.58)
 _light(layer,tex,foot,Vector2(111,40)*scale0,Color("1ba3ff"),charge*.76)
 _light(layer,tex,foot,Vector2(49,19)*scale0,Color("b8f3ff"),charge*.66)
 for i in 5:
  var rise:=clampf((phase-.052-float(i)*.026)/.23,0.,1.)
  var point:=foot.lerp(chest,rise*2.) if rise<.5 else chest.lerp(hand,(rise-.5)*2.)
  _light(layer,tex,point,Vector2(31,31)*scale0,Color("5cd5ff"),sin(PI*rise)*charge*.69)
 var spear:=power*smoothstep(.20,.38,phase)
 _ray(layer,tex,hand.lerp(tip,.36),tip,8.*scale0,spear*.70)
 _light(layer,tex,tip,Vector2(61,49)*scale0,Color("33a9ff"),spear*.85)
 _light(layer,tex,tip,Vector2(21,19)*scale0,Color("e5fbff"),spear)
 var descent:=power*smoothstep(.415,.53,phase)
 if descent>.001 and trail.size()>1:
  var prev:=tip
  for i in range(1,trail.size()):
   var point:=trail[i]
   if point.distance_to(tip)>81.*scale0:break
   prev=point
   var weight:=1.-float(i)/float(trail.size())
   _light(layer,tex,point,Vector2(31,28)*lerpf(.53,1.,weight)*scale0,Color("40b8ff"),descent*weight*.65)
  _ray(layer,tex,prev,tip,18.*scale0,descent)

func draw_han_chain_ground(layer:CanvasItem,tex:Texture2D,floor_point:Vector2,age:float,scale0:=1.)->void:
 if age<0. or age>=HAN_CHAIN_SECONDS:return
 var after:=smoothstep(.015,.075,age)*(1.-smoothstep(.17,.63,age))
 _light(layer,tex,floor_point,Vector2(175,55)*scale0,Color("238cff"),after*.46)
 if han_radial.size()==21:
  var extent:=HAN_RADIAL_EXTENT*scale0
  layer.draw_texture_rect(_frame(han_radial,age),Rect2(floor_point-extent*.5,extent),false)

func draw_han_chain_hit(layer:CanvasItem,tex:Texture2D,at:Vector2,wake:Vector2,age:float,scale0:=1.)->void:
 if age<0. or age>=1.2:return
 if age<HAN_CHAIN_SECONDS and han_chain.size()==21:
  layer.draw_texture_rect(_frame(han_chain,age),Rect2(at-Vector2(96,121.5)*scale0,Vector2(192,192)*scale0),false)
 var peak:=1.-smoothstep(.025,.155,age)
 _ray(layer,tex,wake,at,22.*scale0,1.-smoothstep(.015,.145,age))
 _light(layer,tex,at,Vector2(93,70)*scale0,Color("36afff"),peak*.85)
 _light(layer,tex,at,Vector2(28,24)*scale0,Color("f2fcff"),peak)
 var tail:=smoothstep(.08,.19,age)*(1.-smoothstep(.15,1.2,age))
 _light(layer,tex,at,Vector2(84,65).lerp(Vector2(124,82),age/1.2)*scale0,Color("48afff"),tail*.47)

func draw_uram_skill_windup(layer:CanvasItem,tex:Texture2D,club_tip:Vector2,progress:float,scale0:=1.)->void:
 UramHeavy.draw_windup(layer,tex,club_tip,progress,scale0)

func draw_uram_skill_hit(layer:CanvasItem,tex:Texture2D,hit:Vector2,floor_point:Vector2,direction:Vector2,age:float,scale0:=1.)->void:
 UramHeavy.draw(layer,tex,hit,floor_point,direction,age,scale0,1.60,true)

# Call exclusively for an actual shield contact event; this draws no gameplay hit.
func draw_uram_gong(layer:CanvasItem,tex:Texture2D,center:Vector2,direction:Vector2,age:float,scale0:=1.)->void:
 if age<0. or age>=1.6 or direction.length_squared()<.0001:return
 var forward:=direction.normalized()
 var core:=1.-smoothstep(.045,.33,age)
 _light(layer,tex,center,Vector2(127,89)*scale0,Color("df4c23"),core*.82)
 _light(layer,tex,center,Vector2(74,53)*scale0,Color("ff9f48"),core*.90)
 _light(layer,tex,center,Vector2(31,24)*scale0,Color("ffe7a0"),core)
 var opening:=1.-exp(-age*3.15)
 var radius:=(16.+397.*opening)*.44
 var strength:=smoothstep(0.,.065,age)*(1.-smoothstep(.23,1.6,age))
 var ring:=sin(age*15.)*exp(-age*2.7)
 var across:=forward.orthogonal()
 for j in 40:
  var theta:=lerpf(-1.52,1.52,float(j)/39.)
  var envelope:=pow(maxf(0.,cos(theta)),.72)
  var warp:=sin(theta*7.+age*3.)*(8.+opening*12.)+sin(theta*3.8+.9)*opening*29.+ring*sin(theta*3.)*17.
  var ray:=forward*cos(theta)+across*sin(theta)*.84
  var point:=center+ray*(radius+warp*.44)*scale0
  if j%2==0:_light(layer,tex,point,Vector2(75,49)*(1.+opening*.42)*scale0,Color("ec6826"),strength*envelope*(.30+.10*ring))
  _light(layer,tex,point,Vector2(46,31)*scale0,Color("ff9f48"),strength*envelope*.22*(.8+.2*sin(theta*13.+1.)))
  _light(layer,tex,point-ray*(30.+opening*50.)*.44*scale0,Vector2(59,37)*scale0,Color("d56a36"),strength*envelope*.15)

## Approved standalone ground grit, spatially independent of the shield-face flare.
## Use actual Uram feet at confirmed block. Wildlife takeoff dust remains separate.
func draw_uram_gong_dust(layer:CanvasItem,tex:Texture2D,floor_point:Vector2,age:float)->void:
 if age<=0. or age>=2.15:return
 const SCALE := .44
 var dur:=clampf(age/2.15,0.,1.)
 var env:=smoothstep(0.,.07,age)*(1.-smoothstep(.36,2.15,age))
 if env<=.003:return
 for i in 37:
  var a:=float(i)*2.39996
  var ray:=Vector2(cos(a),sin(a)*.36)
  var at:=floor_point+(ray*lerpf(10.,190.+float(i%6)*11.,sqrt(dur))+Vector2(30.*dur,-(17.+float(i%3)*10.)*sin(dur*PI)))*SCALE
  var extent:=Vector2(78,32)*lerpf(.52,1.65,dur)*SCALE
  _light(layer,tex,at,extent,Color("513d2e"),env*.30)
  _light(layer,tex,at-Vector2(3,4)*SCALE,extent*.87,Color("ca9c68"),env*(.29+float(i%3)*.08))
 for i in 15:
  var a:=float(i)*2.39996
  var at:=floor_point+(Vector2(cos(a)*175,sin(a)*38)*sqrt(dur)+Vector2(0,-(25.+float(i%3)*34.)*sin(dur*PI)))*SCALE
  layer.draw_circle(at,(1.1+float(i%3)*.8)*SCALE,Color("634431",env*.43),true,-1,true)
