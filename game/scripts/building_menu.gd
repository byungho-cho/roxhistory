class_name BuildingMenu
extends Control
var app:Node
var selected_key:=""
var move_button:DemoButton
var upgrade_button:DemoButton
var demolish_button:DemoButton
var close_button:DemoButton
var saved_camera_offset:=Vector2.ZERO
var framing_active:=false
static var textures:Dictionary={}
const ANCHOR_Y:=-62.0 # Approved menu raised another 20 logical UI pixels to overlap the building.
const ROOT:="res://assets/ui/building-menu-v001/"
func _init(owner_app:Node)->void:app=owner_app
static func art(file:String)->Texture2D:
	if textures.has(file):return textures[file]
	var source:Texture2D=load(ROOT+file)
	var bounds:=Rect2(source.get_image().get_used_rect())
	if file!="brush-black-v003.png":
		for entry in JSON.parse_string(FileAccess.get_file_as_string(ROOT+"manifest.json")):
			if entry.file==file:
				var b:Array=entry.visible_bounds
				bounds=Rect2(b[0],b[1],b[2]-b[0],b[3]-b[1])
	var texture:=AtlasTexture.new();texture.atlas=source;texture.region=bounds;texture.filter_clip=true
	textures[file]=texture;return texture
static func decorate(button:Button,file:String,diameter:float)->void:
	for state in ["normal","hover","pressed","disabled","focus"]:button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	var base:=TextureRect.new();base.texture=art("button-base.png");base.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;base.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;base.mouse_filter=Control.MOUSE_FILTER_IGNORE
	button.add_child(base);base.size=Vector2.ONE*diameter
	var icon:=TextureRect.new();icon.texture=art(file);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
	button.add_child(icon);icon.size=Vector2.ONE*diameter*.68
	var layout:=func():base.position=(button.size-base.size)*.5;icon.position=(button.size-icon.size)*.5
	button.resized.connect(layout);layout.call()
func item(title:String,file:String,at:Vector2,diameter:float,callback:Callable)->DemoButton:
	var b:DemoButton=app.button(self,"",callback);b.name=title;b.custom_minimum_size=Vector2.ONE*maxf(44,diameter);b.size=b.custom_minimum_size;b.position=at
	decorate(b,file,diameter)
	if title!="닫기":
		var caption:Label=app.label(b,title,12,Color("fff5d6"));caption.position=Vector2(-12,b.size.y-1);caption.size=Vector2(b.size.x+24,20);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_color_override("font_outline_color",Color("231b12"));caption.add_theme_constant_override("outline_size",4);caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
	b.enable_art_feedback();return b
func _ready()->void:
	name="BuildingMenu";mouse_filter=Control.MOUSE_FILTER_IGNORE;z_index=8;size=Vector2(438,225)*.6
	move_button=app.button(self,"",move_selected);move_button.name="Move"
	IntegratedMenuArt.install(move_button,"move",Vector2(96,96)*.8);move_button.position=Vector2(0,34)*.6
	upgrade_button=app.button(self,"",upgrade);upgrade_button.name="Upgrade"
	IntegratedMenuArt.install(upgrade_button,"upgrade",Vector2(96,96)*.8);upgrade_button.position=Vector2(144.37,67)*.6
	# The reference emphasizes the central action with a larger circle and arrow.
	upgrade_button.custom_minimum_size=Vector2(80,92);upgrade_button.size=Vector2(80,92)
	var upgrade_art:=upgrade_button.art_feedback
	upgrade_art.get_node("RoundBackground").position=Vector2(-3,-2)
	upgrade_art.get_node("RoundBackground").size=Vector2(88,88)
	upgrade_art.get_node("ActionIcon").position=Vector2(11,11)
	upgrade_art.get_node("ActionIcon").size=Vector2(60,60)
	for part in ["LabelBackground","ActionName"]:
		upgrade_art.get_node(part).position=Vector2(-1,72)
		upgrade_art.get_node(part).size=Vector2(80,20)
	demolish_button=app.button(self,"",demolish);demolish_button.name="Demolish"
	IntegratedMenuArt.install(demolish_button,"demolish",Vector2(96,96)*.8);demolish_button.position=Vector2(282,34)*.6
	close_button=app.button(self,"",close);close_button.name="Close"
	IntegratedMenuArt.install(close_button,"close",Vector2(48,48)*.8);close_button.custom_minimum_size=Vector2(44,44);close_button.size=Vector2(44,44)
	close_button.art_feedback.get_node("IntegratedImage").position=Vector2(2.8,2.8)
	hide()
func close()->void:
	selected_key="";hide()
	if framing_active and is_instance_valid(app.world):
		app.world.player.camera.offset=saved_camera_offset;app.world.player.camera.force_update_scroll()
	framing_active=false
func _exit_tree()->void:
	if framing_active and is_instance_valid(app.world):app.world.player.camera.offset=saved_camera_offset
func selected_sprite()->Sprite2D:
	return app.world.building_sprite(selected_key)
func index()->int:
	for i in app.model.built_count():
		if app.model.home_key(i)==selected_key:return i
	return -1
