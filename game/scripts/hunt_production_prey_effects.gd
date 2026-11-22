extends RefCounted
## TEST35 artwork in battlefield-local pixels. Caller supplies native phase, sampled
## muzzle and feet, anchored takeoff origin, and verified impact (no hit simulation).
## Draw from Node2D draw callback; use independent state/history per prey.
const DEER_DUST_LIFETIME := 2.5
var ring_halo: GradientTexture2D
var ring_band: GradientTexture2D
var floor_light_wash: GradientTexture2D
var floor_light_halo: GradientTexture2D
var floor_light_core: GradientTexture2D
var soft: GradientTexture2D
var impact_sprite: Texture2D

func _init(hit_sprite: Texture2D = null) -> void:
	impact_sprite=hit_sprite
	ring_halo=_new_ring_light(PackedFloat32Array([0,.28,.46,.61,.76,.91,1]),PackedFloat32Array([.10,.12,.15,.27,.18,.035,0]))
	ring_band=_new_ring_light(PackedFloat32Array([0,.53,.60,.65,.68,.72,.79,1]),PackedFloat32Array([0,0,.035,.22,.91,.30,.035,0]))
	floor_light_wash=_new_ring_light(PackedFloat32Array([0,.24,.45,.58,.70,.82,1]),PackedFloat32Array([.14,.17,.28,.46,.37,.12,0]))
	floor_light_halo=_new_ring_light(PackedFloat32Array([0,.41,.55,.62,.70,.83,1]),PackedFloat32Array([0,.03,.14,.55,.40,.11,0]))
	floor_light_core=_new_ring_light(PackedFloat32Array([0,.54,.59,.612,.631,.65,.71,1]),PackedFloat32Array([0,0,.05,.83,.88,.19,0,0]))
	soft=_new_ring_light(PackedFloat32Array([0,.18,.48,1]),PackedFloat32Array([.95,.65,.18,0]))

func _soft_light(center:Vector2,extent:Vector2,tint:Color,alpha:float,layer:Node2D)->void:
	if alpha>0.0:layer.draw_texture_rect(soft,Rect2(center-extent*.5,extent),false,Color(tint,alpha))

## Bounds of an actual projected floor ellipse, not head/camera screen-center.
func draw_ground_ring(layer: Node2D, bounds: Rect2, allied: bool) -> void:
	if not bounds.has_area():return
	var spread:=bounds.size/.62
	var disk:=Rect2(bounds.get_center()-spread*.5,spread)
	var rich:=Color("1b9df0") if allied else Color("e33830")
	var core:=Color("c2f6ff") if allied else Color("ffbeb1")
	layer.draw_texture_rect(floor_light_wash,disk,false,Color(rich,.86))
	layer.draw_texture_rect(floor_light_halo,disk,false,Color(rich,.90))
	layer.draw_texture_rect(floor_light_core,disk,false,Color(core,.96))

## Continuous charge trail history: call only for actual native movement.
static func sample_wake(wake: Array, tip: Vector2, foot: Vector2, clock: float) -> void:
	prune_wake(wake,clock)
	if not tip.is_finite() or not foot.is_finite() or not is_finite(clock):return
	if not wake.is_empty() and (clock-float(wake.back().at)<.025 or tip.distance_squared_to(wake.back().tip)<1.0):return
	wake.append({"tip":tip,"foot":foot,"at":clock})
	if wake.size()>24:wake.pop_front()

static func prune_wake(wake: Array, clock: float) -> void:
	while not wake.is_empty() and clock-float(wake.front().at)>=.53:wake.pop_front()

## draw_charge progress: <0=no windup, [0,1)=gather then center hold,
## >=1=tip glow only if armed; an outstanding wake can decay in all states.
## draw_impact p: normalized elapsed, center and floor_point are caller anchors.
func _new_ring_light(stops:PackedFloat32Array,levels:PackedFloat32Array)->GradientTexture2D:
	var gradient:=Gradient.new()
	gradient.offsets=stops
	var colors:=PackedColorArray()
	for alpha in levels:colors.append(Color(1,1,1,alpha))
	gradient.colors=colors
	var texture:=GradientTexture2D.new()
	texture.width=128;texture.height=128
	texture.fill=GradientTexture2D.FILL_RADIAL
	texture.fill_from=Vector2(.5,.5);texture.fill_to=Vector2(1,.5)
	texture.gradient=gradient
	return texture

