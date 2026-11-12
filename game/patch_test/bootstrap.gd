extends Control

const BASE_VERSION := "0.2.91"
const BASE_COMMIT := "9c97f052b583c255c4512bc122919c625bef9551"
const RUNTIME := "godot-4.5.1-android-pck-2"
const RELEASE_ROOT := "https://github.com/byungho-cho/roxhistory/releases/download/android-patches-0.2.91/"
signal check_status_changed(value: String)
signal manifest_check_failed_to_start
var check_status := "":
	set(value):
		check_status = value
		check_status_changed.emit(value)
var checked_title := false
var title_active := false
var restart_pending := false
const TRUST := preload("res://patch_test/patch_key.gd")

var cache := "user://rox-patches-0.2.91/"
var index := cache + "current.json"
var shade:ColorRect
var popup:CenterContainer
enum Phase { IDLE, CHECKING, AVAILABLE, CURRENT, DOWNLOADING, VERIFYING, READY, CHECK_FAILED, DOWNLOAD_FAILED,
	APK_READY, APK_PERMISSION, APK_INSTALLING, APK_INSTALL_FAILED }
const APK_CHANNEL := "https://github.com/byungho-cho/roxhistory/releases/download/android-apk-channel/apk-latest.json"
var apk_bridge: Object
var android_activity: Object
var installed_apk := {}
var checking_apk := false
var apk_selected := false
var apk_candidate := {}
var phase := Phase.IDLE
var dialog: Control
var verification_generation := 0
var failure_message := ""
var check_url := RELEASE_ROOT + "latest.json"
var request: HTTPRequest
var status: Label
var update_button: Button
var close_button: Button
var progress_bar: ProgressBar
var progress_text: Label
var downloading := false
var previous_mouse_emulation := false
var embedded_version := str(ProjectSettings.get_setting("application/config/version",BASE_VERSION))
var cached := {}
var candidate := {}
var envelope := PackedByteArray()
func _init() -> void:
	# Autoload _ready runs after the main scene is loaded. Mount before that load.
	DirAccess.make_dir_recursive_absolute(cache)
	discard(cache + "incoming.part")
	discard(index + ".part")
	cached = verified_manifest(FileAccess.get_file_as_bytes(index)) if FileAccess.file_exists(index) else {}
	if not cached.is_empty() and (version_number(cached.version)<=version_number(embedded_version) or not valid_pack(pack_path(cached),cached)):cached = {}
	ProjectSettings.set_setting("roxhistory/update/source_commit",BASE_COMMIT)
	mount_cached()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade = ColorRect.new()
	shade.color = Color(0.08, 0.06, 0.03, 0.64)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup = CenterContainer.new()
	add_child(popup)
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog = load("res://patch_test/patch_dialog.gd").new()
	popup.add_child(dialog)
	status = dialog.heading
	progress_bar = dialog.progress_bar
	progress_text = dialog.progress_text
	update_button = dialog.update_button
	close_button = dialog.close_button
	update_button.pressed.connect(primary_action)
	close_button.pressed.connect(close_popup)
	render_phase()
	request = HTTPRequest.new()
	request.timeout = 30.0
	request.body_size_limit = 8192
	add_child(request)
	request.request_completed.connect(request_completed)
	setup_apk_bridge()
	ProjectSettings.set_setting("roxhistory/native/diagnostic_zip",true)
	shade.hide()
	popup.hide()

func title_ready() -> void:
	title_active = true
	if not is_inside_tree():return
	if not checked_title and not OS.get_cmdline_user_args().has("--test-ui"):
		checked_title = true
		check_for_patch()

func show_popup() -> void:
	if not popup.visible:previous_mouse_emulation = Input.emulate_mouse_from_touch
	Input.emulate_mouse_from_touch = true
	shade.show()
	popup.show()

func leave_title() -> void:
	title_active = false
	close_popup()

func close_popup()->void:
	if restart_pending:return
	if apk_selected and downloading:apk_bridge.cancel()
	verification_generation += 1
	if popup.visible:
		request.cancel_request()
		discard(cache + "incoming.part")
	downloading=false
	checking_apk = false
	phase = Phase.IDLE
	progress_bar.hide()
	if popup.visible:Input.emulate_mouse_from_touch = previous_mouse_emulation
	popup.hide()
	shade.hide()

