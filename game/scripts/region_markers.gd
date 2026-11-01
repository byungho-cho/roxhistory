class_name RegionMarkers
extends Control

var owner_map:Control
var images:={}
var labels:={}
var shades:={}
var bases:={}

func _init(map:Control) -> void:owner_map=map;mouse_filter=Control.MOUSE_FILTER_IGNORE
func _ready() -> void:
	for key in RegionCatalog.REGIONS:
		var data:Dictionary=RegionCatalog.REGIONS[key]
		bases[key]=FigmaArt.picture(self,"b91e1.svg",Rect2())
		images[key]=FigmaArt.picture(self,data.symbol,Rect2())
		var cast:=ArtShadow.new(images[key],Vector2(.9,3)*owner_map.ui_factor,3*owner_map.ui_factor);add_child(cast);move_child(cast,images[key].get_index())
		shades[key]=FigmaArt.picture(self,"0e025.svg" if key=="jeongok" else "c110f.svg",Rect2())
		labels[key]=FigmaArt.text(self,data.name,Rect2(),22,FigmaArt.BODY,Color.WHITE)
		labels[key].add_theme_color_override("font_shadow_color",Color(0,0,0,.85))
		labels[key].add_theme_constant_override("shadow_offset_y",1)
	refresh()

func blend() -> float:return clampf((owner_map.zoom-1)/.4,0,1)
func bottom(key:String) -> Vector2:
	var data:Dictionary=RegionCatalog.REGIONS[key]
	var offset:Vector2=(data.overview-data.point).lerp(Vector2(0,-25),blend())
	return owner_map.map_point(key)+offset*owner_map.ui_factor
func artifact_rect(key:String) -> Rect2:
	var data:Dictionary=RegionCatalog.REGIONS[key];var chosen:bool=owner_map.selected==key
	var base:Vector2=data.base_size
	if key=="amsa" and chosen:base*=lerpf(1,100.0/85.0,blend())
	var extent:Vector2=base*(1.1 if chosen else .9)*owner_map.ui_factor
	return Rect2(bottom(key)-Vector2(extent.x*.5,extent.y),extent)
func name_rect(key:String) -> Rect2:
	var width:float=RegionCatalog.REGIONS[key].label_width
	return Rect2(bottom(key)+Vector2(-width*.5,-2 if key=="dongsam" else -17)*owner_map.ui_factor,Vector2(width,30)*owner_map.ui_factor)
func hit_rect(key:String) -> Rect2:return artifact_rect(key).merge(name_rect(key))
func refresh() -> void:
	var k:float=owner_map.ui_factor
	for key in images:
		var rect:=artifact_rect(key);images[key].position=rect.position;images[key].size=rect.size
		var nr:=name_rect(key);labels[key].position=nr.position;labels[key].size=nr.size/k;labels[key].scale=Vector2.ONE*k
		shades[key].position=nr.position-Vector2(14,7)*k;shades[key].size=nr.size+Vector2(28,14)*k
		bases[key].size=Vector2(rect.size.x*1.12,maxf(14*k,rect.size.y*.18))
		bases[key].position=bottom(key)-bases[key].size*.5
	queue_redraw()
func _draw() -> void:
	var k:float=owner_map.ui_factor
	for key in RegionCatalog.REGIONS:
		var point:Vector2=owner_map.map_point(key)
		if key!="dongsam" and blend()<1:
			var end:=artifact_rect(key).get_center()
			var delta:=end-point
			draw_set_transform(point,delta.angle(),Vector2.ONE*k)
			draw_texture_rect(FigmaArt.texture("a82bb.svg" if key=="jeongok" else "6661f.svg"),Rect2(0,-.5,delta.length()/k,1),false,Color(1,1,1,1-blend()))
			draw_set_transform(Vector2.ZERO)
		var extent:float=(44 if key==owner_map.selected else 12)*k
		draw_texture_rect(FigmaArt.texture("246e1.svg" if key==owner_map.selected else "96c7f.svg"),Rect2(point-Vector2.ONE*extent*.5,Vector2.ONE*extent),false)