func draw_dust(origin:Vector2,elapsed:float,layer:Node2D)->void:
	if elapsed<0 or elapsed>=DEER_DUST_LIFETIME:return
	var linger:=smoothstep(.14,.58,elapsed)*(1.0-smoothstep(1.86,DEER_DUST_LIFETIME,elapsed))
	if linger>.001:
		var settle:=clampf(elapsed/DEER_DUST_LIFETIME,0,1)
		_soft_light(origin+Vector2(settle*10,0),Vector2(172,35)*lerpf(.75,1.15,settle),Color("7d5b3e"),linger*.67,layer)
		for k in 10:
			var theta:=float(k)*2.39996
			var puff:=Vector2(cos(theta)*lerpf(26,66,settle),sin(theta)*lerpf(7,13,settle))
			var tone:=Color("8a6648").lerp(Color("dcaf78"),float(k%4)/3.0)
			_soft_light(origin+puff,Vector2(44,17)*lerpf(.82,1.23,settle),tone,linger*.61,layer)
	if elapsed>=.86:return
	var t:=elapsed/.86
	var dusty:=smoothstep(0,.060,elapsed)*(1.0-smoothstep(.38,.86,elapsed))
	_soft_light(origin,Vector2(155,49)*lerpf(.40,1.04,sqrt(t)),Color("674632"),dusty*.77,layer)
	_soft_light(origin+Vector2(7,-6),Vector2(125,32)*lerpf(.43,1.17,sqrt(t)),Color("ce965d"),dusty*.92,layer)
	for k in 20:
		var theta:=float(k)*2.39996
		var ray:=Vector2(cos(theta),sin(theta)*.34)
		var reach:=lerpf(5,48+float(k%4)*8,sqrt(t))
		var center:=origin+ray*reach+Vector2(0,-(14+float(k%4)*4.5)*sin(t*2.2))
		var puff:=Vector2(26,19)*lerpf(.70,1.54,t)
		var a0:=dusty*(.67+.28*sin(float(k)*1.39))
		_soft_light(center+Vector2(0,3),puff*1.55,Color("634632"),a0*.91,layer)
		var tone:=Color("a77651").lerp(Color("f0c586"),float(k%5)/4.0)
		_soft_light(center+Vector2(-2,-2),puff*1.15,tone,a0,layer)
	for k in 22:
		var theta:=float(k)*2.39996
		var radius:=lerpf(8,53+float(k%5)*7,sqrt(t))
		var grit:=origin+Vector2(cos(theta),sin(theta)*.37)*radius+Vector2(0,-sin(t*PI)*float(k%5)*8)
		layer.draw_circle(grit,lerpf(2.1,.75,t),Color("886146",dusty*.78),true,-1,true)

func draw_charge(hoof:Vector2,tip:Vector2,progress:float,armed:bool,wake:Array,clock:float,layer:Node2D)->void:
	var jade:=Color("619cbf")
	var silver:=Color("e3f6ff")
	for j in wake.size():
		var sample:Dictionary=wake[j]
		var elapsed:=clock-float(sample.at)
		var fade:=1.0-smoothstep(.02,.53,elapsed)
		var foot:Vector2=sample.foot
		var point:Vector2=sample.tip
		if j>0:
			var prev:Vector2=wake[j-1].tip
			layer.draw_line(prev,point,Color(jade,.44*fade),14.0*fade+1.0,true)
			layer.draw_line(prev,point,Color(silver,.91*fade),3.5*fade+.7,true)
		_soft_light(point,Vector2(31,20),jade,fade*.44,layer)
		_soft_light(foot,Vector2(49,14),jade,fade*.26,layer)
		if j%2==0:
			var dust:=point+Vector2(sin(float(j)*2.2)*8,-elapsed*22)
			_soft_light(dust,Vector2(9,6),silver,.57*fade,layer)
	if progress<0:return
	if progress>=1.0:
		if armed:
			_soft_light(tip,Vector2(37,24),jade,.70,layer)
			_soft_light(tip,Vector2(14,10),silver,.91,layer)
		return
	var power:=smoothstep(.01,.20,progress)
	var scale_r:=lerpf(1.0,0.04,smoothstep(.07,.65,progress))
	var r:=Vector2(68,26)*scale_r
	var alpha:=power*(1.0-smoothstep(.59,.68,progress))
	layer.draw_texture_rect(ring_halo,Rect2(hoof-r*.8,r*1.6),false,Color(jade,alpha*.78))
	layer.draw_texture_rect(ring_band,Rect2(hoof-r*.5,r),false,Color(silver,alpha*.90))
	var focus:=smoothstep(.56,.66,progress)
	var flight:=hoof
	_soft_light(flight,Vector2(24,18),jade,focus*.72,layer)
	_soft_light(flight,Vector2(40,30)*lerpf(1.0,1.4,smoothstep(.94,1.0,progress)),silver,focus*.94,layer)
	for j in 13:
		var a0:=float(j)*2.39996+progress*.7
		var drift:=Vector2(cos(a0),sin(a0)*.32)*scale_r*(36.0+float(j%3)*9.0)
		var speck:=hoof+drift+Vector2(0,-sin(progress*PI)*float(j%4)*3)
		_soft_light(speck,Vector2(8,5),silver,power*(1.0-focus)*(.45+.28*cos(float(j)+progress*9)),layer)

func draw_impact(effect:Dictionary,p:float,layer:Node2D)->void:
	if p<0.0 or p>=1.0:return
	var at:Vector2=effect.center
	var fade:=1.0-smoothstep(.02,1.0,p)
	var peak:=1.0-smoothstep(.01,.38,p)
	var jade:=Color("79b6d8")
	var sil:=Color("eefaff")
	_soft_light(at,Vector2(124,85),jade,fade*.68,layer)
	_soft_light(at,Vector2(46,34),sil,peak*.99,layer)
	var extent:=Vector2(78,57)
	if impact_sprite!=null:layer.draw_texture_rect(impact_sprite,Rect2(at-extent*.5,extent),false,Color(sil,peak*.88))
	var feet:Vector2=effect.floor_point
	var span:=Vector2(lerpf(35,118,p),lerpf(14,39,p))
	layer.draw_texture_rect(ring_band,Rect2(feet-span*.5,span),false,Color(jade,fade*.58))
	for j in 14:
		var direction:=Vector2.from_angle(float(j)*2.39996)*Vector2(1,.57)
		var reach:=lerpf(5,48+float(j%3)*13,sqrt(p))
		_soft_light(at+direction*reach,Vector2(11,8),sil,fade*.75,layer)
