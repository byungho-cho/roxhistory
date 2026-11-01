class_name RegionAmbience
extends Node2D

# Original procedural cartographic decorations, not gameplay actors. Every
# position is a map coordinate; this node owns no input, timers, or audio.
var map:Control
var clock:=0.0
var redraw_clock:=0.0
var enabled:=true
var water:Image
var glints:Array[Vector2]=[]
var mist:GradientTexture2D
var exclusions:Array[Rect2]=[]
const FISH_CENTERS:=[Vector2(1200,240),Vector2(220,510),Vector2(870,830)]

func _init(owner_map:Control) -> void:map=owner_map;name="MapAmbience"
func _ready() -> void:
	water=FigmaArt.texture("94b86.png").get_image()
	if water.is_compressed():water.decompress()
	var rng:=RandomNumberGenerator.new();rng.seed=30313
	for i in 180:
		var at:=Vector2(rng.randf_range(120,1450),rng.randf_range(140,850))
		if is_water(at) and glints.size()<34:glints.append(at)
	var gradient:=Gradient.new();gradient.colors=PackedColorArray([Color(.94,.98,1,.18),Color(.94,.98,1,0)])
	mist=GradientTexture2D.new();mist.gradient=gradient;mist.width=128;mist.height=128
	mist.fill=GradientTexture2D.FILL_RADIAL;mist.fill_from=Vector2(.5,.5);mist.fill_to=Vector2(1,.5)
	queue_redraw()
func is_water(point:Vector2) -> bool:
	if not Rect2(Vector2.ZERO,RegionCatalog.BASE).has_point(point):return false
	var uv:=point/RegionCatalog.BASE
	var color:=water.get_pixel(clampi(int(uv.x*water.get_width()),0,water.get_width()-1),clampi(int(uv.y*water.get_height()),0,water.get_height()-1))
	return color.b>color.g*1.1 and color.g>color.r*1.08 and color.b>.22
func _process(delta:float) -> void:
	if not enabled or not map.app.application_active or map.app.modal:return
	clock+=minf(delta,.1);redraw_clock+=delta
	if redraw_clock>=1.0/30:queue_redraw();redraw_clock=0
func refresh_exclusions() -> void:
	exclusions.clear()
	if is_instance_valid(map.markers):
		for key in RegionCatalog.REGIONS:exclusions.append(map.marker_rect(key).grow(8*map.ui_factor))
	if is_instance_valid(map.ui_root):
		if map.panel_visible:
			var panel:Rect2=map.details.get_global_rect()
			exclusions.append(Rect2(panel.position-Vector2(10,120)*map.ui_factor,panel.size+Vector2(20,130)*map.ui_factor))
		for control in map.ui_root.find_children("*","Button",true,false):
			if control.is_visible_in_tree() and (map.panel_visible or not map.details.is_ancestor_of(control)):exclusions.append(control.get_global_rect())
		exclusions.append(map.ui_root.get_node("RegionHeading").get_global_rect())
func visibility_at(point:Vector2,margin:float=24) -> float:
	var screen:Vector2=map.camera.project(point)
	if not Rect2(Vector2.ZERO,map.size).grow(40).has_point(screen):return 0
	var alpha:=1.0
	for rect in exclusions:
		var nearest:=Vector2(clampf(screen.x,rect.position.x,rect.end.x),clampf(screen.y,rect.position.y,rect.end.y))
		alpha=minf(alpha,smoothstep(0,margin*map.ui_factor,screen.distance_to(nearest)))
	return alpha
func unobstructed(point:Vector2,margin:float=24) -> bool:return visibility_at(point,margin)>.98
func ring(center:Vector2,radius:Vector2,color:Color,width:float) -> void:
	var points:=PackedVector2Array()
	for i in 33:
		var angle:=TAU*i/32.0;points.append(center+Vector2(cos(angle),sin(angle))*radius)
	draw_polyline(points,color,width,true)
func fish_pose(index:int,time_value:float) -> Dictionary:
	var cycle:=12.0+index*3.7
	var phase:=fposmod(time_value+index*4.3,cycle)/cycle
	var t:=phase/.56
	return {"at":FISH_CENTERS[index]+Vector2(lerpf(-42,42,t),sin(t*TAU+index)*9),"alpha":sin(PI*clampf(t,0,1))*.70 if phase<.56 else 0.0,"phase":t}
