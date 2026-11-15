extends Control

const ART := "res://assets/ui/d0024/"
const DESIGN := Vector2(1024,680)
const INK := Color("192c2c")
var app: Node
var amounts: Dictionary = {}

func _init(owner: Node) -> void:
	app=owner

func _ready() -> void:
	name="BagPanel"
	size=DESIGN
	mouse_filter=Control.MOUSE_FILTER_STOP
	var factor: float=minf((app.w-app.safe.x*2)/DESIGN.x,(app.h-app.safe.y*2)/DESIGN.y)
	scale=Vector2.ONE*factor
	position=(Vector2(app.w,app.h)-DESIGN*factor)*.5
	var paper := FigmaSlice.new("paper",28)
	add_child(paper)
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header_button("BagBack",Vector2(43,30),preload(ART+"09-bag-back-charcoal.svg"))
	header_button("BagClose",Vector2(915,30),preload(ART+"09-bag-close-charcoal.svg"))
	FigmaArt.text(self,"가방",Rect2(115,31,170,64),34,FigmaArt.BODY,INK,false)
	var rule := ColorRect.new()
	rule.color=Color("526360")
	rule.position=Vector2(51,110)
	rule.size=Vector2(922,2)
	rule.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(rule)
	var frame := StyleBoxFlat.new()
	frame.bg_color=Color(.51,.39,.26,.31)
	frame.border_color=Color(.34,.24,.15,.55)
	frame.set_border_width_all(2)
	frame.set_corner_radius_all(10)
	var resources := ["wood","stone","grain"]
	for i in 18:
		var slot := Panel.new()
		slot.name="BagSlot%d"%(i+1)
		slot.position=Vector2(51+152*(i%6),133+152*(i/6))
		slot.size=Vector2.ONE*139
		slot.mouse_filter=Control.MOUSE_FILTER_IGNORE
		slot.add_theme_stylebox_override("panel",frame)
		add_child(slot)
		if i>=resources.size():continue
		var resource: String=resources[i]
		var icon := AssetCatalog.texture("UI-SEED") if resource=="grain" else DemoArt.icon(resource)
		app.picture(slot,icon,Rect2(23,12,92,92))
		var amount := FigmaArt.text(slot,"",Rect2(10,104,119,30),23,FigmaArt.BODY,INK,false)
		amount.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		amounts[resource]=amount
	app.model.changed.connect(update_amounts)
	update_amounts()
	app.animate_popup(self)

func header_button(id: String, at: Vector2, icon: Texture2D) -> void:
	var button: DemoButton=app.button(self,"",app.close_modal)
	button.name=id
	button.custom_minimum_size=Vector2.ZERO
	button.position=at
	button.size=Vector2.ONE*64
	for state in ["normal","hover","pressed","focus"]:
		button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	app.picture(button,icon,Rect2(0,0,64,64))

func update_amounts() -> void:
	for resource in amounts:
		amounts[resource].text=str(int(app.model.state.get(resource,app.model.state.get("tokens",0) if resource=="grain" else 0)))
