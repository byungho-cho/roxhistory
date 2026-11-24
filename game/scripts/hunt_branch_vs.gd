extends Control
## Runtime port of the approved make27.py timing/geometry. No fixed roster or video preset.
const ART:="res://assets/ui/hunt-readiness/vs/"
var paused:=false
var playing:=false
var clock:=0.0
var background:TextureRect
var sky_flow:ColorRect
var mist_flow:ColorRect
var letters:Array[TextureRect]=[]
var ember_layers:Array[Node2D]=[]
var flame_layer:Node2D
var glow:TextureRect
const V31_DIR:=ART+"v31/"
const V31_TIMELINE:="res://data/hunt-vs-v31-title-fx.json"
var title_sprite:TextureRect
var title_cut:=AtlasTexture.new()
var title_frames:Array=[]
var title_pages:Dictionary={}
var title_requests:Dictionary={}
var title_pivot:=Vector2.ZERO
var title_fps:=30.
var title_last_frame:=-1
var bounds:=Rect2(0,0,960,540)
const EMBERS:=[Vector2(41,46),Vector2(58,72),Vector2(72,85),Vector2(87,47),Vector2(125,40),Vector2(154,49),Vector2(143,70),Vector2(158,87),Vector2(123,92)]
const BURN_SHADER:="""
shader_type canvas_item;
uniform float burn;
uniform float warmth;
varying vec4 tint;
void vertex(){tint=COLOR;}
void fragment(){
 vec4 wood=texture(TEXTURE,UV);
 vec2 p=vec2(13.,18.)+UV*vec2(184.,92.);
 float front=clamp((p.y-(118.-108.*burn)+5.*sin(p.x*.076)+3.*sin(p.x*.185))/9.,0.,1.);
 float gray=dot(wood.rgb,vec3(.299,.587,.114))*.58;
 vec3 charred=vec3(gray+9./255.,gray+3./255.,gray);
 float bounce=warmth*exp(-pow((p.y-86.)/30.,2.))*(.72+.28*sin(p.x*.13+TIME*11.));
  vec3 lit=mix(wood.rgb,charred,front)+vec3(.31,.13,.034)*bounce;
  COLOR=vec4(lit,wood.a)*tint;
}
"""
func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	size=Vector2(960,540)
	background=TextureRect.new()
	background.texture=load(ART+"VS-Valley-Plate.png")
	background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter=Control.MOUSE_FILTER_STOP
	add_child(background)
	var shader:=Shader.new()
	shader.code="""
shader_type canvas_item;
uniform sampler2D amber : source_color,filter_linear;
varying vec4 tint;
void vertex(){tint=COLOR;}
void fragment(){
 vec3 a=texture(TEXTURE,UV).rgb;
 vec3 b=texture(amber,UV).rgb;
 b=mix(vec3(dot(b,vec3(.299,.587,.114))),b,.60);
 COLOR=vec4(mix(a,b,.22)*.85,1.)*tint;
}
"""
	var material:=ShaderMaterial.new();material.shader=shader
	material.set_shader_parameter("amber",load(ART+"VS-Teal-Amber-Plate.png"));background.material=material
	sky_flow=_flow(false);mist_flow=_flow(true)
	var gradient:=Gradient.new()
	gradient.colors=PackedColorArray([Color(1,1,1,.8),Color(1,1,1,.3),Color(1,1,1,0)])
	gradient.offsets=PackedFloat32Array([0.,.45,1.])
	var halo:=GradientTexture2D.new();halo.gradient=gradient
	halo.fill=GradientTexture2D.FILL_RADIAL;halo.fill_from=Vector2(.5,.5);halo.fill_to=Vector2(1.,.5)
	glow=TextureRect.new();glow.texture=halo;glow.mouse_filter=Control.MOUSE_FILTER_IGNORE
	glow.position=Vector2(344,232);glow.size=Vector2(272,203);add_child(glow)
	var burn_shader:=Shader.new();burn_shader.code=BURN_SHADER
	for letter in ["V","S"]:
		var item:=TextureRect.new()
		item.texture=load(ART+"VS-Branch-"+letter+".png")
		item.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		item.position=Vector2(392,222);item.size=Vector2(184,92)
		item.mouse_filter=Control.MOUSE_FILTER_IGNORE
		item.clip_children=CanvasItem.CLIP_CHILDREN_AND_DRAW
		var burn_material:=ShaderMaterial.new();burn_material.shader=burn_shader
		item.material=burn_material;add_child(item);letters.append(item)
		var ember:=Node2D.new();item.add_child(ember)
		ember.position=Vector2(-13,-18)
		ember.draw.connect(_draw_embers.bind(ember));ember_layers.append(ember)
	flame_layer=Node2D.new();add_child(flame_layer);flame_layer.draw.connect(_draw_flames)
	var meta:Variant=JSON.parse_string(FileAccess.get_file_as_string(V31_TIMELINE))
	if meta is Dictionary and meta.get("frames",[]) is Array and not meta.frames.is_empty():
		title_frames=meta.frames
		title_pivot=Vector2(meta.pivot_source_px[0],meta.pivot_source_px[1])
		title_fps=float(meta.fps)
		title_sprite=TextureRect.new()
		title_sprite.name="ApprovedV31TitleAndFlame"
		title_sprite.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		title_sprite.mouse_filter=Control.MOUSE_FILTER_IGNORE
		title_cut.filter_clip=true
		title_sprite.texture=title_cut
		title_sprite.hide()
		add_child(title_sprite)
		_request_title_page(0)
	fit_background(bounds)
	present(0.)
