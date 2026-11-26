extends RefCounted
## Shared approved visual only. The combat mode owns all release, contact and buff clocks.
static var glow: Texture2D
const PRIMARY = [Vector3(114,-119,13),Vector3(128,-99,13),Vector3(139,-75,14),Vector3(139,-51,14),Vector3(130,-31,14),Vector3(119,-15,14),Vector3(104,-5,12),Vector3(90,7,11),Vector3(75,15,11),Vector3(58,17,9),Vector3(44,14,8)]
const INNER = [Vector3(87,-71,10),Vector3(101,-58,11),Vector3(102,-44,11),Vector3(91,-27,10),Vector3(81,-16,10),Vector3(68,-6,9),Vector3(53,3,8),Vector3(41,8,7)]
const SMALL = [Vector3(54,-47,6),Vector3(59,-35,6),Vector3(57,-23,6),Vector3(49,-13,6),Vector3(40,-4,6),Vector3(32,4,6)]
const GOLD = [Color("9cadca"),Color("adbed5"),Color("cbd8eb"),Color("eef4ff"),Color("dce7f7")]
const SCALE := .60

static func _glow() -> Texture2D:
	if glow==null:
		var g:=Gradient.new()
		g.offsets=PackedFloat32Array([0.,.32,.70,1.])
		g.colors=PackedColorArray([Color.WHITE,Color(1,1,1,.45),Color(1,1,1,.09),Color(1,1,1,0)])
		var tex:=GradientTexture2D.new()
		tex.gradient=g
		tex.width=64
		tex.height=64
		tex.fill=GradientTexture2D.FILL_RADIAL
		tex.fill_from=Vector2(.5,.5)
		tex.fill_to=Vector2(1,.5)
		glow=tex
	return glow

static func wings(layer:CanvasItem,feet:Vector2,t:float)->void:
	if t<.08 or t>=3.74:return
	var spread:=smoothstep(.08,.56,t)
	var alpha:=spread*(1.-smoothstep(2.82,3.74,t))
	var held:=smoothstep(.71,.82,t)
	var flap:=1.+.065*lerpf(sin(t*13.),sin(.82*13.),held)
	var join:=feet+Vector2(0,-31.-6.6*spread)
	layer.draw_texture_rect(_glow(),Rect2(join-Vector2(33,33),Vector2(66,77)),false,Color(.67,.79,1.,.26*alpha))
	for side in [-1.,1.]:
		for j in PRIMARY.size():_feather(layer,join,Vector2(13.+.55*j,-3.+.25*j),PRIMARY[j],j+1,side,t,spread,flap,alpha)
		for j in INNER.size():_feather(layer,join,Vector2(11.+.4*j,-5.+.76*j),INNER[j],j+2,side,t,spread,flap,alpha)
		for j in SMALL.size():_feather(layer,join,Vector2(9.+.31*j,-2.+1.2*j),SMALL[j],j+3,side,t,spread,flap,alpha)

static func campaign_wing(layer: CanvasItem, age: float, side: float, sweep: Vector2, near: bool) -> void:
	if age < .62 or age >= 3.74:
		return
	var fraction := clampf((age - .62) * 1.3 / .27, 0.0, 1.0)
	var spread := smoothstep(0.0, 1.0, fraction)
	var clock := lerpf(.08, .56, fraction) + maxf(0.0, age - .89)
	var alpha := spread * (1.0 - smoothstep(2.82, 3.74, age))
	var flap := 1.0 + .065 * lerpf(sin(clock * 13.0), sin(.82 * 13.0), smoothstep(.71, .82, clock))
	var origin := Vector2(2.0 * side, 1.2) if near else Vector2.ZERO
	for j in PRIMARY.size():
		_feather(layer, origin, Vector2(13.0 + .55 * j, -3.0 + .25 * j), PRIMARY[j], j + 1, side, clock, spread, flap, alpha, sweep, near)
	for j in INNER.size():
		_feather(layer, origin, Vector2(11.0 + .4 * j, -5.0 + .76 * j), INNER[j], j + 2, side, clock, spread, flap, alpha, sweep, near)
	for j in SMALL.size():
		_feather(layer, origin, Vector2(9.0 + .31 * j, -2.0 + 1.2 * j), SMALL[j], j + 3, side, clock, spread, flap, alpha, sweep, near)

