class_name CharacterGuide
extends Control
## U10400: reusable dynamic text, independent artwork and modal input ownership.
var app:Node
var heading:String
var message:String
var layout:Control
var panel_group:Control
var character:TextureRect
var age:=0.0
var pages:Array[Dictionary]=[]
var completions:Array[Callable]=[]
var presses:Dictionary={}
var scroll_pointer:=-2
var initial_scroll:=0
var text_scroll:ScrollContainer
var text_column:VBoxContainer
var text_labels:Array[Label]=[]
var text_fonts:Array[FontVariation]=[]
const DESIGN_SIZE:=Vector2(1200,675)
const PANEL_RECT:=Rect2(149,415,949,212)
const CHARACTER_RECT:=Rect2(-67,202,468,425)
const TEXT_X:=355.0
const TEXT_WIDTH:=670.0
const TEXT_MAX_HEIGHT:=152.0
func _init(owner_app:Node,title:String,body:String)->void:
	app=owner_app;heading=title;message=body
func picture(parent:Node,texture:Texture2D,rect:Rect2)->TextureRect:
	var image:=TextureRect.new();image.texture=texture;image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.position=rect.position;image.size=rect.size;image.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(image);return image
func _ready()->void:
	name="CharacterGuide";set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_STOP
	layout=Control.new();layout.name="GuideLayout";layout.size=DESIGN_SIZE;layout.clip_contents=true;layout.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(layout)
	panel_group=Control.new();panel_group.name="PanelGroup";panel_group.size=DESIGN_SIZE;panel_group.mouse_filter=Control.MOUSE_FILTER_IGNORE;layout.add_child(panel_group)
	var source:Texture2D=preload("res://assets/ui/v0159/guide-panel.png")
	var crop:=AtlasTexture.new();crop.atlas=source;crop.region=Rect2(0,source.get_height()*.1918/1.3699,source.get_width(),source.get_height()/1.3699);crop.filter_clip=true
	# Soft shadow follows the same panel silhouette; cream texture is never redrawn.
	for i in [3,2,1]:
		var shadow:=picture(panel_group,crop,Rect2(149-i,422-i,949+i*2,212+i*2));shadow.self_modulate=Color(.078,.059,.035,.09)
	var panel:=picture(panel_group,crop,PANEL_RECT);panel.name="CreamPanel";panel.self_modulate.a=.8
	var nameplate:=Panel.new()
	nameplate.position=Vector2(267,423);nameplate.size=Vector2(137,42)
	nameplate.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var wood:=StyleBoxFlat.new()
	wood.bg_color=Color("65452b");wood.border_color=Color("be985c")
	wood.set_border_width_all(2);wood.set_corner_radius_all(5)
	nameplate.add_theme_stylebox_override("panel",wood)
	panel_group.add_child(nameplate)
	var speaker:Label=app.label(nameplate,"길잡이",20,Color("fff0c9"))
	speaker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	speaker.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	speaker.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	var advance_hint:=picture(panel_group,preload("res://assets/ui/construction-side-v006/chevron.svg"),Rect2(1030,579,20,34))
	advance_hint.name="GuideAdvanceHint"
	advance_hint.pivot_offset=advance_hint.size*.5
	advance_hint.rotation=-PI*.5
	text_scroll=ScrollContainer.new();text_scroll.name="GuideText";text_scroll.position=Vector2(TEXT_X,475);text_scroll.size=Vector2(TEXT_WIDTH,TEXT_MAX_HEIGHT);text_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;panel_group.add_child(text_scroll)
	text_column=VBoxContainer.new();text_column.name="MessageContent";text_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;text_column.add_theme_constant_override("separation",14);text_scroll.add_child(text_column)
	for item in [[heading,30],[message,23]]:
		var text:=Label.new();text.theme=DemoArt.theme();text.text=item[0];
		var font:=FontVariation.new();font.base_font=FigmaArt.NOTO;font.variation_opentype={TextServerManager.get_primary_interface().name_to_tag("wght"):700.0 if item[1]==30 else 400.0};text.add_theme_font_override("font",font);text.add_theme_font_size_override("font_size",item[1]);text.add_theme_color_override("font_color",Color("1f1c17"));text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;text.add_theme_constant_override("line_spacing",0);text_column.add_child(text);text_labels.append(text);text_fonts.append(font)
	character=picture(layout,preload("res://assets/ui/v0159/guide-character.png"),CHARACTER_RECT);character.name="GuideCharacter";character.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;character.clip_contents=true;character.pivot_offset=Vector2(234,425)
	panel_group.modulate.a=0;character.modulate.a=0
	update_layout()
