class_name DragTrace
extends RefCounted

static var started:=0
static var last_frame:=0
static var done:=false
static var entries:Array=[]

static func start() -> void:
	if started==0:started=Time.get_ticks_usec()

static func span(label:String,begin:int) -> void:
	if started==0 or done:return
	var end:=Time.get_ticks_usec()
	entries.append([label,begin-started,end-begin])

static func frame() -> void:
	if started==0 or done:return
	var now:=Time.get_ticks_usec()
	if last_frame>0:entries.append(["frame",last_frame-started,now-last_frame])
	last_frame=now
	if now-started<26000000:return
	done=true
	var file:=FileAccess.open("user://drag-trace.json",FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(entries))
