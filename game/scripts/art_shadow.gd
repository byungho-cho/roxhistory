class_name ArtShadow
extends TextureRect
var subject:TextureRect
var offset:=Vector2(1.8,6)
var blur:=5.0
var previous_texture:Texture2D
var previous_size:=Vector2.ZERO
func _init(target:TextureRect,offset_value:Vector2=Vector2(1.8,6),blur_value:float=5.0) -> void:
	subject=target;offset=offset_value;blur=blur_value
	expand_mode=TextureRect.EXPAND_IGNORE_SIZE;stretch_mode=TextureRect.STRETCH_SCALE
	mouse_filter=Control.MOUSE_FILTER_IGNORE;texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	material=ShaderMaterial.new();material.shader=preload("res://scripts/art_shadow.gdshader")
func _process(_delta:float) -> void:
	position=subject.position+offset;size=subject.size;visible=subject.visible;texture=subject.texture
	if texture!=previous_texture or size!=previous_size:
		previous_texture=texture;previous_size=size
		if texture and size.x>0 and size.y>0:
			var region:Vector2=texture.region.size/texture.atlas.get_size() if texture is AtlasTexture else Vector2.ONE
			material.set_shader_parameter("blur_step",region*blur*.5/size)
