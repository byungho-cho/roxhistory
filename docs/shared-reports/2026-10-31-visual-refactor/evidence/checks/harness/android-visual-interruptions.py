import subprocess,time,json
from android_ready import wait_title,walk_to,read_state
from pathlib import Path
root=Path(__file__).resolve().parent
adb='C:/Users/sentr/AppData/Local/Temp/roxhistory-tools/android-sdk/platform-tools/adb.exe'
base=[adb,'-s','emulator-5556']
out=root/'visual-evidence'
def run(*args): return subprocess.check_output(base+list(args),text=True,stderr=subprocess.STDOUT).strip()
def tap(x,y,wait=.35):
 run('shell','input','tap',str(x),str(y));time.sleep(wait)
def swipe(x,y,xx,yy,ms):
 run('shell','input','swipe',str(xx),str(yy),str(xx),str(yy),str(ms));time.sleep(.25)
def snap(name):
 run('shell','screencap','-p','/sdcard/p2-review.png');run('pull','/sdcard/p2-review.png',str(out/(name+'.png')))
def save(): return json.loads(json.loads(run('shell','run-as','com.roxhistory.demo','cat','files/tests/session/save.json'))['payload'])
run('shell','am','force-stop','com.roxhistory.demo')
run('shell','am','start','-n','com.roxhistory.demo/com.godot.game.GodotApp','--esa','command_line_params','--,--test-ui');time.sleep(9)
wait_title(base);tap(1010,460);tap(845,625);tap(1050,600,3);tap(640,625);time.sleep(8) # New run only in the disposable test save.
walk_to(base,1367,846)
tap(905,645,.1);swipe(144,582,144,646,350);time.sleep(3.5)
assert save()['wood']==0,'Movement did not cancel'
tap(905,645,.1);tap(1170,645,.15);run('shell','input','keyevent','4');time.sleep(3.5)
assert save()['wood']==0,'Popup did not cancel'
tap(905,645,.1);run('shell','input','keyevent','4');time.sleep(.2);run('shell','input','keyevent','4');time.sleep(3.5)
assert save()['wood']==0,'Back did not cancel'
tap(905,645,.1);run('shell','input','keyevent','3');time.sleep(3.5);run('shell','am','start','-n','com.roxhistory.demo/com.godot.game.GodotApp','--esa','command_line_params','--,--test-ui');time.sleep(2)
assert save()['wood']==0,'Background did not cancel'
snap('android-after-interruptions');recovery_start=time.monotonic();tap(905,645,.05)
while time.monotonic()-recovery_start<6 and save()['wood']==0: time.sleep(.1)
recovery_seconds=round(time.monotonic()-recovery_start,2)
assert save()['wood']==1,'Gather did not recover'
snap('android-interruptions-recovered')
report={'utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'checks':['movement cancels gather','quest popup cancels gather','Android Back cancels gather','Home cancels gather','resume permits one gather'],'failed':[],'recovery_observed_seconds':recovery_seconds,'timing_note':'Configured gather1.2 engine seconds; observed wall time includes approach, emulator scheduling and save-read latency. Negative cancellation observations wait3.5 seconds.'}
(out/'android-interruptions.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print(json.dumps(report))



assert (root/'play-evidence/normal-save-preserved.json').read_text(encoding='utf-8')==run('shell','run-as','com.roxhistory.demo','cat','files/save.json')
