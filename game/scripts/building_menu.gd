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
const ANCHOR_Y:=-42.0 # Previous +8 shifted up by 50 logical UI pixels.
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
	name="BuildingMenu";mouse_filter=Control.MOUSE_FILTER_IGNORE;z_index=8;size=Vector2(288,132)
	# Hold artwork/function is not connected until its display wording is confirmed.
	move_button=app.button(self,"",func():pass);move_button.disabled=true;move_button.hide()
	upgrade_button=app.button(self,"",upgrade);upgrade_button.name="Upgrade"
	IntegratedMenuArt.install(upgrade_button,"upgrade",Vector2(96,96));upgrade_button.position=Vector2(96,36)
	demolish_button=app.button(self,"",demolish);demolish_button.name="Demolish"
	IntegratedMenuArt.install(demolish_button,"demolish",Vector2(96,96));demolish_button.position=Vector2(192,0)
	close_button=app.button(self,"",close);close_button.name="Close"
	IntegratedMenuArt.install(close_button,"close",Vector2(48,48))
	hide()
func close()->void:
	selected_key="";hide()
	if framing_active and is_instance_valid(app.world):
		app.world.player.camera.offset=saved_camera_offset;app.world.player.camera.force_update_scroll()
	framing_active=false
func _exit_tree()->void:
	if framing_active and is_instance_valid(app.world):app.world.player.camera.offset=saved_camera_offset
func selected_sprite()->Sprite2D:
	if selected_key=="chief":return app.world.get_node("ExistingHut").sprite
	var found:=OwnedBuildingUpgrades.lookup(app.model,selected_key)
	if found.is_empty():return null
	if found.collection=="homes":return app.world.homes[found.index].sprite
	var outpost=app.world.get_node_or_null("Outpost_"+str(found.data.uid))
	return outpost.get_child(0) if outpost else null
func index()->int:
	for i in app.model.built_count():
		if app.model.home_key(i)==selected_key:return i
	return -1
func hit_key(at:Vector2)->String:
	# Reverse draw order, using actual scaled sprite rectangles rather than broad reward areas.
	for i in range(app.model.built_count()-1,-1,-1):
		var sprite:Sprite2D=app.world.homes[i].sprite
		if sprite.get_rect().has_point(sprite.to_local(at)):return app.model.home_key(i)
	for entry in app.model.outposts():
		var outpost=app.world.get_node_or_null("Outpost_"+str(entry.uid))
		if outpost:
			var image:Sprite2D=outpost.get_child(0)
			if image.get_rect().has_point(image.to_local(at)):return "outpost:"+str(entry.uid)
	var chief:Sprite2D=app.world.get_node("ExistingHut").sprite
	return "chief" if chief.get_rect().has_point(chief.to_local(at)) else ""
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
	var owned:=OwnedBuildingUpgrades.lookup(app.model,selected_key)
	if selected_key!="chief" and owned.is_empty():close();return
	move_button.disabled=true;move_button.hint_text="건물 이동은 다음 버전에서 제공할 예정이에요"
	var upgrade_reason:String=app.building_workflow.upgrade_block_reason(app.model.chief_level()+1) if selected_key=="chief" else app.building_workflow.owned_upgrade_reason(selected_key)
	upgrade_button.disabled=not upgrade_reason.is_empty();upgrade_button.hint_text=upgrade_reason
	demolish_button.disabled=selected_key=="chief" or selected_key.begins_with("outpost:") or owned.get("data",{}).has("upgrade") or (i>=0 and app.model.reward_pending(i))
	demolish_button.hint_text="주인공 움집은 철거할 수 없어요" if selected_key=="chief" else "건물 위 씨앗 보상을 먼저 받아 주세요"
	if selected_key.begins_with("outpost:"):demolish_button.hint_text="초소 철거는 아직 지원하지 않아요"
	elif owned.get("data",{}).has("upgrade"):demolish_button.hint_text="공사 완료 후 철거할 수 있어요"
	IntegratedMenuArt.refresh(upgrade_button,not upgrade_button.disabled)
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
	close_button.global_position=Vector2(bounds.end.x+4,bounds.end.y-98)

func _process(_delta:float)->void:
	if not visible:return
	if app.modal or app.world_map_open or not app.application_active or app.screen!="play":close();return
	refresh()
func upgrade()->void:
	var key:=selected_key
	close()
	if key=="chief":app.building_workflow.request_upgrade()
	else:app.building_workflow.request_owned_upgrade(key)
func demolish()->void:
	var key:=selected_key
	if key=="chief" or index()<0:return
	close();app.show_demolition_confirmation(key)
