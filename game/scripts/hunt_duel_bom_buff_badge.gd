extends RefCounted

static func sync(hud:Control,remaining:float)->void:
 if not is_instance_valid(hud):return
 var button:=hud.get("portrait_button") as Control
 if button==null:return
 var badge:=button.get_node_or_null("SaebomBuffPortraitTimer") as Panel
 if remaining<=0.:
  if badge!=null:badge.hide()
  return
 if badge==null:
  badge=Panel.new()
  badge.name="SaebomBuffPortraitTimer"
  badge.mouse_filter=Control.MOUSE_FILTER_IGNORE
  badge.z_index=12
  badge.position=Vector2(36.,16.)
  badge.size=Vector2(27.,15.)
  var bg:=StyleBoxFlat.new()
  bg.bg_color=Color(.12,.075,.035,.95)
  bg.border_color=Color("e7b766")
  bg.set_border_width_all(1)
  bg.set_corner_radius_all(4)
  badge.add_theme_stylebox_override("panel",bg)
  button.add_child(badge)
  var icon:=TextureRect.new()
  icon.name="Icon"
  icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
  icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
  icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  icon.position=Vector2(2.,1.)
  icon.size=Vector2(13.,13.)
  badge.add_child(icon)
  var timer:=Label.new()
  timer.name="Seconds"
  timer.mouse_filter=Control.MOUSE_FILTER_IGNORE
  timer.position=Vector2(15.,0.)
  timer.size=Vector2(10.,15.)
  timer.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  timer.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
  timer.add_theme_font_size_override("font_size",10)
  timer.add_theme_color_override("font_color",Color("fff3c9"))
  badge.add_child(timer)
 var art:=hud.get("chain_art") as TextureRect
 if art!=null:(badge.get_node("Icon") as TextureRect).texture=art.texture
 (badge.get_node("Seconds") as Label).text=str(clampi(ceili(remaining),1,5))
 badge.show()

static func sync_field(parent:Node,anchor:Vector2,remaining:float)->void:
 var label:=parent.get_node_or_null("SaebomBuffFieldTimer") as Label
 if remaining<=0.:
  if label!=null:label.hide()
  return
 if label==null:
  label=Label.new()
  label.name="SaebomBuffFieldTimer"
  label.mouse_filter=Control.MOUSE_FILTER_IGNORE
  label.z_index=620
  label.size=Vector2(28.,26.)
  label.scale=Vector2.ONE*.5
  label.modulate.a=.8
  label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
  label.add_theme_font_size_override("font_size",23)
  label.add_theme_color_override("font_color",Color("fff7dd"))
  label.add_theme_color_override("font_outline_color",Color("302115"))
  label.add_theme_constant_override("outline_size",4)
  parent.add_child(label)
  label.resized.connect(func():label.pivot_offset=label.size*.5)
  label.pivot_offset=label.size*.5
 label.text=str(clampi(ceili(remaining),1,5))
 label.position=anchor-label.size*.5
 label.show()
