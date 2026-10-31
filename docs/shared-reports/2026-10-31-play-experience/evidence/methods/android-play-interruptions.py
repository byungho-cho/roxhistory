import subprocess,time,json
from pathlib import Path
root=Path(__file__).resolve().parent
adb='adb'
base=[adb,'-s','emulator-5556']
out=root/'play-evidence'
def run(*args): return subprocess.check_output(base+list(args),text=True,stderr=subprocess.STDOUT).strip()
def tap(x,y,wait=.35):
 run('shell','input','tap',str(x),str(y));time.sleep(wait)
def swipe(x,y,xx,yy,ms):
 run('shell','input','swipe',str(xx+40),str(yy),str(xx+40),str(yy),str(ms));time.sleep(.25)
def snap(name):
 run('shell','screencap','-p','/sdcard/p2-review.png');run('pull','/sdcard/p2-review.png',str(out/(name+'.png')))
def save(): return json.loads(json.loads(run('shell','run-as','com.roxhistory.demo','cat','files/tests/session/save.json'))['payload'])
run('shell','am','force-stop','com.roxhistory.demo')
run('shell','am','start','-n','com.roxhistory.demo/com.godot.game.GodotApp','--esa','command_line_params','--,--test-ui');time.sleep(9)
tap(1010,460);tap(845,625);tap(1050,600,3);tap(640,625) # New run only in the disposable test save.
swipe(144,582,200,552,2500)
tap(830,630,.1);swipe(144,582,220,582,350);time.sleep(1.4)
assert save()['wood']==0,'Movement did not cancel'
tap(830,630,.1);tap(1135,630,.15);run('shell','input','keyevent','4');time.sleep(1.4)
assert save()['wood']==0,'Popup did not cancel'
tap(830,630,.1);run('shell','input','keyevent','4');time.sleep(.2);run('shell','input','keyevent','4');time.sleep(1.4)
assert save()['wood']==0,'Back did not cancel'
tap(830,630,.1);run('shell','input','keyevent','3');time.sleep(1.4);run('shell','am','start','-n','com.roxhistory.demo/com.godot.game.GodotApp','--esa','command_line_params','--,--test-ui');time.sleep(2)
assert save()['wood']==0,'Background did not cancel'
snap('android-after-interruptions');tap(830,630,1.5)
assert save()['wood']==1,'Gather did not recover'
snap('android-interruptions-recovered')
report={'utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'checks':['movement cancels gather','quest popup cancels gather','Android Back cancels gather','Home cancels gather','resume permits one gather'],'failed':[]}
(out/'android-interruptions.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print(json.dumps(report))



assert (root/'play-evidence/normal-save-preserved.json').read_text(encoding='utf-8')==run('shell','run-as','com.roxhistory.demo','cat','files/save.json')