func draw_fish(point:Vector2,phase:float,alpha:float,k:float) -> void:
	var at:Vector2=map.camera.project(point)
	draw_set_transform(at,sin(phase*TAU)*.12,Vector2.ONE*k)
	# A cool body, pale back, separate tail and fins suggest a fish below water.
	var body:=PackedVector2Array([Vector2(-10,0),Vector2(-5,-4),Vector2(4,-4),Vector2(10,-1),Vector2(11,1),Vector2(4,4),Vector2(-5,3)])
	draw_colored_polygon(body,Color(.08,.33,.43,alpha))
	var wag:=sin(clock*8+phase)*2.2
	draw_colored_polygon(PackedVector2Array([Vector2(-9,0),Vector2(-16,-5+wag),Vector2(-15,5+wag)]),Color(.14,.46,.53,alpha*.9))
	draw_colored_polygon(PackedVector2Array([Vector2(-4,-2),Vector2(1,-7),Vector2(3,-2)]),Color(.32,.69,.69,alpha*.7))
	draw_polyline(PackedVector2Array([Vector2(-6,-1),Vector2(0,-2),Vector2(7,-1)]),Color(.65,.90,.83,alpha*.8),1.2,true)
	draw_circle(Vector2(7,0),.8,Color(.02,.12,.18,alpha))
	ring(Vector2(-8,2),Vector2(19,5),Color(.7,.94,1,alpha*.25),.8)
	draw_set_transform(Vector2.ZERO)
func draw_bird(point:Vector2,phase:float,alpha:float,k:float) -> void:
	var at:Vector2=map.camera.project(point)
	var flap:=sin(phase)*7
	draw_set_transform(at,-.22,Vector2.ONE*k)
	var left:=PackedVector2Array([Vector2(0,1),Vector2(-6,-3),Vector2(-16,-3-flap),Vector2(-10,2),Vector2(-3,4)])
	var right:=PackedVector2Array([Vector2(0,1),Vector2(6,-3),Vector2(16,-3-flap),Vector2(10,2),Vector2(3,4)])
	for wing in [left,right]:
		draw_colored_polygon(wing,Color(.94,.94,.84,alpha))
		draw_polyline(wing,Color(.25,.38,.40,alpha*.6),.9,true)
	draw_line(Vector2(0,-4),Vector2(0,5),Color(.98,.96,.85,alpha),3,true)
	draw_circle(Vector2(0,-5),2,Color(.98,.96,.85,alpha),true,-1,true)
	draw_line(Vector2(0,-6),Vector2(1,-8),Color(.90,.68,.27,alpha),1.4,true)
	draw_set_transform(Vector2.ZERO)
func _draw() -> void:
	if not enabled or not water:return
	refresh_exclusions()
	var k:float=map.factor*map.zoom
	for i in glints.size():
		var point:=glints[i]
		if not unobstructed(point):continue
		var pulse:=pow(maxf(0,sin(clock*(.65+i*.017)+i*2.37)),7)
		if pulse<.03:continue
		var at:Vector2=map.camera.project(point)
		draw_line(at-Vector2(5,0)*k,at+Vector2(5,0)*k,Color(.76,.94,1,pulse*.37),1.2*k,true)
		draw_line(at-Vector2(0,2)*k,at+Vector2(0,2)*k,Color(.85,.98,1,pulse*.24),.8*k,true)
	for i in FISH_CENTERS.size():
		var pose:=fish_pose(i,clock)
		for j in 2:
			var point:Vector2=pose.at+Vector2(-23*j,12*j)
			if pose.alpha>.01 and is_water(point):draw_fish(point,pose.phase+j,pose.alpha*(1-.22*j)*visibility_at(point,40),k*(1-.15*j))
	for flock in 2:
		var duration:=18.0+flock*5
		var phase:=fposmod(clock+flock*10,duration)
		if phase>8:continue
		var progress:=phase/8
		var alpha:=smoothstep(0,.12,progress)*(1-smoothstep(.85,1,progress))*.84
		var from:=Vector2(950,200) if flock==0 else Vector2(180,360)
		var to:=Vector2(1370,290) if flock==0 else Vector2(390,620)
		for j in 3:
			var point:=from.lerp(to,progress)+Vector2(-j*26,sin(progress*PI)*14+j*14)
			draw_bird(point,clock*5.5+j*.9,alpha*visibility_at(point,48),k*(.75+j*.07))
	# Slow, translucent edge clouds. No full-screen fog or camera motion.
	for i in 2:
		var center:=Vector2(90,260) if i==0 else Vector2(1430,70)
		center+=Vector2(sin(clock*(.045+i*.013)+i)*35,cos(clock*.031+i)*12)
		if not unobstructed(center,65):continue
		for j in 5:
			var extent:=Vector2(150-j*9,90+j*3)*k
			var at:Vector2=map.camera.project(center+Vector2(j*27-55,sin(j*1.7)*13))
			draw_texture_rect(mist,Rect2(at-extent*.5,extent),false)