func _process(_delta: float) -> void:
	if apk_bridge and apk_selected:
		poll_apk()
	if phase==Phase.DOWNLOADING and not apk_selected:
		update_download_progress(request.get_downloaded_bytes(), int(candidate.size))

func update_download_progress(received: int, total: int) -> void:
	var downloaded := clampi(received, 0, total)
	progress_bar.value = minf(99.0, 100.0 * downloaded / float(total))
	progress_text.text = "%d%%  ·  %.1f / %.1f MB" % [
		floori(progress_bar.value), downloaded / 1000000.0, total / 1000000.0
	]

func render_phase() -> void:
	update_button.disabled = false
	close_button.disabled = false
	match phase:
		Phase.CHECKING:
			dialog.render("업데이트 확인 중…","새 버전이 있는지 확인하고 있습니다.","","","",false,"닫기","")
		Phase.AVAILABLE:
			dialog.render("앱 업데이트" if apk_selected else "게임 업데이트","새 버전이 준비되었습니다.\n게임 파일을 다운로드할까요?",
				"다운로드 용량 %.1f MB"%(int(apk_candidate.size if apk_selected else candidate.size)/1000000.0),
				str(installed_apk.version if apk_selected else ProjectSettings.get_setting("application/config/version",embedded_version))+"   →",apk_candidate.version if apk_selected else candidate.version,false,"나중에","다운로드" if apk_selected else "업데이트 받기")
		Phase.CURRENT:
			dialog.render("이미 최신 버전입니다","현재 버전으로 게임을 시작할 수 있습니다.","","","",false,"닫기","")
		Phase.DOWNLOADING:
			dialog.render("업데이트 다운로드 중","새 게임 파일을 받고 있습니다.\n잠시만 기다려 주세요.","취소하면 다운로드를 중단합니다.","","",true,"다운로드 취소","")
		Phase.VERIFYING:
			dialog.render("파일 확인 중…","내려받은 게임 파일을 확인하고 있습니다.","","","",true,"","")
		Phase.READY:
			dialog.render("업데이트 준비 완료","게임 파일을 내려받고 확인했습니다.\n재실행하면 새 버전이 적용됩니다.",
				"아래 버튼을 눌러 게임을 다시 시작해 주세요." if failure_message.is_empty() else failure_message,
				"새 버전",candidate.version,false,"","게임 재실행",220.0)
		Phase.APK_READY:
			dialog.render("설치 준비 완료","Android 설치 화면에서 확인해 주세요.","설치 후 게임을 다시 열어 주세요.","새 앱 버전",apk_candidate.version,false,"나중에","설치하기")
		Phase.APK_PERMISSION:
			dialog.render("이 앱의 설치 허용이 필요합니다","설정에서 RoxHistory의 앱 설치를 허용해 주세요.","허용한 뒤 돌아와 설치할 수 있습니다.","","",false,"나중에","설정 열기")
		Phase.APK_INSTALLING:
			dialog.render("설치 확인 대기","Android 설치 화면에서 확인해 주세요.","설치 후 게임을 다시 열어 주세요.","","",false,"닫기","")
		Phase.APK_INSTALL_FAILED:
			dialog.render("앱을 설치하지 못했습니다",failure_message,"기존 앱에서 계속하거나 다시 시도할 수 있습니다.","","",false,"나중에","다시 시도")
		Phase.CHECK_FAILED, Phase.DOWNLOAD_FAILED:
			dialog.render("업데이트를 진행하지 못했습니다",failure_message,"연결 상태를 확인한 뒤 다시 시도해 주세요.","","",false,"닫기","다시 시도")
		_:
			dialog.render("게임 업데이트","","","","",false,"닫기","")

func check_for_patch() -> void:
	begin_manifest_check(RELEASE_ROOT+"latest.json")

