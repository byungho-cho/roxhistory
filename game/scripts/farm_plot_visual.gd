class_name FarmPlotVisual
extends Node2D
## PR 68 review assets: fixed root anchors, no baked-in crops or split fence layers.
static var layout_data:Dictionary={}
const CROPS:=[preload("res://assets/farm/v003/grain-growth-01.png"),preload("res://assets/farm/v003/grain-growth-02.png"),preload("res://assets/farm/v003/grain-growth-03.png"),preload("res://assets/farm/v003/grain-growth-04.png")]
var model:GameState
var key:String
func _init(game:GameState,id:String)->void:model=game;key=id;name="TemporaryCropVisual";visibility_layer=2
func _ready()->void:
	if layout_data.is_empty():layout_data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/farm/v003/manifest.json"))
	model.changed.connect(queue_redraw)
func _draw()->void:
	var found:=model.lookup_building(key)
	if found.is_empty():return
	var cycle:=FarmProduction.entry(model,key)
	var progress:=float(cycle.elapsed)/FarmProduction.GROWTH if cycle.phase=="grow" else (1.0 if cycle.phase in ["ready","harvest"] else 0.0)
	var level:=clampi(int(found.data.get("level",1)),1,4)
	var layout:Dictionary=layout_data.levels[level-1]
	var rect:=BuildingVisuals.display_rect("farm",level)
	var anchors:Array=layout.crop_anchors.duplicate();anchors.sort_custom(func(a,b):return a[1]<b[1])
	var count:=anchors.size()
	if cycle.phase=="prepare":count=0
	elif cycle.phase=="harvest":count=ceili(count*(1.0-float(cycle.cuts)/FarmProduction.CUTS[int(cycle.cycle_level)-1]))
	var texture:Texture2D=CROPS[clampi(int(progress*4),0,3)]
	var dimensions:=Vector2.ONE*rect.size.x*float(layout.crop_canvas_width_fraction)
	for i in count:
		var at:=rect.position+Vector2(anchors[i][0],anchors[i][1])*rect.size
		draw_texture_rect(texture,Rect2(at-Vector2(.5,.915)*dimensions,dimensions),false)
	# Draw below the field and keep both side work positions clear.
	draw_set_transform(Vector2(0,rect.end.y-2))
	var brush:=BuildingMenu.art("brush-black-v003.png")
	draw_texture_rect(brush,Rect2(-110,10,220,48),false,Color(1,1,1,.78))
	var fill:=float(cycle.elapsed)/FarmProduction.PREPARATION if cycle.phase=="prepare" else progress
	if cycle.phase=="harvest":fill=1.0-float(cycle.cuts)/FarmProduction.CUTS[int(cycle.cycle_level)-1]
	draw_rect(Rect2(-92,17,184,6),Color(0,0,0,.55));draw_rect(Rect2(-92,17,184*fill,6),Color("b3bd4e"))
	var remaining:=maxf(0.0,(FarmProduction.PREPARATION if cycle.phase=="prepare" else FarmProduction.GROWTH)-float(cycle.elapsed))
	var caption:="준비 %02d:%02d"%[int(remaining)/60,int(remaining)%60] if cycle.phase=="prepare" else "성장 %d%% · %02d:%02d"%[roundi(progress*100),int(remaining)/60,int(remaining)%60]
	if cycle.phase in ["ready","harvest"]:caption="수확 대기" if cycle.phase=="ready" else "수확 중"
	draw_string(DemoArt.theme().default_font,Vector2(-104,44),caption,HORIZONTAL_ALIGNMENT_CENTER,208,20,Color("fff0d3"))
	if int(cycle.stock)>0:draw_string(DemoArt.theme().default_font,Vector2(-110,62),"보관 %d"%int(cycle.stock),HORIZONTAL_ALIGNMENT_CENTER,220,15,Color("fff0d3"))
