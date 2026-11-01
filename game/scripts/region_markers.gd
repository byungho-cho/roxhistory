class_name RegionMarkers
extends Control

# Equal longest edge; original artifact aspect ratios remain intact.
const BASE_EXTENT:=86.0
const SELECTED_SCALE:=1.2
const ENTER_SECONDS:=.28
const RIPPLE_SECONDS:=.55
var owner_map:Control
var images:={}
var labels:={}
var shades:={}
var selection_age:=1.0
var observed_selection:=""

func _init(map:Control) -> void:owner_map=map;mouse_filter=Control.MOUSE_FILTER_IGNORE
func _ready() -> void:
	observed_selection=owner_map.selected
	for key in RegionCatalog.REGIONS:
		var data:Dictionary=RegionCatalog.REGIONS[key]
		images[key]=FigmaArt.picture(self,data.symbol,Rect2())
		var cast:=ArtShadow.new(images[key],Vector2(.9,3)*owner_map.ui_factor,3*owner_map.ui_factor);add_child(cast);move_child(cast,images[key].get_index())
		shades[key]=FigmaArt.picture(self,"0e025.svg" if key=="jeongok" else "c110f.svg",Rect2())
		labels[key]=FigmaArt.text(self,data.name,Rect2(),22,FigmaArt.BODY,Color.WHITE)
		labels[key].add_theme_color_override("font_shadow_color",Color(0,0,0,.85))
		labels[key].add_theme_constant_override("shadow_offset_y",1)
	refresh()

func trigger_selection() -> void:
	observed_selection=owner_map.selected;selection_age=0
func _process(delta:float) -> void:
	selection_age+=delta;refresh()
func bottom(key:String) -> Vector2:return owner_map.map_point(key)
func base_size(key:String) -> Vector2:
	var original:Vector2=RegionCatalog.REGIONS[key].base_size
	return original*(BASE_EXTENT/maxf(original.x,original.y))
func artifact_rect(key:String) -> Rect2:
	var amount:=1.0
	if owner_map.selected==key:
		amount=lerpf(1,SELECTED_SCALE,1-pow(1-clampf(selection_age/ENTER_SECONDS,0,1),3))
	var extent:Vector2=base_size(key)*amount*owner_map.ui_factor
	return Rect2(bottom(key)-Vector2(extent.x*.5,extent.y),extent)
func name_rect(key:String) -> Rect2:
	var width:float=RegionCatalog.REGIONS[key].label_width
	# Separate the two northern labels without moving geographic anchors.
	var offset:=Vector2(-width-38,-22) if key=="jeongok" else Vector2(-width*.5,9)
	return Rect2(bottom(key)+offset*owner_map.ui_factor,Vector2(width,30)*owner_map.ui_factor)
func hit_rect(key:String) -> Rect2:return artifact_rect(key).merge(name_rect(key))
func contains(key:String,at:Vector2) -> bool:
	return artifact_rect(key).grow(3*owner_map.ui_factor).has_point(at) or name_rect(key).has_point(at)
func refresh() -> void:
	if observed_selection!=owner_map.selected:
		observed_selection=owner_map.selected;selection_age=1
	var k:float=owner_map.ui_factor
	for key in images:
		var rect:=artifact_rect(key);images[key].position=rect.position;images[key].size=rect.size
		var nr:=name_rect(key);labels[key].position=nr.position;labels[key].size=nr.size/k;labels[key].scale=Vector2.ONE*k
		shades[key].position=nr.position-Vector2(14,7)*k;shades[key].size=nr.size+Vector2(28,14)*k
	queue_redraw()

func ellipse(center:Vector2,radius:Vector2,color:Color,width:float=0) -> void:
	var points:=PackedVector2Array()
	for i in 65:
		var angle:=TAU*i/64.0;points.append(center+Vector2(cos(angle),sin(angle))*radius)
	if width>0:draw_polyline(points,color,width,true)
	else:draw_colored_polygon(points,color)
func _draw() -> void:
	var k:float=owner_map.ui_factor
	for key in RegionCatalog.REGIONS:
		var contact:=bottom(key)
		if key!=owner_map.selected:
			ellipse(contact+Vector2(0,2)*k,Vector2(base_size(key).x*.31,4)*k,Color(0,0,0,.18))
			continue
		var radius:=Vector2(54,13)*k
		var breath:=.5+.5*sin(selection_age*TAU/2.8)
		# Pedestal stays behind the icon; its rear rim is naturally occluded.
		ellipse(contact+Vector2(0,8)*k,radius*Vector2(1.08,1.1),Color(0,0,0,.25))
		for i in range(4,0,-1):
			ellipse(contact,radius+Vector2(i*2,i*.8)*k,Color(1,.65,.12,(.025+.014*breath)),3*k)
		ellipse(contact+Vector2(0,5)*k,radius,Color("70401d"))
		ellipse(contact+Vector2(0,3)*k,radius,Color("b77727"))
		ellipse(contact,radius,Color("bd8839"))
		ellipse(contact,radius,Color(1,.78,.28,.86+.1*breath),2.5*k)
		ellipse(contact-Vector2(0,1)*k,radius*Vector2(.89,.70),Color("e2b85b"),1*k)
		ellipse(contact,Vector2(25,4)*k,Color(0,0,0,.2))
		if selection_age<RIPPLE_SECONDS:
			var progress:=selection_age/RIPPLE_SECONDS
			ellipse(contact,radius*(1+progress*.55),Color(1,.79,.3,.48*(1-progress)),1.7*k)
		var spark:=contact+Vector2(43,-16)*k
		draw_circle(spark,(1.2+.5*breath)*k,Color(1,.88,.5,.4+.25*breath),true,-1,true)