func begin_manifest_check(url: String) -> bool:
	if downloading or restart_pending or phase==Phase.CHECKING:return false
	check_url = url
	candidate.clear()
	apk_selected = false
	failure_message = ""
	phase = Phase.CHECKING
	render_phase()
	check_status = "업데이트 확인 중…"
	request.cancel_request()
	request.download_file = ""
	request.body_size_limit = 8192
	checking_apk = apk_bridge!=null and not installed_apk.is_empty()
	if checking_apk:
		request.timeout = 2.0
		if request.request(APK_CHANNEL)==OK:return true
		checking_apk = false
	return begin_pck_check()

func begin_pck_check() -> bool:
	if phase!=Phase.CHECKING:return false
	request.timeout = 4.0
	if request.request(check_url)==OK:return true
	show_failure()
	manifest_check_failed_to_start.emit()
	return false

func request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if phase not in [Phase.CHECKING,Phase.DOWNLOADING] or (downloading and apk_selected):return
	if checking_apk:
		checking_apk = false
		apk_candidate = verified_apk_catalog(body) if result==HTTPRequest.RESULT_SUCCESS and code==200 else {}
		if apk_candidate.is_empty():
			# Reuse the request only after the current signal has unwound.
			call_deferred("begin_pck_check")
		else:
			apk_selected = true
			phase = Phase.AVAILABLE
			check_status = ""
			render_phase()
			if title_active:show_popup()
		return
	request.timeout = 30.0
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		show_failure()
		return
	if phase==Phase.CHECKING:
		var remote := verify_payload(body)
		if compatible(remote) and remote.get("version")==BASE_VERSION and remote.get("patch_available")==false:
			phase = Phase.CURRENT
		else:
			candidate = verified_manifest(body)
			if candidate.is_empty():
				show_failure("업데이트 정보의 서명 또는 호환성을 확인하지 못했습니다.")
				return
			phase = Phase.AVAILABLE if version_number(candidate.version)>version_number(cached.get("version",embedded_version)) else Phase.CURRENT
		check_status = ""
		if phase==Phase.AVAILABLE:
			envelope = body
			if title_active:show_popup()
			else:checked_title = false
		render_phase()
		return
	phase = Phase.VERIFYING
	update_download_progress(int(candidate.size),int(candidate.size))
	render_phase()
	var generation := verification_generation
	# Allow a rendered frame before the synchronous file hash.
	await get_tree().process_frame
	await get_tree().process_frame
	if generation!=verification_generation or phase!=Phase.VERIFYING:return
	if not valid_pack(cache+"incoming.part",candidate):
		show_failure("다운로드한 파일의 크기 또는 해시가 일치하지 않습니다.")
		return
	if DirAccess.rename_absolute(cache+"incoming.part",pack_path(candidate))!=OK or not save_index():
		show_failure("업데이트 파일을 저장하지 못했습니다.")
		return
	downloading = false
	restart_pending = true
	failure_message = ""
	check_status = ""
	phase = Phase.READY
	render_phase()

func primary_action() -> void:
	if phase==Phase.CHECK_FAILED:
		begin_manifest_check(check_url)
	elif apk_selected:
		match phase:
			Phase.AVAILABLE, Phase.DOWNLOAD_FAILED: start_apk_download()
			Phase.APK_READY, Phase.APK_INSTALL_FAILED:
				if not apk_bridge.allowed(android_activity):
					phase = Phase.APK_PERMISSION
				elif apk_bridge.install(android_activity):
					phase = Phase.APK_INSTALLING
				else:
					phase = Phase.DOWNLOAD_FAILED
					failure_message = "설치 파일을 다시 받아 주세요."
				render_phase()
			Phase.APK_PERMISSION: apk_bridge.openPermission(android_activity)
	elif phase in [Phase.AVAILABLE,Phase.DOWNLOAD_FAILED,Phase.READY]:
		download_patch()

