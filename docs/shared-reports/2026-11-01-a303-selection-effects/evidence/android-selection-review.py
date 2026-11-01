from pathlib import Path
import subprocess,time,json,math,re
from android_ready import wait_title
r=Path(__file__).resolve().parent;out=r/'selection-evidence'
a=['C:/Users/sentr/AppData/Local/Temp/roxhistory-tools/android-sdk/platform-tools/adb.exe','-s','emulator-5580']
def run(*args):return subprocess.check_output(a+list(args),text=True,stderr=subprocess.STDOUT,timeout=120).strip()
def tap(x,y):run('shell','input','tap',str(round(x)),str(round(y)))
def state():
 rows=[l.split('REGION_STATE ',1)[1] for l in run('logcat','-d','-s','godot:V').splitlines() if 'REGION_STATE ' in l]
 return json.loads(rows[-1]) if rows else None
def wait(predicate,timeout=15):
 deadline=time.monotonic()+timeout
 while time.monotonic()<deadline:
  s=state()
  if s and predicate(s):return s
  time.sleep(.15)
 raise RuntimeError('Map state timeout: '+str(state()))
def snap(name):
 run('shell','screencap','-p','/sdcard/selection-review.png');run('pull','/sdcard/selection-review.png',str(out/(name+'.png')))
def logical_tap(x,y):
 s=state();tap(x*1280/s['size'][0],y*720/s['size'][1])
def select(key):
 s=state();w,h=s['size'];f=max(w/1600,h/900);u=min(w/1600,h/900)
 x,y={'jeongok':(580,138),'amsa':(610,214),'dongsam':(967,633)}[key]
 logical_tap(s['pan'][0]+x*f*s['zoom'],s['pan'][1]+y*f*s['zoom']-40*u)
 return wait(lambda v:v['ticks_ms']>s['ticks_ms'] and v['selected']==key and v['panel_visible'])
def reset():
 s=state();x,y,w,h=s['reset'];logical_tap(x+w/2,y+h/2)
 return wait(lambda v:v['ticks_ms']>s['ticks_ms'] and v['reason']=='animation_end' and abs(v['zoom']-1)<.001)
def pinch():run('shell','CLASSPATH=/data/local/tmp/rox-input.jar','app_process','/','MultiTouch','350','360','530','360','300','360','580','360','1000')
run('shell','am','force-stop','com.roxhistory.demo')
normal=run('shell','run-as','com.roxhistory.demo','cat','files/save.json')
test_save=run('shell','run-as','com.roxhistory.demo','cat','files/tests/session/save.json')
assert 'Success' in run('install','-r',str(out/'build/RoxHistory-0.1.12-selection-debug.apk'))
assert normal==run('shell','run-as','com.roxhistory.demo','cat','files/save.json')
assert test_save==run('shell','run-as','com.roxhistory.demo','cat','files/tests/session/save.json')
run('shell','am','force-stop','com.roxhistory.demo');run('logcat','-c')
run('shell','am','start','-n','com.roxhistory.demo/com.godot.game.GodotApp','--esa','command_line_params','--,--test-ui');wait_title(a)
tap(1045,440);time.sleep(.6);tap(845,625)
wait(lambda s:s['reason']=='ready');time.sleep(.5)
checks=['Signed update preserves normal and test saves'];events=[]
log=open(out/'record.log','w',encoding='utf-8')
rec=subprocess.Popen([str(r/'.tools/scrcpy/scrcpy-win64-v5.0.1/scrcpy.exe'),'--serial=emulator-5580','--no-playback','--no-control','--video-bit-rate=3M','--max-fps=30','--no-audio','--time-limit=42','--record='+str(out/'selection-effects.mp4')],stdout=log,stderr=subprocess.STDOUT)
started=time.monotonic();time.sleep(2)
for key in ['jeongok','amsa','dongsam']:
 before=state();s=select(key);time.sleep(.7)
 assert s['pan']==before['pan'] and s['zoom']==before['zoom']
 assert s['playable']==(key=='amsa')
 snap('android-'+key);events.append({'seconds':round(time.monotonic()-started,2),'action':'select '+key})
 checks.append(key+' selection keeps camera and correct start support')
old=state();tap(640,400);s=wait(lambda s:s['ticks_ms']>old['ticks_ms']);assert not s['panel_visible']
snap('android-panel-hidden');checks.append('Empty background hides full panel')
select('amsa');checks.append('Region tap restores correct panel')
old=state();pinch();s=wait(lambda s:s['ticks_ms']>old['ticks_ms'] and s['reason']=='gesture_end')
assert 1.45<s['zoom']<1.65 and s['panel_visible'];checks.append('Actual two-pointer manual pinch retains panel')
old=s;run('shell','input','swipe','420','400','500','430','800');s=wait(lambda s:s['ticks_ms']>old['ticks_ms'])
assert s['selected']==old['selected'] and s['panel_visible'] and math.dist(s['pan'],old['pan'])>10
checks.append('Manual pan does not hide panel or select');snap('android-manual-zoom')
old=s;run('shell','input','swipe','1080','400','1000','450','800');s=wait(lambda s:s['ticks_ms']>old['ticks_ms'])
assert s['pan']==old['pan'] and s['zoom']==old['zoom'];checks.append('Panel-origin drag cannot move map')
s=reset();assert s['selected']=='amsa' and s['panel_visible'];checks.append('Reset retains selection and restores overview')
for key in ['jeongok','dongsam','amsa','amsa']:select(key)
time.sleep(.7);checks.append('Rapid and repeated selection settles correctly')
rec.wait(timeout=45);log.close();assert rec.returncode==0
old=state();task_id=re.search(r'mFocusedApp=.*com.roxhistory.demo.* t(\d+)',run('shell','dumpsys','window')).group(1)
run('shell','input','keyevent','3');time.sleep(1);run('shell','am','task','focus',task_id);time.sleep(2)
tap(640,400);wait(lambda s:s['ticks_ms']>old['ticks_ms'] and not s['panel_visible'])
select('amsa');old=state();pinch();s=wait(lambda s:s['ticks_ms']>old['ticks_ms'] and s['reason']=='gesture_end')
assert s['zoom']>1.4 and s['touches']==0;checks.append('Background/resume accepts fresh pinch without retained touches');reset()
assert normal==run('shell','run-as','com.roxhistory.demo','cat','files/save.json')
assert test_save==run('shell','run-as','com.roxhistory.demo','cat','files/tests/session/save.json')
logs=run('logcat','-d','-s','godot:V','AndroidRuntime:E');assert 'SCRIPT ERROR' not in logs and 'FATAL EXCEPTION' not in logs
(out/'android-logcat.txt').write_text(logs,encoding='utf-8')
report={'utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'version':'0.1.12-selection','environment':'Android 15 API35 x86_64 emulator-5580, 1280x720; ADB taps/drags and Android MotionEvent two-pointer injection','checks':checks,'events':events,'normal_and_test_save_preserved':True,'failed':[],'physical_device_verified':False}
(out/'android-selection.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps(report,ensure_ascii=False),flush=True)