func hit_key(at:Vector2)->String:
	var keys:Array[String]=OwnedBuildingUpgrades.keys(app.model)
	if app.model.chief_level()>0:keys.append("chief")
	# The frontmost rendered building owns overlapping roof taps.
	keys.sort_custom(func(a:String,b:String):return app.model.building_position(a).y>app.model.building_position(b).y)
	for key in keys:
		var sprite:Sprite2D=app.world.building_sprite(key)
		if not is_instance_valid(sprite) or not sprite.is_visible_in_tree():continue
		if sprite.get_rect().has_point(sprite.to_local(at)):return key
		if Geometry2D.is_point_in_polygon(at-app.model.building_position(key),EnvironmentProp.hut_footprint(340 if key=="chief" else 230)):return key
	return ""
func show_at(screen_point:Vector2)->bool:
	if app.modal or app.world_map_open or not app.application_active:return false
	var at:Vector2=app.world.get_global_transform_with_canvas().affine_inverse()*screen_point
	var key:=hit_key(at)
	if key.is_empty():return false
	app.cancel_build_preview();app.build_side.hide();app.navigation.cancel()
	if not framing_active:saved_camera_offset=app.world.player.camera.offset;framing_active=true
	selected_key=key;show();refresh();return true
func refresh()->void:
	var i:=index()
	var owned:Dictionary=app.model.lookup_building(selected_key)
	if owned.is_empty():close();return
	move_button.disabled=owned.get("data",{}).has("upgrade");move_button.hint_text="공사 완료 후 이동할 수 있어요" if move_button.disabled else "옮길 위치를 선택해 주세요"
	var upgrade_reason:String=app.building_workflow.upgrade_block_reason(app.model.chief_level()+1) if selected_key=="chief" else app.building_workflow.owned_upgrade_reason(selected_key)
	upgrade_button.disabled=not upgrade_reason.is_empty();upgrade_button.hint_text=upgrade_reason
	var quote:Dictionary=app.model.demolition_quote(selected_key)
	demolish_button.disabled=selected_key=="chief" or quote.is_empty() or not quote.get("supported",false) or owned.get("data",{}).has("upgrade")
	demolish_button.hint_text="촌장집은 철거할 수 없어요" if selected_key=="chief" else "건물 철거"
	if owned.get("data",{}).has("upgrade"):demolish_button.hint_text="공사 완료 후 철거할 수 있어요"
	elif i>=0 and app.model.resident_capacity()-[1,2,3,5][clampi(int(owned.data.get("level",1)),1,4)-1]<app.model.resident_count():demolish_button.hint_text="철거 확인 시 초과 주민이 무작위로 떠나요"
	elif selected_key!="chief" and (quote.is_empty() or not quote.get("supported",false)):demolish_button.hint_text="이 건물은 지금 철거할 수 없어요"
	IntegratedMenuArt.refresh(move_button);IntegratedMenuArt.refresh(upgrade_button,not upgrade_button.disabled)
	IntegratedMenuArt.refresh(demolish_button);IntegratedMenuArt.refresh(close_button)
	var sprite:=selected_sprite()
	if sprite==null:close();return
	var bounds:Rect2=sprite.get_global_transform_with_canvas()*sprite.get_rect()
	var anchor:=Vector2(bounds.get_center().x,bounds.end.y)
	var bottom:float=app.h-app.safe.y
	if is_instance_valid(app.action_row) and app.action_row.is_visible_in_tree():bottom=minf(bottom,app.action_row.global_position.y-8)
	var top:float=app.safe.y+100
	var left:float=maxf(app.safe.x+size.x*.5,app.safe.x+bounds.size.x*.5)
	var right:float=minf(app.w-app.safe.x-size.x*.5,app.w-app.safe.x-bounds.size.x*.5-52)
	var desired:=Vector2(clampf(anchor.x,left,maxf(left,right)),clampf(anchor.y,top,maxf(top,bottom-size.y-ANCHOR_Y)))
	var shift:=desired-anchor
	if framing_active and shift.length()>.5:
		app.world.player.camera.offset-=shift/app.world.player.camera.zoom
		app.world.player.camera.force_update_scroll()
		bounds=sprite.get_global_transform_with_canvas()*sprite.get_rect()
		anchor=Vector2(bounds.get_center().x,bounds.end.y)
	position=anchor+Vector2(-size.x*.5,ANCHOR_Y)
	close_button.position=Vector2(396,0)*.6
	queue_redraw()

func _process(_delta:float)->void:
	if not visible:return
	if app.modal or app.world_map_open or not app.application_active or app.screen!="play":close();return
	refresh()
func upgrade()->void:
	var key:=selected_key
	close()
	if key=="chief":app.building_workflow.request_upgrade()
	else:app.building_workflow.request_owned_upgrade(key)
func move_selected()->void:
	var key:=selected_key
	if app.model.lookup_building(key).is_empty():return
	if app.model.lookup_building(key).get("data",{}).has("upgrade"):app.toast("공사 완료 후 이동할 수 있어요");return
	close();app.start_building_move(key)
func demolish()->void:
	var key:=selected_key
	if key=="chief" or app.model.demolition_quote(key).is_empty():return
	close();app.show_demolition_confirmation(key)

func _draw()->void:
	# Figma v005: full exported canvas, aligned to the same reference as the buttons.
	draw_texture_rect(preload("res://assets/ui/building-menu-v005/gold-connector.png"),Rect2(Vector2(55,10)*.6,Vector2(370,137.5)*.6),false)
