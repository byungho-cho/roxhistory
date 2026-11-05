class_name TravelTrail
extends Node2D
# Pending route stays world-anchored; only the travelled portion fades away.
var navigation: AutoTravel
var crumbs:Array[Dictionary]=[]
var previous:=Vector2.INF
func clear()->void:
	crumbs.clear();previous=Vector2.INF;queue_redraw()
func _init(owner_navigation:AutoTravel)->void:
	navigation=owner_navigation
	visibility_layer=2 # World only: the GPS renders natural scenery on layer 1.
	z_index=2
func _process(delta:float)->void:
	if not is_instance_valid(navigation) or not is_instance_valid(navigation.app.world):return
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
	if not is_instance_valid(navigation) or not is_instance_valid(navigation.app.world):return
	var zoom:=maxf(.3,get_canvas_transform().get_scale().x)
	for c in crumbs:draw_circle(c.b,1.6/zoom,Color(1,.92,.65,.32*(1-c.age/.5)))
	var points:=PackedVector2Array([navigation.app.world.player.position])
	var pending:Dictionary=navigation.app.pending_action
	if pending.has("path"):points.append_array(pending.path)
	elif navigation.action!="":points.append_array(navigation.path)
	else:return
	var offset:=0.0
	for i in points.size()-1:
		var length:=points[i].distance_to(points[i+1])
		if length<.01:continue
		var at:=offset
		while at<length:
			var a:=points[i].lerp(points[i+1],at/length)
			draw_circle(a,2.5/zoom,Color(.25,.18,.09,.36))
			draw_circle(a,1.65/zoom,Color(1,.94,.72,.76))
			at+=12.0/zoom
		offset=at-length
