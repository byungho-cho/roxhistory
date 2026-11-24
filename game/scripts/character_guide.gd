class_name CharacterGuide
extends Control
## U10400: reusable dynamic text, independent artwork and modal input ownership.
var app:Node
var heading:String
var message:String
var layout:Control
var panel_group:Control
var character:TextureRect
var timed_art: Texture2D
var art_rect := Rect2(-78,190,676,450.667)
var age:=0.0
var revealed := 0.0
var next_hint: TextureRect
const DEFAULT_CHARS_PER_SECOND := 34.0
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
const PANEL_RECT:=Rect2(149,433,978,190)
const PANEL_FRAME:=Rect2(142,430,992,204)
const TEXT_X:=357.0
const CUTIN_BODY_MAGNIFICATION := 1.30
const CUTIN_PANEL_EDGE_MASK = """
shader_type canvas_item;
void fragment() {
	COLOR.a *= smoothstep(0.022, 0.083, UV.x);
}
"""
var content := PANEL_FRAME.grow(-SharedPopupArt.INSET)
var text_width := content.end.x-TEXT_X-44.0
func _init(owner_app:Node,title:String,body:String,full_body:Texture2D=null)->void:
	app=owner_app;heading=title;message=body;timed_art=full_body
func picture(parent:Node,texture:Texture2D,rect:Rect2)->TextureRect:
	var image:=TextureRect.new();image.texture=texture;image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.position=rect.position;image.size=rect.size;image.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(image);return image
func _ready()->void:
	name="CharacterGuide";set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_STOP
	layout=Control.new();layout.name="GuideLayout";layout.size=DESIGN_SIZE;layout.clip_contents=true;layout.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(layout)
	panel_group=Control.new();panel_group.name="PanelGroup";panel_group.size=DESIGN_SIZE;panel_group.mouse_filter=Control.MOUSE_FILTER_IGNORE;layout.add_child(panel_group)
	var panel:=picture(panel_group,preload("res://assets/ui/village-guidance/guide-panel.svg"),PANEL_FRAME)
	panel.name="CreamPanel"
	if timed_art:
		# Tuck only this panel's left stroke under the foreground silhouette.
		var shader:=Shader.new()
		shader.code=CUTIN_PANEL_EDGE_MASK
		var material:=ShaderMaterial.new()
		material.shader=shader
		panel.material=material
	next_hint=picture(panel_group,preload("res://assets/ui/village-guidance/guide-next.svg"),Rect2(content.end-Vector2.ONE*32,Vector2.ONE*32))
	next_hint.name="GuideAdvanceHint"
	text_scroll=ScrollContainer.new();text_scroll.name="GuideText";text_scroll.position=Vector2(TEXT_X,content.position.y);text_scroll.size=Vector2(text_width,content.size.y);text_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;panel_group.add_child(text_scroll)
	text_column=VBoxContainer.new();text_column.name="MessageContent";text_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;text_column.add_theme_constant_override("separation",12);text_scroll.add_child(text_column)
	for item in [[heading,32],[message,27]]:
		var text:=Label.new();text.theme=DemoArt.theme();text.text=item[0];
		var font:=FontVariation.new();font.base_font=FigmaArt.NOTO;font.variation_opentype={TextServerManager.get_primary_interface().name_to_tag("wght"):700.0 if item[1]==32 else 400.0};text.add_theme_font_override("font",font);text.add_theme_font_size_override("font_size",item[1]);text.add_theme_color_override("font_color",Color("3d230f"));text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;text.add_theme_constant_override("line_spacing",0);text_column.add_child(text);text_labels.append(text);text_fonts.append(font)
	if timed_art:
		var tex_size:=timed_art.get_size()
		var factor:=minf(185.0/tex_size.x,402.0/tex_size.y)
		var fit:=tex_size*factor*CUTIN_BODY_MAGNIFICATION
		art_rect=Rect2(Vector2(196.0-fit.x*.5,623.0-fit.y),fit)
		character=picture(layout,timed_art,art_rect)
		character.name="GuideFullBody"
		character.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	else:
		character=picture(layout,preload("res://assets/ui/village-guidance/guide-character-plaque.png"),art_rect);character.name="GuideCharacter";character.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;character.clip_contents=true;character.pivot_offset=Vector2(234,425)
		var speaker:Label=app.label(character,"길잡이",30,Color("fffdf3"))
		speaker.position=Vector2(472,223);speaker.size=Vector2(94,38)
		speaker.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		speaker.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	begin_reveal()
	panel_group.modulate.a=0;character.modulate.a=0
	update_layout()
	if timed_art:set_process(false)
	else:app.animate_popup(panel_group,PANEL_RECT.get_center())
