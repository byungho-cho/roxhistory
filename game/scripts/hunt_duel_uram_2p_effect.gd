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
