import subprocess,time,json
from android_ready import walk_to
from pathlib import Path
root=Path(__file__).resolve().parent
adb='C:/Users/sentr/AppData/Local/Temp/roxhistory-tools/android-sdk/platform-tools/adb.exe'
base=[adb,'-s','emulator-5556']
out=root/'visual-evidence'
def run(*args): return subprocess.check_output(base+list(args),text=True,stderr=subprocess.STDOUT).strip()
def tap(x,y,wait=.35):
 run('shell','input','tap',str(x),str(y));time.sleep(wait)
def swipe(x,y,xx,yy,ms):
 run('shell','input','swipe',str(xx),str(yy),str(xx),str(yy),str(ms));time.sleep(.35)
def snap(name):
 run('shell','screencap','-p','/sdcard/p2-review.png');run('pull','/sdcard/p2-review.png',str(out/(name+'.png')))
def save(): return json.loads(json.loads(run('shell','run-as','com.roxhistory.demo','cat','files/tests/session/save.json'))['payload'])
run('shell','am','force-stop','com.roxhistory.demo')
run('shell','logcat','-c')
run('shell','am','start','-n','com.roxhistory.demo/com.godot.game.GodotApp','--esa','command_line_params','--,--test-ui');time.sleep(9)
start=time.monotonic();tap(1010,460);tap(845,625);tap(1050,600,3);tap(640,625);time.sleep(8) # Only the previously created test save is restarted through its UI.
# Production and test fixture both use the 3D hero automatically.
scrcpy=root/'.tools/scrcpy/scrcpy-win64-v5.0.1/scrcpy.exe'
rec_log=open(out/'scrcpy-record.log','w',encoding='utf-8')
rec=subprocess.Popen([str(scrcpy),'--serial=emulator-5556','--no-playback','--no-control','--require-audio','--audio-source=playback','--audio-codec=aac','--time-limit=100','--record='+str(out/'android-play-loop.mp4')],stdout=rec_log,stderr=subprocess.STDOUT)
time.sleep(2)
walk_to(base,1367,846);tap(905,645,.1);tap(905,645,1.8)
snap('loop-wood');assert save()['wood']==1,save()
walk_to(base,1293,1086);tap(905,645,.1);tap(905,645,1.8)
snap('loop-stone');assert save()['stone']==1,save()
walk_to(base,780,1080)
tap(1040,645);snap('final-build-confirm');tap(845,625,.1);tap(845,625,2.4);snap('final-reward');tap(950,340,.05);tap(950,340)
state=save();assert state['built'] and state['reward_claimed'] and state['tokens']==10 and state['wood']==0 and state['stone']==0,state
elapsed=time.monotonic()-start
snap('final-completed')
run('shell','am','force-stop','com.roxhistory.demo');run('shell','am','start','-n','com.roxhistory.demo/com.godot.game.GodotApp','--esa','command_line_params','--,--test-ui');time.sleep(9);tap(1010,350);snap('final-continued')
assert save()==state,(state,save())
tap(1170,645);run('shell','input','keyevent','4');time.sleep(.3)
run('shell','input','keyevent','3');time.sleep(1);run('shell','am','start','-n','com.roxhistory.demo/com.godot.game.GodotApp','--esa','command_line_params','--,--test-ui');time.sleep(2)
swipe(144,582,220,582,600);snap('final-resumed-movement')
report={'utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'elapsed_seconds':round(elapsed,2),'environment':'Android 15 API35 x86_64 emulator, host RTX5060, 1280x720','input':'ADB touchscreen gestures, no teleport or save edits; existing --test-ui isolated save path, 3D-only renderer; no comparison menu; focus-only notifications ignored by test mode, Android PAUSED/RESUMED remain active','state':state,'checks':['wood exactly once despite rapid repeat tap','stone exactly once despite rapid repeat tap','repeated confirmation builds once and costs 1+1','repeated reward tap grants exactly 10','force-stop continue identical save','quest popup/back','home/resume movement']}
(out/'android-play-loop.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps(report,ensure_ascii=False),flush=True)
rec.wait(timeout=105);rec_log.close();assert rec.returncode==0,'Audio/video recording failed'
(out/'android-final-logcat.txt').write_text(run('logcat','-d','-s','godot:V','AndroidRuntime:E'),encoding='utf-8')


original=(root/'play-evidence/normal-save-preserved.json').read_text(encoding='utf-8')
assert original==run('shell','run-as','com.roxhistory.demo','cat','files/save.json'),'Normal save changed'
print('Normal save byte-for-byte preserved.')