func _flow(bottom:bool)->ColorRect:
	var layer:=ColorRect.new();layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	var shader:=Shader.new()
	shader.code="""
shader_type canvas_item;
uniform float clock;
uniform bool bottom;
varying vec4 tint;
void vertex(){tint=COLOR;}
void fragment(){
 float x=UV.x;float y=UV.y;
 if(bottom){
  float l=exp(-pow((x-.025)/.20,2.));float r=exp(-pow((x-.975)/.20,2.));
  float detail=.73+.18*sin(x*34.+1.45*y+clock*.47)+.09*sin(x*76.-2.*y-clock*.61);
  float alpha=min(242.,271.*pow(y,1.17)*(.81+.16*detail+.11*(l+r)))/255.;
  COLOR=vec4(vec3(181.,170.,151.)/255.,alpha)*tint;
 }else{
  vec2 p=UV*vec2(160.,28.);
  float alpha=37.*exp(-pow((p.y-9.-2.3*sin(p.x*.044+clock*.43))/5.,2.))*(.40+.38*pow(sin(p.x*.025+clock*.35),2.)+.21*pow(sin(p.x*.127-clock*.51),2.))/255.;
  COLOR=vec4(vec3(184.,195.,202.)/255.,alpha)*tint;
 }
}
"""
	var material:=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("bottom",bottom)
	layer.material=material;return layer
func fit_background(rect:Rect2)->void:
	bounds=rect
	if not is_instance_valid(background):return
	background.position=rect.position;background.size=rect.size
	sky_flow.position=rect.position;sky_flow.size=Vector2(rect.size.x,153)
	mist_flow.position=Vector2(rect.position.x,rect.end.y-208);mist_flow.size=Vector2(rect.size.x,208)
func play()->void:
	playing=true;clock=0.;present(0.)
func stop()->void:
	playing=false
	_release_title_pages()
func is_playing()->bool:return playing and clock<6.9
static func authored_ease(value:float)->float:return 1.-pow(1.-clampf(value,0.,1.),3.)
static func exit_amount(time:float)->float:
	var scene_time:=time if time<.61 else maxf(.61,time-1.5)
	return 1.-authored_ease((scene_time-4.58)/.52)
