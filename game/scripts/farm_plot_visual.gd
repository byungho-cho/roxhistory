class_name FarmPlotVisual
extends Node2D
## PR 68 review assets: fixed root anchors, no baked-in crops or split fence layers.
static var layout_data:Dictionary={}
const CROPS:=[preload("res://assets/farm/v003/grain-growth-01.png"),preload("res://assets/farm/v003/grain-growth-02.png"),preload("res://assets/farm/v003/grain-growth-03.png"),preload("res://assets/farm/v003/grain-growth-04.png")]
var model:GameState
var key:String
var progress_track:=StyleBoxFlat.new()
var progress_fill:=StyleBoxFlat.new()
var hud_bounds:=Rect2()
var hud_visible:=true
func _init(game:GameState,id:String)->void:model=game;key=id;name="TemporaryCropVisual";visibility_layer=2
func _ready()->void:
	progress_track.bg_color=PlayChrome.TRACK_COLOR
	progress_track.border_color=PlayChrome.TRACK_RIM
	progress_track.set_border_width_all(2)
	progress_track.set_corner_radius_all(14)
	progress_fill.bg_color=Color("367fc4")
	progress_fill.set_corner_radius_all(12)
	if layout_data.is_empty():layout_data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/farm/v003/manifest.json"))
	model.changed.connect(queue_redraw)

func _process(_delta:float)->void:
	# Redraw at viewport entry/exit even if the growth clock has not ticked.
	if not hud_bounds.has_area():return
	var bounds:=get_global_transform_with_canvas()*hud_bounds
	var onscreen:=bounds.intersects(get_viewport_rect().grow(4))
	if onscreen!=hud_visible:
		hud_visible=onscreen
		queue_redraw()
func _draw()->void:
	var found:=model.lookup_building(key)
	if found.is_empty():return
	var cycle:=FarmProduction.entry(model,key)
	var progress:=float(cycle.elapsed)/FarmProduction.GROWTH if cycle.phase=="grow" else (1.0 if cycle.phase in ["ready","harvest"] else 0.0)
	var level:=clampi(int(found.data.get("level",1)),1,4)
	var layout:Dictionary=layout_data.levels[level-1]
	var rect:=BuildingVisuals.display_rect("farm",level)
	hud_bounds=rect
	var anchors:Array=layout.crop_anchors.duplicate();anchors.sort_custom(func(a,b):return a[1]<b[1])
	var count:=anchors.size()
	if cycle.phase=="prepare":count=0
	elif cycle.phase=="harvest":count=ceili(count*(1.0-float(cycle.cuts)/FarmProduction.CUTS[int(cycle.cycle_level)-1]))
	var texture:Texture2D=CROPS[clampi(int(progress*4),0,3)]
	var dimensions:=Vector2.ONE*rect.size.x*float(layout.crop_canvas_width_fraction)
	for i in count:
		var at:=rect.position+Vector2(anchors[i][0],anchors[i][1])*rect.size
		draw_texture_rect(texture,Rect2(at-Vector2(.5,.915)*dimensions,dimensions),false)
	if not hud_visible:return
	# Keep the bar under the field and clear of both side work positions.
	var bar:=Rect2(-106,rect.end.y+9,212,30)
	var ratio:=progress
	var status:="성장"
	var duration:=FarmProduction.GROWTH
	match cycle.phase:
		"prepare":
			status="준비"
			duration=FarmProduction.PREPARATION
			ratio=float(cycle.elapsed)/duration
		"ready":
			status="수확 대기"
		"harvest":
			status="수확 중"
			ratio=1.0-float(cycle.cuts)/FarmProduction.CUTS[int(cycle.cycle_level)-1]
	ratio=clampf(ratio,0,1)
	draw_style_box(progress_track,bar)
	if ratio>0:
		var inner:=bar.grow(-2)
		inner.size.x*=ratio
		draw_style_box(progress_fill,inner)

	var font:=DemoArt.theme().default_font
	var baseline:=bar.get_center().y+(font.get_ascent(20)-font.get_descent(20))*.5
	var left:=Vector2(bar.position.x+12,baseline)
	var width:=bar.size.x-24
	if cycle.phase in ["prepare","grow"]:
		var remaining:=ceili(maxf(0,duration-float(cycle.elapsed)))
		draw_bar_text(font,left,"%s %d%%"%[status,roundi(ratio*100)],HORIZONTAL_ALIGNMENT_LEFT,width)
		draw_bar_text(font,left,"%02d:%02d"%[remaining/60,remaining%60],HORIZONTAL_ALIGNMENT_RIGHT,width)
	else:
		draw_bar_text(font,left,status,HORIZONTAL_ALIGNMENT_CENTER,width)
	if int(cycle.stock)>0:
		draw_string(font,Vector2(bar.position.x,bar.end.y+17),"보관 %d"%int(cycle.stock),HORIZONTAL_ALIGNMENT_CENTER,bar.size.x,15,Color("fff0d3"))

func draw_bar_text(font:Font,at:Vector2,label:String,alignment:HorizontalAlignment,width:float)->void:
	draw_string_outline(font,at,label,alignment,width,20,4,Color("30251b"))
	draw_string(font,at,label,alignment,width,20,Color("fffae0"))