func update_layout()->void:
	# Width-fit the design's transparent frame instead of inset fitting the whole
	# 675px preview: its visible character starts at 202px, so wider phones can use
	# the empty upper part without shrinking the messenger away from the left edge.
	var factor:=minf(app.w/DESIGN_SIZE.x,(app.h-app.safe.y)/(DESIGN_SIZE.y-CHARACTER_RECT.position.y))
	var bottom_inset:=maxf(0.0,app.safe.y-(DESIGN_SIZE.y-PANEL_RECT.end.y)*factor)
	layout.scale=Vector2.ONE*factor
	layout.position=Vector2((app.w-DESIGN_SIZE.x*factor)*.5,app.h-DESIGN_SIZE.y*factor-bottom_inset)
	# Short copy is vertically centered like the reference; long/localized copy
	# gets the full inner height and scrolls. Portrait text has a readable minimum.
	for i in text_labels.size():
		var font_size:=maxi(30 if i==0 else 23,ceili((18.0 if i==0 else 14.0)/factor))
		if text_labels[i].get_theme_font_size("font_size")!=font_size:text_labels[i].add_theme_font_size_override("font_size",font_size)
		# Figma line boxes are36/28px (1.2em). Godot Noto's44/34px
		# metrics otherwise push the body down despite an identical font size.
		var trim:=maxi(0,roundi(FigmaArt.NOTO.get_height(font_size))-roundi(font_size*1.2))
		var top:=-int(trim/2);var bottom:=-trim-top
		if text_fonts[i].spacing_top!=top:text_fonts[i].spacing_top=top
		if text_fonts[i].spacing_bottom!=bottom:text_fonts[i].spacing_bottom=bottom
	var height:=minf(TEXT_MAX_HEIGHT,maxf(1,text_column.get_combined_minimum_size().y))
	var optical_shift:=minf(7,(TEXT_MAX_HEIGHT-height)*.5)
	text_scroll.size=Vector2(TEXT_WIDTH,height)
	text_scroll.position=Vector2(TEXT_X,PANEL_RECT.position.y+(PANEL_RECT.size.y-height)*.5-optical_shift)
func enqueue(title:String,body:String,after:Callable)->void:
	pages.append({"title":title,"body":body})
	if after.is_valid():completions.append(after)

func remaining_pages()->Array[Dictionary]:
	var remaining:Array[Dictionary]=[{"title":heading,"body":message}]
	remaining.append_array(pages)
	return remaining

func advance()->void:
	presses.clear()
	scroll_pointer=-2
	if not pages.is_empty():
		var next:Dictionary=pages.pop_front()
		heading=next.title
		message=next.body
		text_labels[0].text=heading
		text_labels[1].text=message
		text_scroll.scroll_vertical=0
		return
	var actions:=completions.duplicate()
	app.close_modal()
	for action in actions:
		if action.is_valid():action.call()

func handle_pointer(event:InputEvent)->bool:
	var pointer:=-2
	var down:=false
	var cancelled:=false
	if event is InputEventScreenTouch:
		pointer=event.index
		down=event.pressed
		cancelled=event.canceled
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		pointer=-1
		down=event.pressed
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		pointer=event.index if event is InputEventScreenDrag else -1
		if presses.has(pointer):
			var offset:Vector2=event.position-presses[pointer].start
			if offset.length()>12:presses[pointer].dragged=true
			if presses[pointer].dragged and pointer==scroll_pointer:
				text_scroll.scroll_vertical=initial_scroll-roundi(offset.y/layout.scale.y)
		return true
	else:
		# Allow the text container to handle mouse-wheel scrolling.
		return false
	if down:
		presses[pointer]={"start":event.position,"dragged":false}
		if scroll_pointer==-2 and text_scroll.get_global_rect().has_point(event.position):
			scroll_pointer=pointer
			initial_scroll=text_scroll.scroll_vertical
	elif presses.has(pointer):
		var press:Dictionary=presses[pointer]
		presses.erase(pointer)
		if scroll_pointer==pointer:scroll_pointer=-2
		if not cancelled and not press.dragged and press.start.distance_to(event.position)<=12:advance()
	return true

func _process(delta:float)->void:
	age+=delta;update_layout()
	panel_group.modulate.a=smoothstep(0,.22,age)
	character.modulate.a=smoothstep(.22,.48,age)
	character.position.x=CHARACTER_RECT.position.x-24*(1-smoothstep(.22,.55,age))+sin(maxf(0,age-.55)*TAU*.35)*2
	character.rotation=0
