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