func download_patch() -> void:
	if restart_pending:
		update_button.disabled = true
		if OS.has_feature("android"):
			if OS.create_instance(PackedStringArray())<0:
				failure_message = "게임을 다시 열지 못했습니다. 한 번 더 눌러 주세요."
				render_phase()
		else:
			OS.set_restart_on_exit(true,OS.get_cmdline_args())
			get_tree().quit()
		return
	if downloading or candidate.is_empty() or phase not in [Phase.AVAILABLE,Phase.DOWNLOAD_FAILED]:return
	downloading = true
	phase = Phase.DOWNLOADING
	failure_message = ""
	check_status = ""
	update_download_progress(0,int(candidate.size))
	render_phase()
	request.timeout = 30.0
	request.download_file = cache+"incoming.part"
	request.body_size_limit = int(candidate.size)
	if request.request(RELEASE_ROOT+candidate.file)!=OK:show_failure()


func setup_apk_bridge() -> void:
	if not OS.has_feature("android") or not Engine.has_singleton("AndroidRuntime"):return
	apk_bridge = Engine.get_singleton("JavaClassWrapper").wrap("com.roxhistory.notifications.GameApkUpdate")
	if not apk_bridge:return
	android_activity = Engine.get_singleton("AndroidRuntime").getActivity()
	if not android_activity:
		apk_bridge = null
		return
	var data: Variant = JSON.parse_string(apk_bridge.installed(android_activity))
	if data is Dictionary:installed_apk = data
	if str(apk_bridge.snapshot()).begins_with("installed:"):
		check_status = "앱 업데이트가 완료되었습니다."
	elif str(apk_bridge.snapshot()).begins_with("install_interrupted:"):
		check_status = "앱 설치를 완료하지 못했습니다."

func is_manifest_check_pending() -> bool:
	return phase==Phase.CHECKING

func verified_apk_catalog(body: PackedByteArray) -> Dictionary:
	var data := verify_payload(body)
	if data.get("schema")!=1 or data.get("kind")!="apk" or data.get("package")!=installed_apk.get("package"):
		return {}
	var syntax := RegEx.new()
	syntax.compile("^[0-9]{1,4}[.][0-9]{1,4}[.][0-9]{1,4}$")
	if not data.get("version") is String or syntax.search(data.version)==null:return {}
	syntax.compile("^[0-9a-f]{64}$")
	if not data.get("sha256") is String or syntax.search(data.sha256)==null:return {}
	syntax.compile("^[0-9a-f]{40}$")
	if not data.get("commit") is String or syntax.search(data.commit)==null:return {}
	for key in ["code","size","min_sdk"]:
		if not data.get(key) is float or data[key]!=floorf(data[key]) or data[key]<=0:return {}
	if data.code<=installed_apk.get("code",0) or data.size>800000000 or data.min_sdk>installed_apk.get("sdk",0):return {}
	if data.get("file")!="Roxhistory_%s.apk"%data.version or data.get("tag")!="v"+data.version:return {}
	if not data.get("signer") is String or data.signer.is_empty() or data.signer!=installed_apk.get("signer"):return {}
	if not data.get("abis") is Array or not data.abis.any(func(abi):return abi in installed_apk.get("abis",[])):return {}
	if apk_bridge and not apk_bridge.acceptCode(android_activity,int(data.code)):return {}
	return data

func start_apk_download() -> void:
	if downloading or apk_candidate.is_empty():return
	if not apk_bridge.download(android_activity,apk_candidate.version,int(apk_candidate.code),int(apk_candidate.size),apk_candidate.sha256):
		phase = Phase.DOWNLOAD_FAILED
		failure_message = "설치 파일을 받을 수 없습니다. 저장공간을 확인해 주세요."
	else:
		downloading = true
		phase = Phase.DOWNLOADING
		update_download_progress(0,int(apk_candidate.size))
	render_phase()