func present(time:float)->void:
	if paused or not is_instance_valid(background):return
	clock=time
	var scene_time:=time if time<.61 else maxf(.61,time-1.5)
	var phase:=authored_ease((time-.12)/.42)*(1.-authored_ease((scene_time-4.68)/.53))
	for layer in [background,sky_flow,mist_flow]:layer.modulate.a=phase
	for layer in [sky_flow,mist_flow]:layer.material.set_shader_parameter("clock",time)
	var title:=authored_ease((time-.47)/.31)*exit_amount(time)
	for letter in letters:
		letter.modulate.a=title
		letter.material.set_shader_parameter("burn",clampf((time-1.14)/.89,0.,1.))
	var ft:=clampf((time-1.10)/1.18,0.,1.)
	var strength:=minf(1.,ft*7.)*minf(1.,(1.-ft)*4.)
	glow.modulate=Color(1.,124./255.,34./255.,163./255.*strength*.70)
	var v31_ready:=_present_v31(time)
	for letter in letters:
		letter.visible=not v31_ready
		letter.material.set_shader_parameter("warmth",strength)
	glow.visible=not v31_ready
	flame_layer.visible=not v31_ready
	for ember in ember_layers:ember.queue_redraw()
	flame_layer.queue_redraw()
func _request_title_page(index:int)->void:
	if index<0 or title_pages.has(index) or title_requests.has(index):return
	var path:=V31_DIR+"title-fx-%d.png"%index
	if ResourceLoader.exists(path,"Texture2D") and ResourceLoader.load_threaded_request(path,"Texture2D")==OK:
		title_requests[index]=path

func _title_page(index:int)->Texture2D:
	if title_pages.has(index):return title_pages[index]
	_request_title_page(index)
	if not title_requests.has(index):return null
	var path:String=title_requests[index]
	var status:=ResourceLoader.load_threaded_get_status(path)
	if status==ResourceLoader.THREAD_LOAD_IN_PROGRESS:return null
	title_requests.erase(index)
	if status!=ResourceLoader.THREAD_LOAD_LOADED:return null
	var art:=ResourceLoader.load_threaded_get(path) as Texture2D
	if is_instance_valid(art):title_pages[index]=art
	return art

func _release_title_pages()->void:
	if not is_instance_valid(title_sprite):return
	title_sprite.hide()
	title_cut.atlas=null
	title_last_frame=-1
	title_pages.clear()
	for index in title_requests.keys():
		var path:String=title_requests[index]
		if ResourceLoader.load_threaded_get_status(path)==ResourceLoader.THREAD_LOAD_LOADED:
			ResourceLoader.load_threaded_get(path)
			title_requests.erase(index)

func _present_v31(time:float)->bool:
	if not is_instance_valid(title_sprite):return false
	var frame:=floori(time*title_fps+.00001)
	if frame>=title_frames.size():
		_release_title_pages()
		return true
	var data:Variant=title_frames[frame]
	if data==null:
		title_sprite.hide()
		title_last_frame=-1
		return true
	var index:=int(data.atlas)
	var tex:=_title_page(index)
	if not is_instance_valid(tex):return title_sprite.visible
	for key in title_pages.keys():
		if key!=index and key!=index+1:title_pages.erase(key)
	for n in range(frame+1,mini(frame+13,title_frames.size())):
		var next:Variant=title_frames[n]
		if next!=null and int(next.atlas)!=index:
			_title_page(int(next.atlas))
			break
	if title_last_frame!=frame:
		var r:Array=data.rect
		var at:Array=data.offset
		title_cut.atlas=tex
		title_cut.region=Rect2(r[0],r[1],r[2],r[3])
		title_sprite.position=title_pivot+Vector2(at[0],at[1])
		title_sprite.size=title_cut.region.size
		title_last_frame=frame
	title_sprite.show()
	return true

