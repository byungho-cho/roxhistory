class_name CharacterGuide
extends Control
## U10400: reusable dynamic text, independent artwork and modal input ownership.
var app:Node
var heading:String
var message:String
var layout:Control
var panel_group:Control
var character:TextureRect
var close_button:Button
var age:=0.0
var outside_press:=false
func _init(owner_app:Node,title:String,body:String)->void:
	app=owner_app;heading=title;message=body
func picture(parent:Node,texture:Texture2D,rect:Rect2)->TextureRect:
	var image:=TextureRect.new();image.texture=texture;image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.position=rect.position;image.size=rect.size;image.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(image);return image
func _ready()->void:
	name="CharacterGuide";set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_STOP
	layout=Control.new();layout.name="GuideLayout";layout.size=Vector2(1200,675);layout.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(layout)
	panel_group=Control.new();panel_group.name="PanelGroup";panel_group.size=Vector2(1200,675);panel_group.mouse_filter=Control.MOUSE_FILTER_IGNORE;layout.add_child(panel_group)
	var source:Texture2D=preload("res://assets/ui/v0159/guide-panel.png")
	var crop:=AtlasTexture.new();crop.atlas=source;crop.region=Rect2(0,source.get_height()*.1918/1.3699,source.get_width(),source.get_height()/1.3699);crop.filter_clip=true
	# Soft shadow follows the same panel silhouette; cream texture is never redrawn.
	for i in [3,2,1]:
		var shadow:=picture(panel_group,crop,Rect2(149-i,422-i,949+i*2,212+i*2));shadow.self_modulate=Color(.078,.059,.035,.09)
	var panel:=picture(panel_group,crop,Rect2(149,415,949,212));panel.name="CreamPanel";panel.self_modulate.a=.8
	var hit:=Control.new();hit.name="PanelHit";hit.position=Vector2(149,415);hit.size=Vector2(949,212);hit.mouse_filter=Control.MOUSE_FILTER_STOP;panel_group.add_child(hit)
	var scroll:=ScrollContainer.new();scroll.name="GuideText";scroll.position=Vector2(355,467);scroll.size=Vector2(670,139);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;panel_group.add_child(scroll)
	var column:=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_theme_constant_override("separation",14);scroll.add_child(column)
	for item in [[heading,30],[message,23]]:
		var text:=Label.new();text.theme=DemoArt.theme();text.text=item[0];
		var font:=FontVariation.new();font.base_font=FigmaArt.NOTO;font.variation_opentype={TextServerManager.get_primary_interface().name_to_tag("wght"):700.0 if item[1]==30 else 400.0};text.add_theme_font_override("font",font);text.add_theme_font_size_override("font_size",item[1]);text.add_theme_color_override("font_color",Color("1f1c17"));text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_child(text)
	character=picture(layout,preload("res://assets/ui/v0159/guide-character.png"),Rect2(-67,202,468,425));character.name="GuideCharacter";character.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;character.pivot_offset=Vector2(234,425)
	close_button=DemoButton.new();close_button.name="CloseGuide";close_button.position=Vector2(1034,415);close_button.size=Vector2(58,54);close_button.focus_mode=Control.FOCUS_NONE;close_button.tooltip_text="안내 닫기";panel_group.add_child(close_button)
	for state in ["normal","hover","pressed","disabled","focus"]:close_button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	var close_art:=AtlasTexture.new();close_art.atlas=preload("res://assets/ui/v0159/guide-close.png");close_art.region=Rect2(270,290,480,480);close_art.filter_clip=true
	picture(close_button,close_art,Rect2(15,13,28,28))
	close_button.pressed.connect(app.close_modal)
	gui_input.connect(outside_input)
	panel_group.modulate.a=0;character.modulate.a=0
	update_layout()
func update_layout()->void:
	var factor:=minf((app.w-app.safe.x*2)/1200.0,(app.h-app.safe.y*2)/675.0)
	layout.scale=Vector2.ONE*factor;layout.position=Vector2((app.w-1200*factor)*.5,app.h-app.safe.y-675*factor)
func outside_input(event:InputEvent)->void:
	if age<.25:return
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		var local:Vector2=layout.get_global_transform().affine_inverse()*event.position
		if Rect2(149,415,949,212).has_point(local) or Rect2(-67,202,468,425).has_point(local):
			outside_press=false;return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:outside_press=true
		elif outside_press:accept_event();app.close_modal()
	elif event is InputEventScreenTouch:
		if event.pressed:outside_press=true
		elif outside_press:accept_event();app.close_modal()
func _process(delta:float)->void:
	age+=delta;update_layout()
	panel_group.modulate.a=smoothstep(0,.22,age)
	character.modulate.a=smoothstep(.22,.48,age)
	character.position.x=-67-24*(1-smoothstep(.22,.55,age))
	character.rotation=sin(maxf(0,age-.22)*TAU*.8)*.014*minf(1,age)
