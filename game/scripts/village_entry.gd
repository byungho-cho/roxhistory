class_name VillageEntry
extends Control
signal completed

const DURATION:=2.8
const BANK_A:=preload("res://assets/village-entry-v001/cloud_bank_a.png")
const BANK_B:=preload("res://assets/village-entry-v001/cloud_bank_b.png")
const PUFF:=preload("res://assets/village-entry-v001/cloud_puff_c.png")
const WISP:=preload("res://assets/village-entry-v001/cloud_wisp_d.png")
# Centre, width relative to the viewport diagonal, rotation, and peak opacity.
const CLOUDS:=[
	[BANK_A,Vector2(.32,.03),.77,-.12,.94],
	[BANK_B,Vector2(.78,.08),.72,.16,.92],
	[BANK_B,Vector2(.32,.98),.82,.16,.96],
	[BANK_A,Vector2(.78,.95),.74,-.13,.91],
	[PUFF,Vector2(.015,.55),.43,-.19,.83],
	[PUFF,Vector2(.99,.53),.44,.23,.86],
	[WISP,Vector2(.54,.68),.74,-.12,.30],
]

var player:DemoPlayer
var perimeter:Line2D
var perimeter_was_visible:=false
var normal_zoom:float
var elapsed:=0.0
var draw_clouds: bool

func _init(actor:DemoPlayer,debug_outline:Line2D,with_clouds:=true)->void:
	player=actor
	draw_clouds=with_clouds
	perimeter=debug_outline
	normal_zoom=player.zoom_factor
	name="VillageEntry"
	z_index=-1
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func _ready()->void:
	if is_instance_valid(perimeter):
		perimeter_was_visible=perimeter.visible
		perimeter.hide()
	player.direction=Vector2.ZERO
	player.presentation_paused=true
	update_camera(0)

func update_camera(progress:float)->void:
	var center:=get_viewport_rect().size*.5
	var approach:=Vector2(-160,-200)*(1.0-progress)
	player.zoom_at(center,lerpf(DemoPlayer.MIN_ZOOM,normal_zoom,progress),player.global_position+approach)

func _process(delta:float)->void:
	elapsed+=delta
	if elapsed>=DURATION:
		finish()
		return
	update_camera(smoothstep(0.0,DURATION,elapsed))
	if draw_clouds:queue_redraw()

func finish()->void:
	if is_queued_for_deletion():return
	if is_instance_valid(perimeter):perimeter.visible=perimeter_was_visible
	player.zoom_factor=normal_zoom
	player.fit_camera()
	player.resume_camera()
	player.camera.force_update_scroll()
	player.presentation_paused=false
	hide()
	set_process(false)
	queue_free()
	completed.emit()

func _draw()->void:
	if not draw_clouds:return
	var extent:=get_viewport_rect().size
	var progress:=clampf(elapsed/DURATION,0,1)
	for i in CLOUDS.size():
		var cloud:Array=CLOUDS[i]
		var texture:Texture2D=cloud[0]
		var anchor:Vector2=cloud[1]
		var drift:Vector2=(anchor-Vector2(.5,.5))*extent
		var width:float=extent.length()*cloud[2]
		var dimensions:=texture.get_size()*(width/texture.get_width())
		var opacity:float=cloud[4]*(1.0-smoothstep(.15+float(i%3)*.05,1.0,progress))
		draw_set_transform(anchor*extent+drift*progress*.42,cloud[3])
		draw_texture_rect(texture,Rect2(-dimensions*.5,dimensions),false,Color(1,1,1,opacity))