func update_layout()->void:
	# Width-fit the design's transparent frame instead of inset fitting the whole
	# 675px preview: its visible character starts at 202px, so wider phones can use
	# the empty upper part without shrinking the messenger away from the left edge.
	var factor:=minf(app.w/DESIGN_SIZE.x,(app.h-app.safe.y)/(DESIGN_SIZE.y-art_rect.position.y))
	var bottom_inset:=maxf(0.0,app.safe.y-(DESIGN_SIZE.y-PANEL_RECT.end.y)*factor)
	layout.scale=Vector2.ONE*factor
	layout.position=Vector2((app.w-DESIGN_SIZE.x*factor)*.5,app.h-DESIGN_SIZE.y*factor-bottom_inset)
	# Short copy is vertically centered like the reference; long/localized copy
	# gets the full inner height and scrolls. Portrait text has a readable minimum.
	for i in text_labels.size():
		var font_size:=maxi(32 if i==0 else 27,ceili((18.0 if i==0 else 14.0)/factor))
		if text_labels[i].get_theme_font_size("font_size")!=font_size:text_labels[i].add_theme_font_size_override("font_size",font_size)
		# Figma line boxes are36/28px (1.2em). Godot Noto's44/34px
		# metrics otherwise push the body down despite an identical font size.
		var trim:=maxi(0,roundi(FigmaArt.NOTO.get_height(font_size))-roundi(font_size*(39.0/32 if i==0 else 34.0/27)))
		var top:=-int(trim/2);var bottom:=-trim-top
		if text_fonts[i].spacing_top!=top:text_fonts[i].spacing_top=top
		if text_fonts[i].spacing_bottom!=bottom:text_fonts[i].spacing_bottom=bottom
	var height:=minf(content.size.y,maxf(1,text_column.get_combined_minimum_size().y))
	text_scroll.size=Vector2(text_width,height)
	text_scroll.position=Vector2(TEXT_X,content.position.y)
func enqueue(title:String,body:String,after:Callable)->void:
	pages.append({"title":title,"body":body})
	if after.is_valid():completions.append(after)

func remaining_pages()->Array[Dictionary]:
	var remaining:Array[Dictionary]=[{"title":heading,"body":message}]
	remaining.append_array(pages)
	return remaining

func begin_reveal() -> void:
	revealed = 0
	text_labels[1].visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	text_labels[1].visible_characters = 0
	next_hint.hide()

func finish_reveal() -> void:
	revealed = message.length()
	text_labels[1].visible_characters = -1
	next_hint.show()

func advance()->void:
	presses.clear()
	scroll_pointer=-2
	if revealed < message.length():
		finish_reveal()
		return
	if not pages.is_empty():
		var next:Dictionary=pages.pop_front()
		heading=next.title
		message=next.body
		text_labels[0].text=heading
		text_labels[1].text=message
		text_scroll.scroll_vertical=0
		begin_reveal()
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
		if not presses.is_empty():return true
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

## Timed presentation reuses the actual U10400 panel, type and safe layout.
## Its enclosing encounter owns pause, input lock and when this view is shown.
func present_timed(progress:float, duration:float) -> void:
	if not timed_art:return
	update_layout()
	var seconds:=progress*duration
	var appearing:=smoothstep(0.,.18,seconds)
	modulate.a=1.0-smoothstep(.89,1.0,progress)
	panel_group.modulate.a=appearing
	character.modulate.a=smoothstep(.05,.26,seconds)
	character.position=art_rect.position+Vector2(-13.0*(1.0-appearing),0.0)
	text_labels[1].visible_characters=mini(message.length(),maxi(0,floori((seconds-.10)*48.0)))
	next_hint.hide()

func _process(delta:float)->void:
	age+=delta;update_layout()
	panel_group.modulate.a=smoothstep(0,.22,age)
	character.modulate.a=smoothstep(.22,.48,age)
	character.position.x=art_rect.position.x-24*(1-smoothstep(.22,.55,age))
	character.position.y=art_rect.position.y+sin(age*2.2)*3.0
	if revealed < message.length():
		var speed := float(ProjectSettings.get_setting("roxhistory/tutorial/characters_per_second", DEFAULT_CHARS_PER_SECOND))
		revealed += maxf(1, speed) * delta
		if revealed >= message.length():finish_reveal()
		else:text_labels[1].visible_characters = int(revealed)
	else:
		next_hint.show()
		next_hint.position.x = 1075 + sin(age*3)*3