func poll_apk() -> void:
	var snapshot := str(apk_bridge.snapshot()).split(":")
	if snapshot.size()!=2:return
	if downloading:
		update_download_progress(int(snapshot[1]),int(apk_candidate.size))
		match snapshot[0]:
			"verifying":
				if phase!=Phase.VERIFYING:
					phase = Phase.VERIFYING
					render_phase()
			"ready":
				downloading = false
				phase = Phase.APK_READY
				render_phase()
			"download_failed","cancelled":
				show_failure("앱 파일을 내려받거나 검증하지 못했습니다.")
	elif phase==Phase.APK_PERMISSION:
		if apk_bridge.allowed(android_activity):
			phase = Phase.APK_READY
			render_phase()
		elif snapshot[0]=="permission_failed":
			phase = Phase.APK_INSTALL_FAILED
			failure_message = "설치 허용 설정을 열지 못했습니다."
			render_phase()
	elif phase==Phase.APK_INSTALLING and snapshot[0] in ["install_failed","install_cancelled"]:
		phase = Phase.APK_INSTALL_FAILED
		failure_message = "설치를 취소했습니다." if snapshot[0]=="install_cancelled" else "Android가 앱을 설치하지 못했습니다."
		render_phase()


func verify_payload(bytes:PackedByteArray) -> Dictionary:
	if bytes.is_empty():return {}
	var wrapper:Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not wrapper is Dictionary:return {}
	if not wrapper.get("payload") is String or not wrapper.get("signature") is String:return {}
	var payload := Marshalls.base64_to_raw(wrapper.payload)
	var signature := Marshalls.base64_to_raw(wrapper.signature)
	var key := CryptoKey.new()
	if key.load_from_string(TRUST.PATCH_PUBLIC_KEY,true) != OK:return {}
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(payload)
	if not Crypto.new().verify(HashingContext.HASH_SHA256,hash.finish(),signature,key):return {}
	var data:Variant = JSON.parse_string(payload.get_string_from_utf8())
	return data if data is Dictionary else {}

func compatible(data: Dictionary) -> bool:
	return data.get("base")==BASE_VERSION and data.get("base_commit")==BASE_COMMIT and data.get("runtime")==RUNTIME

func verified_manifest(bytes:PackedByteArray) -> Dictionary:
	var data:=verify_payload(bytes)
	if not compatible(data):return {}
	if not data.get("version") is String or not data.get("sha256") is String or not data.get("size") is float:return {}
	var regex := RegEx.new()
	regex.compile("^[0-9]{1,4}\\.[0-9]{1,4}\\.[0-9]{1,4}$")
	if regex.search(data.version)==null or version_number(data.version)<=version_number(BASE_VERSION):return {}
	regex.compile("^[0-9a-f]{64}$")
	if not data.get("commit") is String or data.commit.length()!=40:return {}
	if regex.search(data.sha256)==null or data.size<=0 or data.size>600000000 or data.size!=floorf(data.size):return {}
	if data.get("file") != "Roxhistory_%s_to_%s.pck"%[BASE_VERSION,data.version]:return {}
	return data

func version_number(version:String) -> int:
	var parts:=version.split(".")
	return int(parts[0])*100000000+int(parts[1])*10000+int(parts[2])

func pack_path(manifest:Dictionary) -> String:
	return cache + manifest.sha256 + ".pck"

func valid_pack(path:String,manifest:Dictionary) -> bool:
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null:return false
	var length:=file.get_length()
	file.close()
	return length==int(manifest.size) and FileAccess.get_sha256(path)==manifest.sha256

func save_index() -> bool:
	var file:=FileAccess.open(index + ".part",FileAccess.WRITE)
	if file==null:return false
	file.store_buffer(envelope)
	var ok:=file.get_error()==OK
	file.close()
	return ok and DirAccess.rename_absolute(index + ".part",index)==OK

func mount_cached() -> bool:
	if cached.is_empty() or not ProjectSettings.load_resource_pack(pack_path(cached),true):return false
	ProjectSettings.set_setting("application/config/version",cached.version)
	ProjectSettings.set_setting("roxhistory/update/source_commit",cached.commit)
	return true

func show_failure(message := "") -> void:
	var download_failed := downloading
	phase = Phase.DOWNLOAD_FAILED if download_failed else Phase.CHECK_FAILED
	downloading = false
	request.timeout = 30.0
	discard(cache+"incoming.part")
	failure_message = message
	if failure_message.is_empty():
		failure_message = "게임 파일을 내려받지 못했습니다." if download_failed else "새 버전 정보를 가져오지 못했습니다."
	check_status = failure_message
	render_phase()


func discard(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
