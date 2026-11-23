extends RefCounted
## A screen-space travelling shield wake for a charged ordinary counter.
## It never selects a target or supplies area damage.
static func duration(start:Vector2,finish:Vector2)->float:
	return clampf(.16+start.distance_to(finish)*.0015,.22,.51)

static func draw(layer:Node2D,start:Vector2,finish:Vector2,progress:float)->void:
	var t:=clampf(progress,0.,1.)
	var ax:=start.direction_to(finish)
	if ax.length_squared()<.001:ax=Vector2.RIGHT
	var cross:=ax.orthogonal()
	var head:=start.lerp(finish,t)
	var tail:=start.lerp(finish,maxf(0.,t-.22))
	for i in 4:
		var shade:=1.-float(i)*.21
		var a:=shade*(1.-smoothstep(.87,1.,t)*.32)
		var mark:=head.lerp(tail,float(i)/3.0)
		var width:=lerpf(14.,25.,t)*shade
		var line:=PackedVector2Array()
		for j in 16:
			var u:=float(j)/15.
			var s:=u*2.-1.
			line.append(mark+cross*s*width+ax*(1.-s*s)*width*.42)
		layer.draw_polyline(line,Color("ca6329",a*.30),12.*shade,true)
		layer.draw_polyline(line,Color("ffad55",a*.66),5.4*shade,true)
		layer.draw_polyline(line,Color("fff1ad",a*.98),1.65*shade,true)
		for j in 3:
			var f:=float(j-1)
			var speck:=mark+cross*f*width*.66-ax*(5.+float(i)*8.)
			layer.draw_circle(speck,1.3*shade,Color("ffcc80",a*.65),true,-1.,true)

static func draw_pop(layer:Node2D,where:Vector2,age:float)->void:
	if age<0. or age>.23:return
	var t:=age/.23
	var a:=1.-smoothstep(.06,1.,t)
	layer.draw_circle(where,6.+t*16.,Color("ffbd61",a*.20),true,-1.,true)
	layer.draw_circle(where,3.+t*8.,Color("ffea9f",a*.75),true,-1.,true)
	for j in 7:
		var ray:=Vector2.from_angle(float(j)*TAU/7.+.3)
		var mark:=where+ray*(4.+t*15.)
		layer.draw_line(mark,mark+ray*(3.+float(j%3)),Color("fff0b4",a*.85),1.2,true)

# The directional-looking shield lead is visual only. After the strike the
# warm ground resonance closes a complete loop and rolls across the arena.
const FIELD_SECONDS:=.80
const GROUND_ASPECT:=.58

static func fan_range(origin:Vector2,destination:Vector2,short_cast:bool)->float:
	return clampf(origin.distance_to(destination)+(16. if short_cast else 0.),56.,124.)


# Preview only: one continuous soil impulse, not a burst followed by separate rings.


# Preview only: the struck shield sends a single airborne bronze pressure wave.
static func draw_fan(layer:Node2D,shield:Vector2,origin:Vector2,forward:Vector2,reach:float,progress:float,draw_shield:bool=true,draw_ground:bool=true)->void:
	var t:=clampf(progress,0.,1.)
	if draw_shield:
		var hit:=smoothstep(0.,.027,t)*(1.-smoothstep(.19,.36,t))
		if hit>.002:
			var bend:=forward.orthogonal()*sin(t*133.)*4.45*hit
			var vapor:=Color(1.,.63,.38,hit*.92)
			var bell_edge:=PackedVector2Array()
			for j in 19:
				var theta:=lerpf(-1.3,1.3,float(j)/18.)+forward.angle()
				bell_edge.append(shield+bend+Vector2(cos(theta)*10.6,sin(theta)*8.0))
			layer.draw_polyline(bell_edge,Color(.99,.36,.075,hit*.49),7.5,true)
			layer.draw_polyline(bell_edge,vapor,2.6,true)
			layer.draw_circle(shield+bend,2.45,Color(1.,.74,.52,hit*.86),true,-1.,true)
	if not draw_ground:return
	var drift:=smoothstep(.14,.66,t)
	var center:=shield.lerp(origin-Vector2(0,37.),drift*.82)+forward*minf(12.,reach*.13)*(1.-drift)
	var elevation:=lerpf(.66,.44,smoothstep(.04,.49,t))
	var extent:=0.
	for corner:Vector2 in [Vector2(12,105),Vector2(948,105),Vector2(12,470),Vector2(948,470)]:
		var d:=corner-(origin-Vector2(0,28.))
		extent=maxf(extent,Vector2(d.x,d.y/elevation).length())
	var spread:=lerpf(.67,PI,smoothstep(.08,.33,t))
	var radius:=2.+extent*pow(t,1.33)
	var axis:=forward.angle()
	var strength:=smoothstep(.0,.055,t)*(1.-smoothstep(.49,1.,t))
	var body_width:=lerpf(10.,33.,smoothstep(.02,.56,t))

	# A single tessellated surface; neither overlaps nor sharp material joins.
	var points:=PackedVector2Array()
	var colors:=PackedColorArray()
	var indices:=PackedInt32Array()
	var resolution:=168
	var bands:=14
	var hot:=1.-smoothstep(.09,.67,t)
	var open_end:=1.-smoothstep(.22,.33,t)
	var sheen_gate:=smoothstep(.045,.15,t)*(1.-smoothstep(.59,.91,t))
	var travel:=.27+t*.83
	for j in range(resolution+1):
		var f:=float(j)/float(resolution)
		var a:=axis+lerpf(-spread,spread,f)
		var n:=Vector2(cos(a),sin(a)*elevation+cos(a)*.08)
		var profile:=1.+sin(a*3.+t*5.5)*.045
		var flow:=sin(a*5.+t*7.)*3.5+sin(a*12.-t*9.)*1.2
		var r:=radius*profile+flow*smoothstep(.1,.40,t)
		var taper:=lerpf(pow(maxf(.016,sin(PI*f)),.44),1.,smoothstep(.26,.37,t))
		var w:=body_width*taper*(.75+.18*sin(a*4.+t*2.9)+.10*sin(a*9.-t*4.9))
		var phase:=TAU*(f-travel)
		var gloss:=pow(.5+.5*cos(phase),17.)+.58*pow(.5+.5*cos(phase-2.62),24.)
		var end_alpha:=lerpf(1.,smoothstep(0.,.155,f)*(1.-smoothstep(.845,1.,f)),open_end)
		for k in range(bands+1):
			var v:=float(k)/float(bands)
			var x:=lerpf(-1.45,1.53,v)
			points.append(center+n*maxf(.30,r+w*x))
			var soft:=smoothstep(0.,.21,v)*(1.-smoothstep(.72,1.,v))
			var crest:=exp(-pow((x-.22)/.27,2.))
			var face:=exp(-pow((x-.08)/.85,2.))
			var tint:=Color(.95,.32,.076).lerp(Color(1.,.62,.30),face*.70+crest*.23)
			tint=tint.lerp(Color(1.,.72,.43),crest*.43)
			tint=tint.lerp(Color(1.,.87,.65),clampf(gloss*sheen_gate*crest*1.39,0.,.98))
			tint.a=strength*end_alpha*soft*clampf(.19+face*(.25+.12*hot)+crest*(.26+.39*gloss*sheen_gate),0.,.95)
			colors.append(tint)
	for j in range(resolution):
		for k in range(bands):
			var a:=j*(bands+1)+k
			var b:=a+bands+1
			indices.append_array(PackedInt32Array([a,b,b+1,a,b+1,a+1]))
	RenderingServer.canvas_item_add_triangle_array(layer.get_canvas_item(),indices,points,colors)
