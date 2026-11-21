extends RefCounted

const RATIO:=.60

static func _light(layer:CanvasItem, texture:Texture2D, at:Vector2, sz:Vector2, tint:Color, a:float)->void:
 if texture!=null and a>.002:
  var size:=sz*RATIO
  layer.draw_texture_rect(texture,Rect2(at-size*.5,size),false,Color(tint,a))

static func draw_trail(layer:CanvasItem, texture:Texture2D, points:PackedVector2Array, alpha:float=1.)->void:
 if points.size()<2 or alpha<=.002:return
 for i in range(1,points.size()):
  var f:=float(i)/float(points.size()-1)
  var a:Vector2=points[i-1]
  var b:Vector2=points[i]
  if a.distance_squared_to(b)<.0001:continue
  layer.draw_line(a,b,Color("e78627",alpha*f*.45),41.*RATIO*f,true)
  layer.draw_line(a,b,Color("ffbc59",alpha*f*.80),21.*RATIO*f,true)
  layer.draw_line(a,b,Color("fff1ad",alpha*f*.92),8.*RATIO*f,true)
 var head:=points[-1]
 _light(layer,texture,head,Vector2(176,126),Color("ffc249"),alpha*.90)
 _light(layer,texture,head,Vector2(38,33),Color("fff2ba"),alpha*.99)

static func draw_hit(layer:CanvasItem, texture:Texture2D, hit:Vector2, dir:Vector2, t:float)->void:
 if t<0. or t>1.35:return
 var v:=dir.normalized() if dir.length_squared()>.00001 else Vector2.RIGHT
 var n:=Vector2(-v.y,v.x)
 var flash:=1.-smoothstep(.10,.32,t)
 var tail:=smoothstep(0.,.028,t)*(1.-smoothstep(.23,1.22,t))
 _light(layer,texture,hit,Vector2(618,304),Color("e37c29"),flash*.96)
 _light(layer,texture,hit,Vector2(302,154),Color("ffc960"),flash)
 _light(layer,texture,hit,Vector2(63,38),Color("fff5c7"),flash)
 _light(layer,texture,hit+v*(138.*(1.-exp(-t*6.4)))*RATIO,Vector2(430,236),Color("e89b32"),tail*.35)
 var reach:=1.-exp(-t*8.)
 for i in 11:
  var q:=float(i)/10.*2.-1.
  var at:=hit+(v*(450.-absf(q)*138.)+n*q*155.)*reach*RATIO
  _light(layer,texture,at,Vector2(235,111),Color("f39c32"),tail*(.35-.14*absf(q)))
  _light(layer,texture,at,Vector2(112,46),Color("ffc452"),tail*.54)