func _draw_embers(layer:Node2D)->void:
	if clock<=1.45:return
	for j in EMBERS.size():
		var p:Vector2=EMBERS[j]
		var v:=minf(1.,(clock-1.45)*2.)*(.60+.40*pow(sin(clock*3.1+j),2.))*clampf((2.28-clock)/.24,0.,1.)
		var line:=PackedVector2Array([p+Vector2(-5,1),p+Vector2(-1,-1),p+Vector2(1,1),p+Vector2(5,-1)])
		layer.draw_polyline(line,Color(1.,138./255.,52./255.,minf(1.,v*1.25)),3.,true)
	if clock<=2.04:return
	var q:=clampf((clock-2.04)/.20,0.,1.)*clampf(1.-(clock-2.36)/3.76,0.,1.)
	var pieces:Array=[PackedVector2Array([Vector2(20,24),Vector2(21,21),Vector2(27,19),Vector2(34,20),Vector2(40,19),Vector2(44,22),Vector2(42,25)]),PackedVector2Array([Vector2(187,28),Vector2(190,29),Vector2(191,33),Vector2(190,36),Vector2(189,41),Vector2(187,45),Vector2(183,45)])]
	for j in pieces.size():
		var line:PackedVector2Array=pieces[j]
		var v:=q*(.86+.14*pow(sin(clock*4.+j),2.))
		layer.draw_polyline(line,Color(204./255.,46./255.,13./255.,.25*v),6.,true)
		layer.draw_polyline(line,Color(204./255.,46./255.,13./255.,.88*v),3.,true)
		layer.draw_polyline(line.slice(1,6),Color(1.,120./255.,39./255.,v),2.,true)
		layer.draw_polyline(line.slice(2,5),Color(1.,184./255.,78./255.,.93*v),1.,true)
		layer.draw_circle(line[0],1.4,Color(1.,120./255.,39./255.,v))
		layer.draw_circle(line[6],1.4,Color(1.,120./255.,39./255.,v))
func _draw_flames()->void:
	var ft:=clampf((clock-1.10)/1.18,0.,1.)
	var drift:=maxf(0.,clock-1.73)
	if drift>0. and drift<4.4:
		for j in 10:
			var seed:=float(j)
			var life:=clampf((drift-seed*.046)/.35,0.,1.)*(1.-smoothstep(2.2,4.4,drift))
			var point:=Vector2(480.+(seed-4.5)*(12.+drift*4.)+8.*sin(seed*2.7+drift*3.),300.-(12.+fposmod(seed*5.3,17.))*drift)
			flame_layer.draw_circle(point,3.2,Color(1.,.28,.05,.16*life))
			flame_layer.draw_circle(point,1.35+fposmod(seed,3.)*.24,Color(1.,.66,.25,.92*life))
	if ft<=0. or ft>=1.:return
	var strength:=minf(1.,ft*7.)*minf(1.,(1.-ft)*4.)
	var th:=160.*authored_ease(ft/.53)
	for k in 7:
		var offset:=float(k-3)*22.;var phase:=float(k)*1.99
		var x:=480.+offset
		var y:=355.-pow(ft,1.05)*(170.+23.*sin(phase))
		var length:float=(29.+th*.45)*(1.-.55*ft)*(.74+.26*cos(phase))
		var width:float=(19.+9.*pow(sin(phase),2.))*(.52+.48*strength)
		var centers:Array[Vector2]=[];var widths:Array[float]=[]
		for j in 16:
			var u:=float(j)/15.
			centers.append(Vector2(x+u*((14.+54.*u*u)*sin(phase+ft*4.+u*3.75)+offset*.36),y-u*length))
			widths.append(width*pow(sin(PI*(.08+.92*u)),.82))
		_polygon(centers,widths,16,1.,Color(1.,float(73+k%3*21)/255.,18./255.,float(238-k%3*18)/255.*strength))
		_polygon(centers,widths,13,.44,Color(1.,float(197+k%3*16)/255.,float(71+k%3*24)/255.,238./255.*strength))
		if k in [1,3,5]:_polygon(centers.slice(2,10),widths.slice(2,10),8,.19,Color(1.,247./255.,196./255.,252./255.*strength))
	# Only the short-lived orange fire sparks present in the approved recipe; no ash or lightning.
	for j in 28:
		var h:=fposmod(float(j)*.307+ft*1.7,1.)
		var point:=Vector2(480.+sin(float(j)*11.71+ft)*97.*(.7+h*.45),351.-h*(126.+ft*93.))
		flame_layer.draw_circle(point,1.25,Color(1.,200./255.,104./255.,177./255.*strength*(1.-h)))
func _polygon(centers:Array[Vector2],widths:Array[float],count:int,factor:float,color:Color)->void:
	var points:=PackedVector2Array()
	for j in count:points.append(centers[j]-Vector2(widths[j]*factor,0))
	for j in range(count-1,-1,-1):points.append(centers[j]+Vector2(widths[j]*factor,0))
	flame_layer.draw_colored_polygon(points,color)
	points.append(points[0]);flame_layer.draw_polyline(points,Color(color,color.a*.35),1.3,true)
