class_name TravelTrail
extends Node2D
# Pending route stays world-anchored; only the travelled portion fades away.
var navigation: AutoTravel
var crumbs:Array[Dictionary]=[]
var previous:=Vector2.INF
func _init(owner_navigation:AutoTravel)->void:
	navigation=owner_navigation
	z_index=2
func _process(delta:float)->void:
	for crumb in crumbs:crumb.age+=delta
	crumbs=crumbs.filter(func(c):return c.age<.5)
	var p:Vector2=navigation.app.world.player.position
	if navigation.action!="":
		if previous.is_finite() and previous.distance_to(p)>3:
			crumbs.append({"a":previous,"b":p,"age":0.0});previous=p
		elif not previous.is_finite():previous=p
	else:previous=Vector2.INF
	queue_redraw()
func _draw()->void:
	for c in crumbs:draw_line(c.a,c.b,Color(1,.92,.65,.32*(1-c.age/.5)),2,true)
	if navigation.action=="":return
	var points:=PackedVector2Array([navigation.app.world.player.position]);points.append_array(navigation.path)
	var offset:=0.0
	for i in points.size()-1:
		var length:=points[i].distance_to(points[i+1])
		if length<.01:continue
		var at:=offset
		while at<length:
			var end:=minf(at+6,length)
			var a:=points[i].lerp(points[i+1],at/length)
			var b:=points[i].lerp(points[i+1],end/length)
			draw_line(a,b,Color(.35,.23,.08,.28),5.5,true)
			draw_line(a,b,Color(1,.95,.75,.60),3.5,true)
			at+=15
		offset=at-length
