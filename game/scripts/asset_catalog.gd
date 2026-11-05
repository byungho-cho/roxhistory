class_name AssetCatalog
extends RefCounted
## Presentation metadata only. Physics, costs and occupancy belong to game logic.
const MANIFEST := "res://data/assets.json"
static var entries:Dictionary={}
static var cache:Dictionary={}
static var replacements:Dictionary={}
static func set_replacements(files:Dictionary)->void:
	# Future resource packages supply ID -> local file. No network or gameplay fields.
	replacements=files.duplicate();cache.clear()
static func entry(id:String)->Dictionary:
	if entries.is_empty():entries=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST)).assets
	return entries.get(id,{})
static func texture(id:String)->Texture2D:
	if cache.has(id):return cache[id]
	var e:=entry(id)
	var path:String=e.get("file","")
	var replacement:String=replacements.get(id,path)
	var resource:Resource=load(replacement) if ResourceLoader.exists(replacement) else null
	var t:Texture2D=resource as Texture2D
	if t!=null and e.has("source_size") and t.get_size()!=Vector2(e.source_size[0],e.source_size[1]):t=null
	if t==null and replacement!=path:t=load(path) if ResourceLoader.exists(path) else null
	if t==null:
		var fallback:String=e.get("fallback","")
		if not fallback.is_empty() and fallback!=id:return texture(fallback)
		return preload("res://assets/environment/rock-v018.png")
	if e.has("crop"):
		var r:Array=e.crop
		var region:=Rect2(r[0],r[1],r[2],r[3])
		if not Rect2(Vector2.ZERO,t.get_size()).encloses(region):
			var fallback:String=e.get("fallback","")
			return texture(fallback) if not fallback.is_empty() and fallback!=id else preload("res://assets/environment/rock-v018.png")
		var a:=AtlasTexture.new();a.atlas=t;a.region=region;a.filter_clip=true;t=a
	cache[id]=t
	return t
static func sprite(id:String,width:float)->Sprite2D:
	var s:=Sprite2D.new();s.texture=texture(id);s.scale=Vector2.ONE*width/s.texture.get_width()
	var a:Array=entry(id).get("anchor",[.5,.5])
	s.offset=s.texture.get_size()*(Vector2(.5,.5)-Vector2(a[0],a[1]))
	s.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return s
