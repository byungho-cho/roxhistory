extends RefCounted
## Preview-to-game Uram 2P. Contact and facing are supplied by gameplay.
static func _light(layer:CanvasItem, texture:Texture2D, at:Vector2, size:Vector2, tint:Color, alpha:float)->void:
 if alpha>.002 and texture!=null:
  layer.draw_texture_rect(texture,Rect2(at-size*.5,size),false,Color(tint,alpha))

static func draw_windup(layer:CanvasItem, texture:Texture2D, club_tip:Vector2, progress:float, scale:float=1.)->void:
 var wind:=smoothstep(.10,.58,progress)*(1.-smoothstep(.79,1.,progress))
 var ratio:=.60*scale
 _light(layer,texture,club_tip,Vector2(159,109)*ratio,Color("d8511c"),wind*.61)
 _light(layer,texture,club_tip,Vector2(47,29)*ratio,Color("ffc067"),wind*.86)

static func draw(layer:CanvasItem, texture:Texture2D, hit:Vector2, floor_point:Vector2, direction:Vector2, elapsed:float, scale:float=1., expansion_scale:float=1., deliberate:=false)->void:
 if elapsed<0. or elapsed>(2.04 if deliberate else 1.15*expansion_scale):return
 var wave_time:=elapsed/expansion_scale
 var forward:=direction.normalized() if direction.length_squared()>.00001 else Vector2.RIGHT
 var across:=Vector2(-forward.y,forward.x)
 var ratio:=.60*scale
 var dust_reach:=lerpf(0.0,.999,smoothstep(.04,1.24,elapsed)) if deliberate else 1.-exp(-wave_time*6.7)
 var dust_fade:=smoothstep(0.,.05,elapsed)*(1.-smoothstep(.61,2.04,elapsed) if deliberate else 1.-smoothstep(.34,1.15,wave_time))
 for j in 18:
  var q:=float(j)/17.*2.-1.
  var at:=floor_point+(forward*(154.+sin(float(j)*2.39)*105.)+across*q*64.)*dust_reach*ratio-Vector2(0,14.*sin(PI*wave_time/1.15)*ratio)
  var sz:=Vector2(105+float(j%7)*23,44+float(j%3)*12)*(1.+dust_reach*.36)*ratio
  _light(layer,texture,at,sz,Color("795737"),dust_fade*.30)
  _light(layer,texture,at+Vector2(-3,-4)*ratio,sz*.78,Color("d29a5b"),dust_fade*.36)
 if elapsed>1.46 if deliberate else wave_time>.71:return
 var fade:=smoothstep(0.,.032,elapsed)*(1.-smoothstep(.51,1.45,elapsed) if deliberate else 1.-smoothstep(.17,.65,wave_time))
 var reach:=lerpf(0.0,.997,smoothstep(.04,.91,elapsed)) if deliberate else 1.-exp(-wave_time*8.3)
 if deliberate:
  for band in 5:
   var from_ground:=float(band)/4.
   _light(layer,texture,floor_point+forward*from_ground*reach*132.*ratio,Vector2(143,32)*ratio,Color("d98745"),fade*.30*(1.-from_ground*.4))
 var flash:=1.-smoothstep(.056,.18,elapsed)
 _light(layer,texture,hit+forward*34.*ratio,Vector2(521,121)*ratio,Color("b43b18"),flash*.98)
 _light(layer,texture,hit+forward*27.*ratio,Vector2(357,68)*ratio,Color("f27324"),flash*.96)
 _light(layer,texture,hit+forward*16.*ratio,Vector2(134,30)*ratio,Color("ffc467"),flash*.97)
 _light(layer,texture,hit+forward*3.*ratio,Vector2(64,18)*ratio,Color("fff1b1"),flash*.94)
 for j in 18:
  var v:=float(j)/17.*2.-1.
  var env:=pow(maxf(.0,1.-absf(v)),.53)
  var longitudinal:=54.+223.*(1.-v*v)
  var wave_origin:=floor_point if deliberate else hit
  var breadth:=.68 if deliberate else 1.0
  var p:=wave_origin+(forward*longitudinal*1.90+across*(v*143.+sin(v*9.)*16.)*breadth)*reach*ratio
  _light(layer,texture,p,(Vector2(310,70) if deliberate else Vector2(332,121))*ratio,Color("b13914"),fade*(.21 if deliberate else .33)*env)
  _light(layer,texture,p-forward*79.*ratio,(Vector2(193,43) if deliberate else Vector2(193,60))*ratio,Color("fa903a"),fade*.39*env)
  _light(layer,texture,p-forward*134.*ratio,Vector2(168,44)*ratio,Color("e4a05a"),fade*.21*env)
 for j in 5:
  var dir:=forward+across*(sin(float(j)*2.39996)*.24)
  var at:=hit+(dir*(54.+float((j*43)%134))*reach+Vector2(0.,elapsed*elapsed*16.))*ratio
  var grit:=(1.-smoothstep(.08,.28+float(j%5)*.025,elapsed))*smoothstep(0.,.037,elapsed)
  if grit>.002:layer.draw_line(at-dir*18.*ratio,at,Color("d78c38",grit*.61),2.8*ratio,true)

## TEST36 solo presentation: compact contact plus separate floor aftershock.
static func draw_readable_flash(layer:CanvasItem, texture:Texture2D, hit:Vector2, direction:Vector2, elapsed:float)->void:
 if elapsed<0.0 or elapsed>=.23:return
 var forward:=direction.normalized() if direction.length_squared()>.00001 else Vector2.RIGHT
 var flash:=1.0-smoothstep(.023,.14,elapsed)
 _light(layer,texture,hit,Vector2(76,51),Color("f27a33"),flash*.71)
 _light(layer,texture,hit,Vector2(35,25),Color("fff1b1"),flash*.97)
 var fade:=1.0-smoothstep(.026,.23,elapsed)
 for j in 5:
  var d:=forward.rotated(lerpf(-.65,.65,float(j)/4.0))
  var p:=hit+d*lerpf(7.0,42.0,smoothstep(0.0,.19,elapsed))
  layer.draw_line(p-d*(4.0+10.0*fade),p,Color("ffc785",fade*.78),1.4,true)

