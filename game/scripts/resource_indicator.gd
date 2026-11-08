class_name ResourceIndicator
extends Node2D

var kind:="wood"
var remaining:=1.0
var total:=1.0
var picture_height:=0.0
var screen_zoom:=1.0
var bar_time:=0.0
var initialized:=false
var action_progress:=0.0

func update_amount(left:float,capacity:float)->void:
	remaining=left;total=maxf(1,capacity);queue_redraw()
	initialized=true

func reveal_bar()->void:
	bar_time=.05;queue_redraw()

func show_action(progress:float)->void:
	action_progress=clampf(progress,0,1);reveal_bar()

func hide_action()->void:
	bar_time=0;queue_redraw()

func _process(delta:float)->void:
	if bar_time>0:
		bar_time=maxf(0,bar_time-delta);queue_redraw()

func update_geometry(height:float,zoom:float)->void:
	picture_height=height;screen_zoom=zoom
	scale=Vector2.ONE/maxf(.1,zoom);queue_redraw()

func _draw()->void:
	if bar_time<=0:return
	# Centre the icon/bar group below the object, shifted two logical screen pixels upward.
	draw_texture_rect(DemoArt.icon(kind),Rect2(-27,-1,12,12),false)
	var bar:=Rect2(-11,2.5,38,5)
	draw_texture_rect_region(preload("res://assets/ui/v034/energy-bar-frame.png"),bar,Rect2(100,250,1975,205),Color(1,1,1,.8))
	var fill:=bar.grow(-1)
	fill.size.x*=action_progress
	if fill.size.x>0:draw_rect(fill,Color(0.52,0.78,0.18,0.8))
