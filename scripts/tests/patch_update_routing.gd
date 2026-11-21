extends SceneTree
# Runs against the unchanged legacy bootstrap, proving existing installs can
# receive patches without first installing a replacement native APK.
class Probe extends "res://patch_test/bootstrap.gd":
	var pck_checks:=0
	func _init():super(false)
	func begin_pck_check()->bool:
		pck_checks+=1
		return true
	func render_phase()->void:pass
var checks:=0
var failures:=0
var folder:="D:/workspace/roxhistory/build/patch-routing-fix/"
func _initialize():call_deferred("run")
func check(ok:bool,why:String):
	checks+=1
	if not ok:failures+=1;push_error(why)
func make_probe(code:int)->Probe:
	var p:=Probe.new()
	p.request=HTTPRequest.new()
	p.installed_apk={"package":"com.roxhistory.demo","code":code,"sdk":35,"abis":["arm64-v8a"],"signer":"33849a2f2e23a3b7e13231a4a2f32d4e3d89ac8dc2c78feb75492046358feb3b"}
	p.embedded_version="0.2.%d"%code
	return p
func dispose(p:Probe):
	p.request.free();p.free()
func run():
	var policy:=FileAccess.get_file_as_bytes("D:/workspace/roxhistory/build/android-apk-channel/apk-latest.json")
	var patch:=FileAccess.get_file_as_bytes("D:/workspace/roxhistory/build/patch-286/latest.json")
	var previous:=FileAccess.get_file_as_bytes(folder+"previous-apk-catalog.json")
	for code in [174,259,283,285,286]:
		var p:=make_probe(code)
		var data:=p.verify_payload(policy)
		check(not data.is_empty() and data.get("update_available")==false,"signed no-native-upgrade policy")
		check(not data.has("file") and not data.has("size") and not data.has("code"),"no installable full APK advertised")
		check(p.verified_apk_catalog(policy).is_empty(),"legacy client sees no required APK")
		p.phase=p.Phase.CHECKING;p.checking_apk=true
		p.request_completed(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),policy)
		await process_frame
		check(p.pck_checks==1 and not p.apk_selected,"existing client proceeds to PCK check")
		p.request_completed(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),patch)
		check(not p.apk_selected and p.candidate.get("version")=="0.2.286","PCK selected with unchanged bootstrap")
		check(p.phase==(p.Phase.CURRENT if code==286 else p.Phase.AVAILABLE),"embedded version controls update need")
		dispose(p)
	var p:=make_probe(285)
	check(not p.verified_apk_catalog(previous).is_empty(),"required native APK route remains compatible")
	p.phase=p.Phase.CHECKING;p.checking_apk=true
	p.request_completed(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),previous)
	await process_frame
	check(p.apk_selected and p.pck_checks==0,"explicit installable catalog still supports real native upgrades")
	dispose(p)
	p=make_probe(285)
	var wrapper:Dictionary=JSON.parse_string(policy.get_string_from_utf8());wrapper.payload=Marshalls.raw_to_base64("tampered".to_utf8_buffer())
	check(p.verify_payload(JSON.stringify(wrapper).to_utf8_buffer()).is_empty(),"policy signature tampering rejected")
	dispose(p)
	print("Legacy patch routing: ",checks," checks, ",failures," failures")
	quit(0 if failures==0 else 1)