static func draw_readable_floor(layer:CanvasItem, texture:Texture2D, origin:Vector2, direction:Vector2, elapsed:float)->void:
 if elapsed<0.0 or elapsed>=2.04:return
 var forward:=direction.normalized() if direction.length_squared()>.00001 else Vector2.RIGHT
 var across:=Vector2(-forward.y,forward.x)*.58
 var spread:=smoothstep(.05,1.24,elapsed)
 var fade:=smoothstep(.04,.17,elapsed)*(1.0-smoothstep(.57,2.04,elapsed))
 for j in 10:
  var a:=float(j)*2.39996
  var p:=origin+spread*(forward*(40.0+float(j)*18.0)+across*sin(a)*83.0)
  _light(layer,texture,p,Vector2(36+7*(j%3),12+4*(j%3)),Color("b88a61"),fade*(.10+.12*absf(sin(a))))
 var wave_alpha:=smoothstep(.018,.085,elapsed)*(1.0-smoothstep(.54,1.46,elapsed))
 if wave_alpha<.005:return
 for band in 2:
  var phase:=smoothstep(.04+float(band)*.17,.91+float(band)*.17,elapsed)
  var alpha:=wave_alpha*(1.0 if band==0 else .44)*smoothstep(.02,.18,phase)
  if alpha<.005:continue
  var last:=Vector2.INF
  for j in 25:
   var u:=float(j)/24.0*2.0-1.0
   var envelope:=pow(maxf(0.0,1.0-u*u),.65)
   var p:=origin+(forward*(63.0+238.0*envelope)+across*(u*149.0+sin(u*10.0)*8.0))*phase*(1.0 if band==0 else .82)
   if last!=Vector2.INF:
    layer.draw_line(last,p,Color("d87c45",alpha*.20*envelope),10.0,true)
    layer.draw_line(last,p,Color("f3a762",alpha*.43*envelope),2.3,true)
   if j%3==0:
    _light(layer,texture,p,Vector2(46,15),Color("ee9259"),alpha*.39*envelope)
   last=p

## TEST48: the old orange light rides the same low, weighted front as the
## dust. It starts on the actual club's ground projection, never on a foe.
static func draw_ground_wave(layer:CanvasItem, texture:Texture2D, origin:Vector2, finish:Vector2, age:float, travel:float)->void:
 if age<0. or age>1.04:return
 var delta:=finish-origin
 var forward:=delta.normalized() if delta.length_squared()>.001 else Vector2.RIGHT
 var across:=Vector2(-forward.y,forward.x)*.50
 var dust_alpha:=smoothstep(0.,.028,age)*(1.-smoothstep(.28,.95,age))
 var head:=clampf(age/maxf(.01,travel),0.,1.)
 var flash:=1.-smoothstep(.028,.16,age)
 _light(layer,texture,origin,Vector2(106,28),Color("9f4720"),flash*.94)
 _light(layer,texture,origin,Vector2(69,21),Color("ffac4e"),flash*.94)
 _light(layer,texture,origin,Vector2(29,11),Color("ffe3a7"),flash*.94)
 for j in 16:
  var n:=float(j)
  var off:=sin(n*2.39996)
  var local:=clampf(head*(.39+float(j%6)*.12),0.,1.)
  var scatter:=lerpf(8.,47.,smoothstep(0.,.55,age))*off
  var p:=origin+delta*local+across*scatter
  var dust_size:=(Vector2(37.,17.)+Vector2(7.,2.)*float(j%4))*(.72+smoothstep(0.,.53,age)*.47)
  _light(layer,texture,p,dust_size,Color("755137"),dust_alpha*.90)
  _light(layer,texture,p-Vector2(1.5,1.7),dust_size*.63,Color("c69b6b"),dust_alpha*.77)
  if j<9 and age<.36:
   var grit:=smoothstep(0.,.027,age)*(1.-smoothstep(.11,.36,age))
   var grit_p:=p-forward*float(j%4)*2.-Vector2(0,(3.+float(j%3)*3.)*sin(age/.36*PI))
   layer.draw_line(grit_p-forward*4.,grit_p,Color("d6a26d",grit*.82),1.8,true)
 for band in 2:
  var time:=age-float(band)*.069
  var phase:=clampf(time/maxf(.01,travel),0.,1.)
  var wave_alpha:=smoothstep(0.,.026,time)*(1.-smoothstep(travel+.025,.47,time))*(1. if band==0 else .45)
  if wave_alpha<.005:continue
  var prev:=Vector2.INF
  for j in 21:
   var q:=float(j)/20.*2.-1.
   var weight:=pow(maxf(0.,1.-q*q),.60)
   var at:=origin+delta*(phase*(.80+weight*.20)) + across*(q*lerpf(11.,68.,phase))
   if prev!=Vector2.INF:
    layer.draw_line(prev,at,Color("9a471e",wave_alpha*weight*.87),9.,true)
    layer.draw_line(prev,at,Color("ffa745",wave_alpha*weight*.96),4.4,true)
    layer.draw_line(prev-Vector2(0,1.),at-Vector2(0,1.),Color("ffdb91",wave_alpha*weight*.96),1.75,true)
   if j%4==0:_light(layer,texture,at,Vector2(58,19),Color("f79c3c"),wave_alpha*weight*.83)
   prev=at
