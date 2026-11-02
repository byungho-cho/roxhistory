from pathlib import Path
import subprocess,json,time,hashlib
from android_ready import wait_title,read_state
r=Path(__file__).resolve().parent;o=r/'aurora-icon-evidence';repo=r/'a303-main';apk=o/'final-build/RoxHistory-0.1.17-aurora-icon-debug.apk'
a=['C:/Users/sentr/AppData/Local/Temp/roxhistory-tools/android-sdk/platform-tools/adb.exe','-s','emulator-5554']
def raw(*v):return subprocess.check_output(a+list(v),timeout=240)
def run(*v):return raw(*v).decode().strip()
def git(*v):return subprocess.check_output(['git','-C',str(repo),*v],text=True).strip()
assert git('rev-parse','HEAD')=='d6b23163eab3e32b49faa50a9b2d28c52ef4a394'
assert git('rev-parse','HEAD:game')==git('rev-parse','0e9b676:game')
assert not git('status','--porcelain','--','game')
normal=raw('shell','run-as','com.roxhistory.demo','cat','files/save.json')
# This emulator had no test save. Create a valid NEW test-only save via the UI,
# without changing the empty normal save or clearing either app/profile.
existing=subprocess.run(a+['shell','run-as','com.roxhistory.demo','cat','files/tests/session/save.json'],capture_output=True,timeout=20)
assert existing.returncode!=0 or not existing.stdout,'Existing test progress found; do not overwrite'
run('shell','am','force-stop','com.roxhistory.demo');run('logcat','-c')
run('shell','am','start','-n','com.roxhistory.demo/com.godot.game.GodotApp','--esa','command_line_params','--,--test-ui');wait_title(a)
run('shell','input','tap','1045','440');time.sleep(1);run('shell','input','tap','1040','655');time.sleep(3)
before=read_state(a);assert before and not before['built']
run('shell','am','force-stop','com.roxhistory.demo')
test=raw('shell','run-as','com.roxhistory.demo','cat','files/tests/session/save.json');assert len(test)>100
(o/'pre-final-update-hashes.json').write_text(json.dumps({'normal':hashlib.sha256(normal).hexdigest(),'test':hashlib.sha256(test).hexdigest(),'new_test_save_created_via_ui':True},indent=2))
print('Valid test-only save created; installing final main APK',flush=True)
result=run('install','--no-streaming','-r',str(apk));assert 'Success' in result,result
assert normal==raw('shell','run-as','com.roxhistory.demo','cat','files/save.json')
assert test==raw('shell','run-as','com.roxhistory.demo','cat','files/tests/session/save.json')
package=run('shell','dumpsys','package','com.roxhistory.demo');assert 'versionName=0.1.17-aurora-icon' in package and 'versionCode=18 ' in package
installed=run('shell','pm','path','com.roxhistory.demo').removeprefix('package:')
digest=hashlib.sha256(apk.read_bytes()).hexdigest();assert run('shell','sha256sum',installed).split()[0]==digest
run('logcat','-c');run('shell','am','start','-n','com.roxhistory.demo/com.godot.game.GodotApp','--esa','command_line_params','--,--test-ui');wait_title(a)
run('shell','input','tap','1045','354');time.sleep(3);assert read_state(a)==before
(o/'final-main-installed.png').write_bytes(raw('exec-out','screencap','-p'))
logs=run('logcat','-d','-s','godot:V','AndroidRuntime:E');assert 'SCRIPT ERROR' not in logs and 'FATAL EXCEPTION' not in logs
(o/'final-install-log.txt').write_text(logs,encoding='utf-8')
proof={'version':'0.1.17-aurora-icon','versionCode':18,'commit':git('rev-parse','HEAD'),'game_tree':git('rev-parse','HEAD:game'),'sha256':digest,'size':apk.stat().st_size,'utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'installed_hash_matches':True,'update_preserved_valid_test_save':True,'continue_test_save':True,'normal_empty_save_unchanged':True,'physical_device_tested':False,'speaker_listening_verified':False}
(o/'final-build.json').write_text(json.dumps(proof,indent=2));print(json.dumps(proof),flush=True)
