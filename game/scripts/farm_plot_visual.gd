class_name FarmPlotVisual
extends Node2D
## Completed farm art contains crops. Separate growth overlays await clean base assets.
var model:GameState
var key:String
func _init(game:GameState,id:String)->void:model=game;key=id;name="TemporaryCropVisual";visibility_layer=2;z_index=4
func _process(_delta:float)->void:queue_redraw()
func _draw()->void:
	var found:=model.lookup_building(key)
	if found.is_empty():return
	var cycle:=FarmProduction.entry(model,key)
	var progress:=float(cycle.elapsed)/FarmProduction.GROWTH if cycle.phase=="grow" else (1.0 if cycle.phase in ["ready","harvest"] else 0.0)
	# Growth artwork is intentionally not layered over baked-in crops.
	var brush:=BuildingMenu.art("brush-black-v003.png")
	draw_texture_rect(brush,Rect2(-100,12,200,40),false,Color(1,1,1,.78))
	var fill:=float(cycle.elapsed)/FarmProduction.PREPARATION if cycle.phase=="prepare" else progress
	if cycle.phase=="harvest":fill=1.0-float(cycle.cuts)/FarmProduction.CUTS[int(cycle.cycle_level)-1]
	draw_rect(Rect2(-84,18,168,5),Color(0,0,0,.55));draw_rect(Rect2(-84,18,168*fill,5),Color("b3bd4e"))
	var remaining:=maxf(0.0,(FarmProduction.PREPARATION if cycle.phase=="prepare" else FarmProduction.GROWTH)-float(cycle.elapsed))
	var caption:="준비 %02d:%02d"%[int(remaining)/60,int(remaining)%60] if cycle.phase=="prepare" else "성장 %d%% · %02d:%02d"%[roundi(progress*100),int(remaining)/60,int(remaining)%60]
	if cycle.phase in ["ready","harvest"]:caption="수확 대기" if cycle.phase=="ready" else "수확 중"
	draw_string(DemoArt.theme().default_font,Vector2(-94,40),caption,HORIZONTAL_ALIGNMENT_CENTER,188,18,Color("fff0d3"))
	if int(cycle.stock)>0:draw_string(DemoArt.theme().default_font,Vector2(-110,62),"보관 %d"%int(cycle.stock),HORIZONTAL_ALIGNMENT_CENTER,220,15,Color("fff0d3"))