static func _feather(layer:CanvasItem,join:Vector2,root:Vector2,tip:Vector3,j:int,side:float,t:float,spread:float,flap:float,alpha:float,sweep:=Vector2.ZERO,near:=false)->void:
	var axis:=Vector2(side*(.24+.76*spread)*flap,.6+.4*spread)*SCALE
	var a:=join+root*axis
	var j10:=j%10
	var delay:=.008*j10
	var b:=a+(join+Vector2(tip.x,tip.y)*axis-a)*lerpf(.72,1.,smoothstep(.09+delay,.60+delay,t))
	var ripple:=sin((t-.13)*12.4-j*.34)*exp(-maxf(0.,t-.57)*3.4)+.31*smoothstep(.74,.94,t)*sin((t-.74)*6.2-j*.42)
	b+=Vector2(side*(1.1+tip.x*.027),.8+tip.x*.034)*ripple*spread*SCALE
	b += sweep * pow(clampf(tip.x / 139.0, 0.0, 1.0), 1.20) * spread * (.92 if near else .82)
	var d:=b-a
	var n:=d.normalized().orthogonal()*-side
	var w:=tip.z*SCALE
	var c:=(tip.z*spread*.66+1.)*SCALE
	var dir:=d.normalized()
	var top:=b+n*c*.52-dir*c*.20
	var bot:=b-n*c*.48-dir*c*.33
	var points:=_bezier(a,a+d*.36-n*w*.23,a+d*.75+n*w,top)
	var cap:=_bezier(top,b+n*c*.59+dir*c*.55,b-n*c*.36+dir*c*.55,bot)
	points.append_array(cap.slice(1))
	points.append_array(_bezier(bot,a+d*.69-n*w*.87,a+d*.25-n*w*.15,a).slice(1,-1))
	var color:Color=GOLD[j%5]
	color.a = alpha * (.76 if near else .47)
	if Geometry2D.triangulate_polygon(points).is_empty():
		points=Geometry2D.convex_hull(points).slice(0,-1)
	if points.size()>=3:layer.draw_colored_polygon(points,color)
	var hold_center:=(4.5+4.7*sin((t-.83)*2.7))*smoothstep(.83,1.01,t)
	var shine:=exp(-pow((j10-(t-.30)*13.6)/2.55,2.))+.52*smoothstep(.83,1.01,t)*exp(-pow((j10-hold_center)/2.35,2.))
	var rim:=_bezier(a+d*.23,a+d*.47-n*w*.07,a+d*.80+n*w*.72,top)
	rim.append_array(cap)
	layer.draw_polyline(rim,Color(.68,.79,.99,(.16+shine*.21)*alpha),3.,true)
	layer.draw_polyline(rim,Color(.91,.955,1.,(.22+shine*.49)*alpha),1.,true)

static func _bezier(a:Vector2,b:Vector2,c:Vector2,d:Vector2)->PackedVector2Array:
	var p:=PackedVector2Array()
	for i in 10:p.append(a.bezier_interpolate(b,c,d,float(i)/8.))
	return p

const FRAME_FOLDER := "res://assets/effects/saebom-silver-approved/"
const GROUND_ANCHOR := Vector2(96.,113.5)
const FRAME_COUNT := 150
static var frames:Array[Texture2D]=[]

static func prepare()->void:
	if frames.size()==FRAME_COUNT:return
	frames.clear()
	for i in FRAME_COUNT:
		var tex:=load(FRAME_FOLDER+"saebom_buff_silver_%03d.png"%i) as Texture2D
		if tex==null or tex.get_size()!=Vector2(192,192):
			push_error("Approved Saebom silver sequence missing frame %d"%i)
			frames.clear()
			return
		frames.append(tex)

static func frame_index(remaining:float,duration:float)->int:
	if remaining<=0.:return -1
	return clampi(floori(maxf(0.,duration-remaining)*30.+.0001),0,FRAME_COUNT-1)

static func aura(layer:CanvasItem,feet:Vector2,remaining:float,duration:float)->void:
	if remaining<=0. or frames.size()!=FRAME_COUNT:return
	var frame:=frame_index(remaining,duration)
	const SCALE_TO_FIELD:=.76
	layer.draw_texture_rect(frames[frame],Rect2(feet-GROUND_ANCHOR*SCALE_TO_FIELD,Vector2(192.,192.)*SCALE_TO_FIELD),false)
